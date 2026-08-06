#!/usr/bin/env bash
# Bootstrap platform stack (cert-manager → ingress-nginx) then apps.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
argocdPath="${repoRoot}/argocd"

bootstrapPlatform() {
  if ! kubectl get ns argocd &>/dev/null; then
    echo "argocd namespace not found — install Argo CD first."
    exit 1
  fi

  kubectl apply -f "${argocdPath}/certManagerApplication.yaml"
  kubectl apply -f "${argocdPath}/ingressNginxApplication.yaml"

  echo "Platform Argo apps registered (cert-manager, ingress-nginx)."
  echo "Wait for sync, then run: ./scripts/bootstrapArgoApps.sh"
  kubectl get applications -n argocd
}

bootstrapPlatform "$@"
