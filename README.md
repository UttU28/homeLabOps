# homeLabOps

GitOps manifests for the homelab Kubernetes cluster (`supernova`).  
**App code and Docker builds stay in app repos**; routing, ingress, and TLS live here (org-style).

## Layout

```text
homeLabOps/
├── platform/
│   ├── certManager/         # cert-manager + Let's Encrypt ClusterIssuer
│   ├── ingressNginx/        # ingress-nginx controller (NodePorts 30080/30443)
│   └── edgeNginx/           # optional host edge proxy templates (homelab)
├── apps/saralJobViewer/     # app workloads + Ingress (routing in GitOps)
├── argocd/                  # Argo CD Application manifests
└── scripts/
```

## Org-style flow

```text
Push Saral code → CI → GHCR → bump image tag here → Argo syncs
                                                      ├── Ingress (routes + TLS)
                                                      ├── Deployments / Services (ClusterIP)
                                                      └── cert-manager issues saral-tls
Host edge nginx (optional) → proxies :80/:443 → ingress NodePorts
```

| Concern | Repo |
|---------|------|
| App source, Dockerfile, CI | `Saral-Job-Viewer` |
| Deployments, Services, **Ingress**, image tags | **homeLabOps** |
| Platform (ingress-nginx, cert-manager) | **homeLabOps/platform** |
| Host edge proxy (single-server homelab) | **homeLabOps/platform/edgeNginx** |

## Quick start

```bash
# 1) Platform (once per cluster)
./scripts/bootstrapPlatform.sh
# wait until cert-manager + ingress-nginx are Synced/Healthy in Argo

# 2) App secrets + Argo apps
./scripts/createSaralSecrets.sh
./scripts/bootstrapArgoApps.sh

# 3) Host edge nginx (homelab — proxies to in-cluster ingress)
sudo ./scripts/configureEdgeNginx.sh

# 4) Smoke test
curl -s http://127.0.0.1:30080/api/health -H 'Host: saral.thatinsaneguy.com'
```

## GitHub repos

| Repo | Role |
|------|------|
| [Saral-Job-Viewer](https://github.com/UttU28/Saral-Job-Viewer) | App source + CI only |
| **homeLabOps** | GitOps — platform + apps + ingress |

## Secrets (GitHub Actions — Saral repo)

| Secret | Purpose |
|--------|---------|
| `HOMELABOPS_GIT_TOKEN` | PAT — commit tag bumps to homeLabOps |

## ClusterIssuer email

Edit `platform/certManager/clusterIssuer.yaml` (`certs@thatinsaneguy.com`) if needed.

## Scraping

`Saral-Job-Viewer/scraping/` stays **off cluster** (local cron/PM2 only).
