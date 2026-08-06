#!/usr/bin/env bash
# Create K8s secrets for Habit Tracker from backend/.env and firebase-config.json.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
habitAppRoot="${habitAppRoot:-${HOME}/Desktop/habitTracker}"
backendEnv="${habitAppRoot}/backend/.env"
firebaseJson="${habitAppRoot}/backend/firebase-config.json"
namespace="${habitNamespace:-habit}"

createBackendEnvSecret() {
  if [[ ! -f "${backendEnv}" ]]; then
    echo "Missing ${backendEnv}"
    exit 1
  fi

  kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret generic habit-backend-env \
    --from-env-file="${backendEnv}" \
    --namespace="${namespace}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Secret habit-backend-env updated in namespace ${namespace}"
}

createFirebaseCredentialsSecret() {
  if [[ ! -f "${firebaseJson}" ]]; then
    echo "Missing ${firebaseJson}"
    exit 1
  fi

  kubectl create secret generic habit-firebase-credentials \
    --from-file=firebase-config.json="${firebaseJson}" \
    --namespace="${namespace}" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Secret habit-firebase-credentials updated in namespace ${namespace}"
}

createHabitSecrets() {
  createBackendEnvSecret
  createFirebaseCredentialsSecret
  kubectl get secrets -n "${namespace}" | grep habit || true
}

createHabitSecrets "$@"
