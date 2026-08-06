#!/usr/bin/env bash
# Apply Saral GitOps manifests directly (no Argo CD).
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
appPath="${repoRoot}/apps/saralJobViewer"

applySaralStack() {
  kubectl apply -k "${appPath}"
  echo "Applied saralJobViewer from ${appPath}"
  kubectl get pods,svc -n saral
}

applySaralStack "$@"
