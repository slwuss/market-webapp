#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_DIR="$SCRIPT_DIR/../argocd"
VALUES_FILE="$ARGOCD_DIR/argocd-values-9.4.0.yaml"
TEMP_VALUES_FILE="$ARGOCD_DIR/argocd-values-9.4.0.tmp.yaml"
BOUTIQUE_FILE="$ARGOCD_DIR/argocd-apps/boutique-app.yaml"
TEMP_BOUTIQUE_FILE="$ARGOCD_DIR/argocd-apps/boutique-app.tmp.yaml"

[[ -f "$VALUES_FILE" ]]   || { echo "Error: $VALUES_FILE not found." >&2; exit 1; }
[[ -f "$BOUTIQUE_FILE" ]] || { echo "Error: $BOUTIQUE_FILE not found." >&2; exit 1; }

cleanup() {
  if [[ -f "$TEMP_VALUES_FILE" ]]; then
    rm -f "$TEMP_VALUES_FILE"
    echo "[cleanup] Removed temporary values file."
  fi
  if [[ -f "$TEMP_BOUTIQUE_FILE" ]]; then
    rm -f "$TEMP_BOUTIQUE_FILE"
    echo "[cleanup] Removed temporary boutique-app file."
  fi
}
trap cleanup EXIT

# ── 1. Prompt for domain ────────────────────────────────────────────────────

read -rp "Enter your domain (e.g. example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "Error: domain cannot be empty." >&2
  exit 1
fi

read -rp "Enter your GitHub repo URL (e.g. https://github.com/user/repo.git): " GITHUB_REPO
if [[ -z "$GITHUB_REPO" ]]; then
  echo "Error: GitHub repo URL cannot be empty." >&2
  exit 1
fi

# ── 2. Create temp values file with domain substituted ──────────────────────

sed "s|your-domain\.com|${DOMAIN}|g" "$VALUES_FILE" > "$TEMP_VALUES_FILE"
echo "[info] Created temporary values file: $TEMP_VALUES_FILE"
echo "[info] ArgoCD hostname will be: argocd.${DOMAIN}"

# ── 3. Add ArgoCD Helm repo ─────────────────────────────────────────────────

echo ""
echo "[step 1/4] Adding ArgoCD Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# ── 4. Install ArgoCD ───────────────────────────────────────────────────────

echo ""
echo "[step 2/4] Installing ArgoCD via Helm..."
helm upgrade --install argo-cd argo/argo-cd \
  -n argocd \
  -f "$TEMP_VALUES_FILE" \
  --version 9.4.0 \
  --create-namespace

# ── 5. Apply target group config ────────────────────────────────────────────

echo ""
echo "[step 3/4] Applying target group config..."
kubectl apply -f "$ARGOCD_DIR/target-grp-config.yaml"

# ── 6. Retrieve initial admin password ──────────────────────────────────────

echo ""
echo "[step 4/4] Waiting for ArgoCD initial admin secret..."
for i in $(seq 1 30); do
  if kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; then
    break
  fi
  echo "  Waiting for secret... (${i}/30)"
  sleep 5
  if [[ $i -eq 30 ]]; then
    echo "Error: timed out waiting for argocd-initial-admin-secret." >&2
    exit 1
  fi
done

PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "────────────────────────────────────────"
echo "  ArgoCD is ready!"
echo "  URL:  https://argocd.${DOMAIN}"
echo "  user: admin"
echo "  pass: ${PASSWORD}"
echo "────────────────────────────────────────"

# ── 7. Deploy boutique-app with custom GitHub repo ──────────────────────────

echo ""
echo "[step 5/5] Deploying boutique-app..."
sed "s|repoURL: .*|repoURL: ${GITHUB_REPO}|" "$BOUTIQUE_FILE" > "$TEMP_BOUTIQUE_FILE"
echo "[info] repoURL set to: ${GITHUB_REPO}"
kubectl apply -f "$TEMP_BOUTIQUE_FILE"
echo "[info] boutique-app applied successfully."
