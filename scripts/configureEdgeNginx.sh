#!/usr/bin/env bash
# Install homelab edge nginx vhost — proxies domain traffic to in-cluster Ingress.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
edgeTemplate="${repoRoot}/platform/edgeNginx/saral.thatinsaneguy.com.conf"
nginxSite="${edgeNginxSite:-/etc/nginx/sites-available/saral.thatinsaneguy.com}"
leCert="/etc/letsencrypt/live/saral.thatinsaneguy.com/fullchain.pem"

configureEdgeNginx() {
  if [[ ! -f "${edgeTemplate}" ]]; then
    echo "Missing ${edgeTemplate}"
    exit 1
  fi

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Re-run with sudo:"
    echo "  sudo ${scriptDir}/configureEdgeNginx.sh"
    exit 1
  fi

  if [[ -f "${nginxSite}" ]]; then
    cp "${nginxSite}" "${nginxSite}.bak.$(date +%Y%m%d%H%M%S)"
  fi

  cp "${edgeTemplate}" "${nginxSite}"
  mkdir -p /etc/nginx/sites-enabled
  ln -sf "${nginxSite}" "/etc/nginx/sites-enabled/saral.thatinsaneguy.com"

  if [[ ! -f "${leCert}" ]]; then
    echo "Warning: ${leCert} not found — HTTPS block needs a cert for nginx to reload."
    echo "Run cert-manager sync first, or keep existing certbot cert at that path."
  fi

  nginx -t
  systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || nginx -s reload

  echo "Edge nginx updated: ${nginxSite}"
  echo "  HTTP  → ingress NodePort 30080"
  echo "  HTTPS → ingress NodePort 30443 (TLS from cert-manager in cluster)"
}

configureEdgeNginx "$@"
