# Homelab GitOps Setup — Saral Job Viewer

How we wired **Saral-Job-Viewer** to **Kubernetes + Argo CD + GitHub Actions** on `supernova`, org-style (separate app repo + gitops repo).

---

## Architecture (org-style)

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  Saral-Job-Viewer (app repo)                                            │
│  backend/ frontend/ docker/  +  .github/workflows/homelabBuildAndDeploy │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ push cid / main
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  GitHub Actions (self-hosted runner: supernova)                         │
│  buildApi + buildUi + buildRedis → GHCR → bump tags in homeLabOps       │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  homeLabOps (gitops repo) — UttU28/homeLabOps                           │
│  platform/ + apps/saralJobViewer/ + argocd/                             │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ Argo CD watches main
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Kubernetes (supernova) — namespace saral                               │
│  Deployments + Ingress + cert-manager TLS                               │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Host edge nginx → ingress NodePorts 30080 / 30443                      │
│  https://saral.thatinsaneguy.com                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

**Scraping** (`Saral-Job-Viewer/scraping/`) stays **off cluster** — local cron/PM2 only.

---

## Two repos — who owns what

| Repo | Role | Push triggers |
|------|------|----------------|
| **Saral-Job-Viewer** | App source, Dockerfiles, CI workflow | Builds images only |
| **homeLabOps** | K8s manifests, Ingress, platform, image tags | Updated by CI (not you manually) |

Prod domain updates when you **push app code** — not when you edit homeLabOps by hand (except platform/bootstrap).

---

## GitHub secrets & PATs

### Saral-Job-Viewer → Settings → Secrets → Actions

| Secret | Scopes / notes | Why |
|--------|----------------|-----|
| **`HOMELABOPS_GIT_TOKEN`** | PAT: `repo` | CI clones + commits tag bumps to `homeLabOps` |
| **`GITHUB_TOKEN`** | Automatic | Push images to GHCR |

### Personal Access Tokens (your GitHub account)

| Token name | Scopes | Used for |
|------------|--------|----------|
| **homeLabOps** | `repo`, `workflow` | Local `git push` to Saral (workflow files need `workflow` scope) |
| **dedsec995** (optional) | broad incl. `workflow` | General git / admin |

**Important:** Pushing `.github/workflows/*` over HTTPS requires **`workflow`** scope on the PAT — not just `repo`.

### Cluster secrets (not in GitHub)

Created on the cluster from local files:

```bash
cd ~/Desktop/homeLabOps
./scripts/createSaralSecrets.sh
```

| K8s secret | Source | Why |
|------------|--------|-----|
| `saral-backend-env` | `Saral-Job-Viewer/backend/.env` | API env vars |
| `saral-gmail-client` | `backend/client_secret.json` | Gmail OAuth (mounted at runtime, not in image) |

---

## Self-hosted GitHub runner

| Item | Value |
|------|--------|
| Install path | `~/actions-runner` |
| Runner name | `supernova` |
| Scope | Repo: **Saral-Job-Viewer** |
| Service | `actions.runner.UttU28-Saral-Job-Viewer.supernova.service` |

```bash
cd ~/actions-runner
sudo ./svc.sh status          # must run FROM this directory
sudo systemctl restart actions.runner.UttU28-Saral-Job-Viewer.supernova.service
```

One runner → build jobs run **sequentially** (api → ui → redis → bumpGitOps). Add more runners for parallel builds.

---

## CI workflow — Saral-Job-Viewer

**File:** `.github/workflows/homelabBuildAndDeploy.yml`

| Trigger | Branches |
|---------|----------|
| `push` | `cid`, `main` |
| Paths | `backend/**`, `frontend/**`, `docker/**`, `docker-compose.yml`, workflow file |
| Manual | `workflow_dispatch` |

**Jobs (all run every time):**

