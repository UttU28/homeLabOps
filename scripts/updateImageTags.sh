#!/usr/bin/env bash
# Bump image tags in apps/saralJobViewer/kustomization.yaml (used by CI or locally).
# Usage: ./updateImageTags.sh <apiTag> <uiTag> <redisTag>
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
kustomizationFile="${repoRoot}/apps/saralJobViewer/kustomization.yaml"

updateImageTag() {
  local imageName="$1"
  local newTag="$2"

  if [[ ! -f "${kustomizationFile}" ]]; then
    echo "Missing ${kustomizationFile}"
    exit 1
  fi

  # Replace newTag for the matching image name block.
  awk -v img="${imageName}" -v tag="${newTag}" '
    $0 ~ "name: " img { inBlock=1 }
    inBlock && $0 ~ /^[[:space:]]*newTag:/ {
      sub(/newTag:.*/, "newTag: \"" tag "\"")
      inBlock=0
    }
    { print }
  ' "${kustomizationFile}" > "${kustomizationFile}.tmp"

  mv "${kustomizationFile}.tmp" "${kustomizationFile}"
  echo "Set ${imageName} -> ${newTag}"
}

updateAllImageTags() {
  local apiTag="${1:-latest}"
  local uiTag="${2:-${apiTag}}"
  local redisTag="${3:-${apiTag}}"

  updateImageTag "ghcr.io/uttu28/saral-api" "${apiTag}"
  updateImageTag "ghcr.io/uttu28/saral-ui" "${uiTag}"
  updateImageTag "ghcr.io/uttu28/saral-redis" "${redisTag}"

  echo "Tags updated in ${kustomizationFile}"
  grep -A1 'name: ghcr.io' "${kustomizationFile}" || true
}

updateAllImageTags "$@"
