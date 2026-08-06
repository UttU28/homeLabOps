# homeLabOps

GitOps manifests for the homelab Kubernetes cluster (`supernova`).  
Argo CD watches this repo; **app code and Docker builds stay in app repos** (e.g. `Saral-Job-Viewer`).

## Layout

```text
homeLabOps/
├── apps/saralJobViewer/     # Kustomize — api, ui, redis (1 replica each)
├── argocd/                  # Argo CD Application manifests
└── scripts/                 # bootstrap, secrets, local apply, image tags
```

## Quick start

```bash
# 1) Create K8s secrets from Saral backend env (once per cluster)
./scripts/createSaralSecrets.sh

# 2) Register app with Argo CD
./scripts/bootstrapArgoApps.sh

# 3) Or apply without Argo (smoke test)
./scripts/applySaralLocally.sh
```

## GitHub repos

| Repo | Role |
|------|------|
| [Saral-Job-Viewer](https://github.com/UttU28/Saral-Job-Viewer) | App source + `.github/workflows/homelabBuildAndDeploy.yml` |
| **homeLabOps** (this repo) | Deploy manifests only — image tags updated by CI |

Push to `main` on Saral → Actions builds images → GHCR → bumps tags here → Argo syncs.

## Secrets (GitHub Actions — Saral repo)

| Secret | Purpose |
|--------|---------|
| `GITHUB_TOKEN` | Push to GHCR (built-in) |
| `HOMELABOPS_GIT_TOKEN` | PAT with `repo` scope — commit tag bumps to homeLabOps |
| `HOMELABOPS_REPO` | `UttU28/homeLabOps` |

## Local paths

Scripts assume Saral lives at `~/Desktop/Saral-Job-Viewer`. Override:

```bash
export saralAppRoot=/path/to/Saral-Job-Viewer
```

## Scraping

`Saral-Job-Viewer/scraping/` stays **off cluster** (local cron/PM2 only).
