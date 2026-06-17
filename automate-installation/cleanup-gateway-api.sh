#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./cleanup-gateway-api.sh [--yes] [--cluster <name>]

Searches for Gateway API HTTPRoute and Gateway resources in the current kubectl
context, shows them, and deletes them. Optionally also deletes EBS volumes whose
Name tag starts with the given cluster name.

Options:
  --yes              Skip all confirmation prompts and delete immediately.
  --cluster <name>   EKS cluster name used to find and delete associated EBS volumes.
  -h, --help
EOF
}

AUTO_CONFIRM=false
CLUSTER_NAME=""

verify_cleanup() {
  local timeout_seconds=120
  local interval_seconds=5
  local elapsed=0

  echo "Verifying that all Gateway API resources are deleted..."

  while (( elapsed < timeout_seconds )); do
    REMAINING="$(kubectl get httproute,gateway --all-namespaces -o name 2>/dev/null || true)"

    if [[ -z "${REMAINING}" ]]; then
      echo "Verification passed: no HTTPRoute or Gateway resources remain in the cluster."
      return 0
    fi

    echo "Waiting for terminating resources to disappear (${elapsed}s / ${timeout_seconds}s)..."
    kubectl get httproute,gateway --all-namespaces -o wide || true

    sleep "${interval_seconds}"
    elapsed=$((elapsed + interval_seconds))
  done

  echo "Verification failed. Some HTTPRoute or Gateway resources are still present after ${timeout_seconds}s:" >&2
  kubectl get httproute,gateway --all-namespaces -o wide >&2 || true
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      AUTO_CONFIRM=true
      shift
      ;;
    --cluster)
      CLUSTER_NAME="${2:-}"
      if [[ -z "$CLUSTER_NAME" ]]; then
        echo "Error: --cluster requires a value." >&2
        usage >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but was not found in PATH." >&2
  exit 1
fi

if ! kubectl get ns >/dev/null 2>&1; then
  echo "Unable to access the Kubernetes cluster from the current kubectl context." >&2
  echo "Run 'aws eks update-kubeconfig ...' or set the correct context first." >&2
  exit 1
fi

CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || echo '<unknown>')"

printf 'Current kubectl context: %s\n\n' "$CURRENT_CONTEXT"

printf 'Searching for Gateway API resources...\n'

kubectl get httproute,gateway --all-namespaces -o wide || true

if ! kubectl get httproute --all-namespaces >/dev/null 2>&1 && ! kubectl get gateway --all-namespaces >/dev/null 2>&1; then
  echo "No Gateway API HTTPRoute or Gateway resources were found."
  exit 0
fi

if [[ "$AUTO_CONFIRM" != true ]]; then
  read -r -p "Delete all discovered HTTPRoute and Gateway resources from this cluster? [y/N] " CONFIRM
  case "$CONFIRM" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Aborted. No resources were deleted."
      exit 0
      ;;
  esac
fi

echo "Deleting HTTPRoute resources..."
kubectl delete httproute --all --all-namespaces --ignore-not-found=true

echo "Deleting Gateway resources..."
kubectl delete gateway --all --all-namespaces --ignore-not-found=true

verify_cleanup

# ── EBS Volume cleanup ───────────────────────────────────────────────────────

echo ""
if [[ -z "$CLUSTER_NAME" ]]; then
  if [[ "$AUTO_CONFIRM" == true ]]; then
    echo "[warn] --yes passed but no --cluster name provided — skipping EBS cleanup."
  else
    read -rp "Enter your EKS cluster name to delete associated EBS volumes (leave blank to skip): " CLUSTER_NAME
  fi
fi

if [[ -z "$CLUSTER_NAME" ]]; then
  echo "Skipping EBS volume cleanup."
else
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI is required for EBS cleanup but was not found in PATH." >&2
    echo "Skipping EBS volume cleanup."
  else
    echo ""
    echo "Searching for EBS volumes with name starting with '${CLUSTER_NAME}'..."

    VOLUMES_RAW=$(aws ec2 describe-volumes \
      --filters "Name=tag:Name,Values=${CLUSTER_NAME}*" \
      --query 'Volumes[*].[VolumeId,State,Tags[?Key==`Name`].Value|[0],Size]' \
      --output text 2>/dev/null || true)

    if [[ -z "$VOLUMES_RAW" ]]; then
      echo "No EBS volumes found with name starting with '${CLUSTER_NAME}'."
    else
      echo "Found EBS volumes:"
      printf "%-25s %-12s %-45s %s\n" "ID" "State" "Name" "Size(GiB)"
      printf "%-25s %-12s %-45s %s\n" "-------------------------" "------------" "---------------------------------------------" "---------"
      while IFS=$'\t' read -r vol_id state name size; do
        printf "%-25s %-12s %-45s %s\n" "$vol_id" "$state" "${name:-N/A}" "$size"
      done <<< "$VOLUMES_RAW"

      DO_DELETE=true
      if [[ "$AUTO_CONFIRM" != true ]]; then
        read -r -p "Delete all listed EBS volumes? [y/N] " EBS_CONFIRM
        case "$EBS_CONFIRM" in
          y|Y|yes|YES) ;;
          *)
            echo "Skipping EBS volume deletion."
            DO_DELETE=false
            ;;
        esac
      fi

      if [[ "$DO_DELETE" == true ]]; then
        while IFS=$'\t' read -r vol_id _state _name _size; do
          echo "Deleting EBS volume ${vol_id}..."
          aws ec2 delete-volume --volume-id "$vol_id" \
            || echo "[warn] Could not delete ${vol_id} — it may still be in-use."
        done <<< "$VOLUMES_RAW"
        echo "EBS volume deletion complete."
      fi
    fi
  fi
fi

echo "Cleanup completed."
