#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGGING_DIR="$SCRIPT_DIR/../observability/logging"
HELM_VALUES_DIR="$LOGGING_DIR/้helm-values"

STORAGECLASS_FILE="$LOGGING_DIR/storageclass.yaml"
ECK_BEATS_VALUES="$HELM_VALUES_DIR/eck-beats-0.18.0.yaml"
ECK_KIBANA_VALUES="$HELM_VALUES_DIR/eck-kibana-0.18.0.yaml"
KIBANA_ROUTE="$LOGGING_DIR/HTTProute-kibana.yaml"
TARGET_GRP_KIBANA="$LOGGING_DIR/target-grp-kibana.yaml"

TEMP_KIBANA_ROUTE="$LOGGING_DIR/HTTProute-kibana.tmp.yaml"

[[ -f "$STORAGECLASS_FILE" ]]  || { echo "Error: $STORAGECLASS_FILE not found." >&2; exit 1; }
[[ -f "$ECK_BEATS_VALUES" ]]   || { echo "Error: $ECK_BEATS_VALUES not found." >&2; exit 1; }
[[ -f "$ECK_KIBANA_VALUES" ]]  || { echo "Error: $ECK_KIBANA_VALUES not found." >&2; exit 1; }
[[ -f "$KIBANA_ROUTE" ]]       || { echo "Error: $KIBANA_ROUTE not found." >&2; exit 1; }
[[ -f "$TARGET_GRP_KIBANA" ]]  || { echo "Error: $TARGET_GRP_KIBANA not found." >&2; exit 1; }

cleanup() {
  if [[ -f "$TEMP_KIBANA_ROUTE" ]]; then
    rm -f "$TEMP_KIBANA_ROUTE"
    echo "[cleanup] Removed temporary Kibana HTTPRoute file."
  fi
}
trap cleanup EXIT

# ── 1. Collect all inputs upfront ───────────────────────────────────────────

read -rp "Enter your EKS cluster name (e.g. terraform-cluster): " CLUSTER_NAME
if [[ -z "$CLUSTER_NAME" ]]; then
  echo "Error: cluster name cannot be empty." >&2
  exit 1
fi
if [[ "$CLUSTER_NAME" =~ [[:space:]] ]]; then
  echo "Error: cluster name must not contain spaces." >&2
  exit 1
fi

read -rp "Enter the EBS CSI IAM Role ARN from CloudFormation output (e.g. arn:aws:iam::123456789:role/eksctl-...): " ROLE_ARN
if [[ -z "$ROLE_ARN" ]]; then
  echo "Error: IAM Role ARN cannot be empty." >&2
  exit 1
fi
if [[ "$ROLE_ARN" != arn:aws:iam::* ]]; then
  echo "Error: Role ARN must start with 'arn:aws:iam::'." >&2
  exit 1
fi

read -rp "Enter your domain (e.g. example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "Error: domain cannot be empty." >&2
  exit 1
fi
if [[ "$DOMAIN" == *"|"* ]]; then
  echo "Error: domain must not contain '|'." >&2
  exit 1
fi

# ── 2. Check EBS CSI addon availability ─────────────────────────────────────

echo ""
echo "[step 1/10] Checking EBS CSI Driver addon availability..."
aws eks describe-addon-versions --addon-name aws-ebs-csi-driver --query 'addons[0].addonVersions[0].addonVersion' --output text

echo ""
echo "[info] Current addons on cluster '${CLUSTER_NAME}':"
aws eks list-addons --cluster-name "$CLUSTER_NAME"

# ── 3. Create IAM service account (if not exists) ───────────────────────────

echo ""
echo "[step 2/10] Checking IAM service account ebs-csi-controller-sa..."
if kubectl -n kube-system get serviceaccount ebs-csi-controller-sa &>/dev/null; then
  echo "[info] Service account 'ebs-csi-controller-sa' already exists, skipping."
else
  echo "[info] Creating IAM service account..."
  eksctl create iamserviceaccount \
    --cluster "$CLUSTER_NAME" \
    --namespace kube-system \
    --name ebs-csi-controller-sa \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --override-existing-serviceaccounts \
    --approve
fi

# ── 4. Create EBS CSI addon (if not exists) ──────────────────────────────────

echo ""
echo "[step 3/10] Checking EBS CSI Driver addon on cluster..."
if aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name aws-ebs-csi-driver &>/dev/null; then
  echo "[info] EBS CSI Driver addon already exists, skipping."
