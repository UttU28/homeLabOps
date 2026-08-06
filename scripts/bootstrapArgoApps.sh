#!/usr/bin/env bash
# Register Argo CD Applications from this repo.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
argocdPath="${repoRoot}/argocd"

bootstrapArgoApps() {
  if ! kubectl get ns argocd &>/dev/null; then
    echo "argocd namespace not found — install Argo CD first."
    exit 1
  fi

  kubectl apply -f "${argocdPath}/"
  echo "Argo CD applications applied from ${argocdPath}"
  kubectl get applications -n argocd
}

bootstrapArgoApps "$@"
