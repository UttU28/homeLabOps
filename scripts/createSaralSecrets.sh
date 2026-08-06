#!/usr/bin/env bash
# Create K8s secrets for Saral from backend/.env and client_secret.json.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
saralAppRoot="${saralAppRoot:-${HOME}/Desktop/Saral-Job-Viewer}"
backendEnv="${saralAppRoot}/backend/.env"
gmailJson="${saralAppRoot}/backend/client_secret.json"
namespace="${saralNamespace:-saral}"

createBackendEnvSecret() {
  if [[ ! -f "${backendEnv}" ]]; then
    echo "Missing ${backendEnv}"
    exit 1
  fi

  kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret generic saral-backend-env \
    --from-env-file="${backendEnv}" \
    --namespace="${namespace}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Secret saral-backend-env updated in namespace ${namespace}"
}

createGmailClientSecret() {
  if [[ ! -f "${gmailJson}" ]]; then
    echo "Missing ${gmailJson} — skip Gmail secret or add file later."
    return 0
  fi

  kubectl create secret generic saral-gmail-client \
    --from-file=client_secret.json="${gmailJson}" \
    --namespace="${namespace}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Secret saral-gmail-client updated in namespace ${namespace}"
}

createSaralSecrets() {
  createBackendEnvSecret
  createGmailClientSecret
  kubectl get secrets -n "${namespace}" | grep saral || true
}

createSaralSecrets "$@"
