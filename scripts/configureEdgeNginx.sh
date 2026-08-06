#!/usr/bin/env bash
# Install homelab edge nginx vhosts — proxy domain traffic to in-cluster Ingress.
set -euo pipefail

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repoRoot="$(cd "${scriptDir}/.." && pwd)"
edgeDir="${repoRoot}/platform/edgeNginx"

configureEdgeNginx() {
  if [[ ! -d "${edgeDir}" ]]; then
    echo "Missing ${edgeDir}"
    exit 1
  fi

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Re-run with sudo:"
    echo "  sudo ${scriptDir}/configureEdgeNginx.sh"
    exit 1
  fi

  shopt -s nullglob
  local configs=("${edgeDir}"/*.conf)
  if [[ ${#configs[@]} -eq 0 ]]; then
    echo "No *.conf files in ${edgeDir}"
    exit 1
  fi

  mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

  for edgeTemplate in "${configs[@]}"; do
    local siteName
    siteName="$(basename "${edgeTemplate}")"
    local nginxSite="/etc/nginx/sites-available/${siteName}"
    local domain="${siteName%.conf}"
    local leCert="/etc/letsencrypt/live/${domain}/fullchain.pem"

    if [[ -f "${nginxSite}" ]]; then
      cp "${nginxSite}" "${nginxSite}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    cp "${edgeTemplate}" "${nginxSite}"
    ln -sf "${nginxSite}" "/etc/nginx/sites-enabled/${siteName}"

    if [[ ! -f "${leCert}" ]]; then
      echo "Warning: ${leCert} not found — HTTPS block for ${domain} needs a cert for nginx to reload."
    fi

    echo "Installed edge vhost: ${nginxSite}"
  done

  nginx -t
  systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || nginx -s reload

  echo "Edge nginx updated (${#configs[@]} site(s))."
  echo "  HTTP  → ingress NodePort 30080"
  echo "  HTTPS → ingress NodePort 30443 (TLS from cert-manager in cluster)"
}

configureEdgeNginx "$@"