else
  echo "[info] Creating EBS CSI Driver addon..."
  eksctl create addon \
    --cluster "$CLUSTER_NAME" \
    --name aws-ebs-csi-driver \
    --version latest \
    --service-account-role-arn "$ROLE_ARN" \
    --force
fi

echo ""
echo "[verify] EBS CSI pods in kube-system (may still be initializing):"
kubectl get pods -n kube-system | grep ebs || echo "[warn] No EBS pods found yet — addon may still be rolling out."

# ── 5. Create logging namespace ──────────────────────────────────────────────

echo ""
echo "[step 4/10] Creating logging namespace..."
kubectl create ns logging 2>/dev/null || echo "[info] Namespace 'logging' already exists, skipping."

# ── 6. Apply StorageClass ────────────────────────────────────────────────────

echo ""
echo "[step 5/10] Applying EBS StorageClass..."
kubectl apply -f "$STORAGECLASS_FILE"

echo ""
echo "[verify] StorageClasses (ebs-aws should be default):"
kubectl get storageclass

# ── 7. Install ECK Operator + Elasticsearch ──────────────────────────────────

echo ""
echo "[step 6/10] Adding elastic Helm repo and installing ECK Operator..."
helm repo add elastic https://helm.elastic.co
helm repo update elastic

helm upgrade --install eck-operator elastic/eck-operator \
  --version 3.3.0 \
  -n logging

echo ""
echo "[step 7/10] Installing ECK Elasticsearch..."
helm upgrade --install eck-elasticsearch elastic/eck-elasticsearch \
  --version 0.18.0 \
  -n logging

echo ""
echo "[verify] Pods in logging namespace (may still be initializing):"
kubectl get po -n logging

echo ""
echo "[verify] Elasticsearch status (may still be initializing):"
kubectl get elasticsearch -n logging

echo ""
echo "[verify] Persistent Volumes (may be empty until Elasticsearch starts):"
kubectl get pv

echo ""
echo "[verify] Persistent Volume Claims in logging namespace (may be empty until Elasticsearch starts):"
kubectl get pvc -n logging

# ── 8. Install ECK Beats ─────────────────────────────────────────────────────

echo ""
echo "[step 8/10] Installing ECK Beats..."
helm upgrade --install eck-beats elastic/eck-beats \
  --version 0.18.0 \
  -f "$ECK_BEATS_VALUES" \
  -n logging

echo ""
echo "[verify] Pods in logging namespace:"
kubectl get po -n logging

# ── 9. Install ECK Kibana ────────────────────────────────────────────────────

echo ""
echo "[step 9/10] Installing ECK Kibana..."
helm upgrade --install eck-kibana elastic/eck-kibana \
  --version 0.18.0 \
  -f "$ECK_KIBANA_VALUES" \
  -n logging

echo ""
echo "[verify] Pods in logging namespace:"
kubectl get po -n logging

# ── 10. Deploy Kibana HTTPRoute + target group ───────────────────────────────

echo ""
echo "[step 10/10] Deploying Kibana HTTPRoute..."
sed "s|kibana\.project-cruddur\.com|kibana.${DOMAIN}|g" \
  "$KIBANA_ROUTE" > "$TEMP_KIBANA_ROUTE"
echo "[info] Kibana hostname set to: kibana.${DOMAIN}"

echo ""
echo "[verify] Services in logging namespace:"
kubectl get svc -n logging

kubectl apply -f "$TEMP_KIBANA_ROUTE"
kubectl apply -f "$TARGET_GRP_KIBANA"

# ── 11. Get Elasticsearch credentials ───────────────────────────────────────

echo ""
echo "[info] Waiting for Elasticsearch secret..."
for i in $(seq 1 30); do
  if kubectl -n logging get secret eck-elasticsearch-es-elastic-user &>/dev/null; then
    break
  fi
  echo "  Waiting for secret... (${i}/30)"
  sleep 5
  if [[ $i -eq 30 ]]; then
    echo "Error: timed out waiting for eck-elasticsearch-es-elastic-user secret." >&2
    exit 1
  fi
done

ES_PASSWORD=$(kubectl get secret eck-elasticsearch-es-elastic-user \
  -n logging \
  -o go-template='{{.data.elastic | base64decode}}')

echo ""
echo "────────────────────────────────────────"
echo "  Logging stack deployed!"
echo "  Kibana: https://kibana.${DOMAIN}"
echo ""
echo "  Elasticsearch credentials:"
echo "  user:     elastic"
echo "  password: ${ES_PASSWORD}"
echo "────────────────────────────────────────"
