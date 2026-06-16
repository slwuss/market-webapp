#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./cleanup-gateway-api.sh [--yes]

Searches for Gateway API HTTPRoute and Gateway resources in the current kubectl context,
shows them, and deletes them from the cluster.

Options:
  --yes    Skip the confirmation prompt and delete immediately.
  -h, --help
EOF
}

AUTO_CONFIRM=false

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

echo "Cleanup completed."
