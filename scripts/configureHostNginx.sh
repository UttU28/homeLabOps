#!/usr/bin/env bash
# Deprecated — routing lives in homeLabOps (Ingress + edge nginx).
# Forwards to org-style edge installer.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Note: Saral host nginx moved to homeLabOps (platform/edgeNginx)."
exec "${scriptDir}/configureEdgeNginx.sh" "$@"