1. `buildApi` — `docker/Dockerfile.api` → `ghcr.io/uttu28/saral-api:<sha>`
2. `buildUi` — `docker/Dockerfile.frontend` → `ghcr.io/uttu28/saral-ui:<sha>`
3. `buildRedis` — `docker/Dockerfile.redis` → `ghcr.io/uttu28/saral-redis:<sha>`
4. `bumpGitOps` — updates `apps/saralJobViewer/kustomization.yaml` in homeLabOps, commits + pushes

Uses plain `docker build` / `docker push` (no Buildx — not installed on Arch runner).

**`client_secret.json`** is **not** baked into the API image (gitignored). Mounted at runtime via K8s secret / compose volume.

---

## homeLabOps — files & why

### `apps/saralJobViewer/` — app workloads (GitOps)

| File | Why |
|------|-----|
| `namespace.yaml` | `saral` namespace |
| `kustomization.yaml` | Image tags (CI bumps `newTag` here) |
| `api/deployment.yaml` | API pod, env from secret, gmail + docker.sock mounts |
| `api/service.yaml` | ClusterIP :9260 |
| `frontend/deployment.yaml` | UI pod |
| `frontend/service.yaml` | ClusterIP :9261 |
| `redis/deployment.yaml` | Redis pod |
| `redis/service.yaml` | ClusterIP :9262 (internal only) |
| `ingress.yaml` | **Org-style routing** — `/api` → api, `/` → ui, TLS via cert-manager |

Services are **ClusterIP** (not NodePort). External access is through **Ingress**, not per-app host ports.

### `platform/` — shared cluster infra (org-style)

