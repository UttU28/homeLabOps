#!/usr/bin/env bash
# Create K8s secrets for Link It Up from backend/.env and firebaseServiceAccountKey.json.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
linkItUpAppRoot="${linkItUpAppRoot:-${HOME}/Desktop/LinkedIn_Reverse_Search}"
backendEnv="${linkItUpAppRoot}/backend/.env"
firebaseJson="${linkItUpAppRoot}/backend/firebaseServiceAccountKey.json"
namespace="${linkItUpNamespace:-linkitup}"

createBackendEnvSecret() {
  local envFile="${backendEnv}"
  if [[ ! -f "${envFile}" && -f "${linkItUpAppRoot}/backend/.example.env" ]]; then
    envFile="${linkItUpAppRoot}/backend/.example.env"
    echo "Using ${envFile} — copy to backend/.env for production values."
  fi
  if [[ ! -f "${envFile}" ]]; then
    echo "Missing ${backendEnv}"
    exit 1
  fi

  kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret generic linkitup-backend-env \
    --from-env-file="${envFile}" \
    --namespace="${namespace}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Secret linkitup-backend-env updated in namespace ${namespace}"
}

createFirebaseCredentialsSecret() {
  if [[ ! -f "${firebaseJson}" ]]; then
    echo "Missing ${firebaseJson}"
    exit 1
  fi

  kubectl create secret generic linkitup-firebase-credentials \
    --from-file=firebaseServiceAccountKey.json="${firebaseJson}" \
    --namespace="${namespace}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Secret linkitup-firebase-credentials updated in namespace ${namespace}"
}

createLinkItUpSecrets() {
  createBackendEnvSecret
  createFirebaseCredentialsSecret
  kubectl get secrets -n "${namespace}" | grep linkitup || true
}

createLinkItUpSecrets "$@"
