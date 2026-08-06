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

  if kubectl get ns ingress-nginx &>/dev/null; then
    echo "Waiting for ingress-nginx controller (admission webhook must be ready)…"
    kubectl wait --for=condition=available deployment/ingress-nginx-controller \
      -n ingress-nginx --timeout=180s 2>/dev/null || true
  fi

  kubectl apply -f "${argocdPath}/"
  echo "Argo CD applications applied from ${argocdPath}"
  kubectl get applications -n argocd
}

bootstrapArgoApps "$@"