| Path | Why |
|------|-----|
| `certManager/` | cert-manager install + `ClusterIssuer` (Let's Encrypt HTTP-01) |
| `ingressNginx/` | ingress-nginx controller, NodePorts **30080** (http) / **30443** (https) |
| `edgeNginx/saral.thatinsaneguy.com.conf` | Homelab edge: host nginx proxies domain → ingress (single-server pattern) |

### `argocd/` — Argo CD Application CRs

| File | Sync wave | Why |
|------|-----------|-----|
| `certManagerApplication.yaml` | 0 | TLS issuer must exist first |
| `ingressNginxApplication.yaml` | 1 | Ingress controller before app Ingress |
| `saralJobViewerApplication.yaml` | 2 | App + Ingress for Saral |

### `scripts/`

| Script | Why |
|--------|-----|
| `bootstrapPlatform.sh` | Register cert-manager + ingress-nginx Argo apps |
| `bootstrapArgoApps.sh` | Register all Argo apps (waits for ingress webhook) |
| `createSaralSecrets.sh` | Create `saral-backend-env` + `saral-gmail-client` in cluster |
| `applySaralLocally.sh` | `kubectl apply -k` without Argo (smoke test) |
| `updateImageTags.sh` | Manually bump image tags in kustomization (CI does this automatically) |
| `configureEdgeNginx.sh` | Install host edge vhost → ingress NodePorts |
| `configureHostNginx.sh` | Wrapper → `configureEdgeNginx.sh` (deprecated name) |

---

## Saral-Job-Viewer — related files

| File | Status | Why |
|------|--------|-----|
| `.github/workflows/homelabBuildAndDeploy.yml` | **Active** | CI build + gitops bump |
| `docker/Dockerfile.api` | Active | API image (no client_secret COPY) |
| `docker/Dockerfile.frontend` | Active | UI image + `VITE_API_URL` |
| `docker/Dockerfile.redis` | Active | Redis image |
| `docker-compose.yml` | Local dev | Full stack on loopback 9260/9261 |
| `deploy.sh` / `backend/deploy.sh` | **Local dev only** | Docker compose deploy — **not** prod path anymore |
| `backend/nginx-saral.conf` | Deprecated | Routing moved to homeLabOps Ingress |
| `backend/configureHostNginx.sh` | Deprecated | Forwards to homeLabOps edge script |

**Prod deploy:** `git push origin cid` (or `main`) — not `./deploy.sh`.

---

## Bootstrap order (one-time + after clone)

```bash
# 1) Cluster already has: kubeadm, Calico, Argo CD, CoreDNS fix (8.8.8.8 / 1.1.1.1)

# 2) Platform
cd ~/Desktop/homeLabOps
./scripts/bootstrapPlatform.sh
# Wait: Argo → cert-manager + ingress-nginx → Synced / Healthy

# 3) App secrets + Argo apps
./scripts/createSaralSecrets.sh
./scripts/bootstrapArgoApps.sh
# Wait: saral-job-viewer → Synced / Healthy

# 4) Host edge (homelab)
sudo ./scripts/configureEdgeNginx.sh

# 5) Self-hosted runner (already on supernova)
# GitHub → Saral-Job-Viewer → Settings → Actions → Runners
```

---

## Day-to-day deploy flow

```bash
# Edit code locally
cd ~/Desktop/Saral-Job-Viewer
git add backend/ frontend/
git commit -m "your change"
git push origin cid

# Automatically:
# → Actions on supernova builds images
# → GHCR receives saral-api, saral-ui, saral-redis
# → homeLabOps kustomization.yaml tag bump
# → Argo CD syncs → pods roll → https://saral.thatinsaneguy.com updates
```

---

## Fixes we hit along the way

| Problem | Cause | Fix |
|---------|-------|-----|
| Argo `ComparisonError` DNS | CoreDNS forwarded to router `192.168.0.1`, pods couldn't reach it | Patch CoreDNS → `forward . 8.8.8.8 1.1.1.1` |
| Invalid K8s names | camelCase in `metadata.name` | kebab-case: `saral-backend-env`, `saral-job-viewer`, `gmail-client-secret` |
| `docker buildx` missing | Self-hosted Arch has no buildx | Plain `docker build` in workflow |
| `client_secret.json` not found in CI | File gitignored | Remove from Dockerfile; mount at runtime |
| `HOMELABOPS_GIT_TOKEN` empty | Secret missing on Saral repo | Add PAT with `repo` scope |
| Push workflow rejected | PAT missing `workflow` scope | Add `workflow` to PAT used for local git push |
| **502 Bad Gateway** | Edge nginx → ingress before Saral Ingress existed | Wait for ingress-nginx webhook, re-sync Argo app |
| Multiple ReplicaSets in Argo tree | Normal K8s rollout history | Only 1 pod Running per deployment (`replicas: 1`) |

---

## Useful commands

```bash
# Argo apps
kubectl get applications -n argocd

# Saral pods
kubectl get pods,ingress,certificate -n saral

# Test ingress locally
curl -sL http://127.0.0.1:30080/api/health -H 'Host: saral.thatinsaneguy.com'

# Force Argo sync
kubectl patch application saral-job-viewer -n argocd --type merge \
  -p '{"operation":{"sync":{"revision":"main","prune":true}}}'

# Runner logs
journalctl -u actions.runner.UttU28-Saral-Job-Viewer.supernova.service -f
```

---

## GHCR images

| Image | Tag source |
|-------|------------|
| `ghcr.io/uttu28/saral-api` | CI commit SHA (7 chars) |
| `ghcr.io/uttu28/saral-ui` | same |
| `ghcr.io/uttu28/saral-redis` | same |

If packages are **private**, cluster needs `imagePullSecrets` or make packages public on GitHub.

---

## What we intentionally did **not** put in gitops

- App source code
- `backend/.env` / `client_secret.json` (cluster secrets only)
- Scraping scripts
- Docker builds (happen in CI, not on cluster)

---

## Paths on disk

| Path | Purpose |
|------|---------|
| `~/Desktop/Saral-Job-Viewer` | App repo |
| `~/Desktop/homeLabOps` | GitOps repo |
| `~/actions-runner` | GitHub self-hosted runner |
| `/etc/nginx/sites-available/saral.thatinsaneguy.com` | Host edge (from `platform/edgeNginx/`) |

---

*Last updated: homelab pilot on supernova — Saral Job Viewer as first GitOps app.*
