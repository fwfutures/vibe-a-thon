---
name: gcp-deploy
description: Deploy containerised applications to Google Cloud Run from source using gcloud CLI. Use when the user asks to "deploy to GCP", "deploy to Cloud Run", "ship to Google Cloud", "gcloud run deploy", or needs to set up, redeploy, configure env vars/secrets, view logs, or troubleshoot a Cloud Run service.
---

# GCP Cloud Run Deploy

Deploy from source to Cloud Run in a single command. Requires: a GCP project, a Dockerfile in the repo root, and an app that listens on a port (default 8080 / `PORT` env var).

## Quick Deploy

```bash
# 1. Auth (skip if already logged in)
gcloud auth login
gcloud config set project PROJECT_ID

# 2. Enable APIs (first time only)
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

# 3. Deploy
gcloud run deploy SERVICE_NAME \
  --source . \
  --region australia-southeast1 \
  --allow-unauthenticated
```

This builds the container remotely via Cloud Build, pushes to Artifact Registry, deploys to Cloud Run, and returns a public HTTPS URL. Redeploy by re-running the same command.

## Deploy Script

Copy `scripts/deploy.sh` into the project root for one-command deploys:

```bash
chmod +x deploy.sh
./deploy.sh my-service
```

Env vars: `GCP_REGION` (default `australia-southeast1`), `GCP_PROJECT` (default: current gcloud project).

## Common Flags

| Flag | Purpose | Example |
|---|---|---|
| `--region` | Deployment region | `australia-southeast1` |
| `--allow-unauthenticated` | Public access | |
| `--port` | Container port (if not 8080) | `--port 3000` |
| `--set-env-vars` | Env vars | `--set-env-vars KEY=val,FOO=bar` |
| `--set-secrets` | Secret Manager secrets | `--set-secrets ENV=SECRET:latest` |
| `--memory` | Memory | `--memory 512Mi` |
| `--cpu` | CPU | `--cpu 1` |
| `--min-instances` | Min instances (0 = scale to zero) | `--min-instances 0` |
| `--max-instances` | Max instances | `--max-instances 3` |
| `--timeout` | Request timeout (max 3600) | `--timeout 300` |

## Environment Variables and Secrets

Inline env vars:

```bash
gcloud run deploy SERVICE --source . --region REGION --allow-unauthenticated \
  --set-env-vars "DATABASE_URL=postgres://...,API_KEY=abc123"
```

Secret Manager (recommended for sensitive values):

```bash
# Create secret
echo -n "secret-value" | gcloud secrets create MY_SECRET --data-file=-

# Grant access to default compute SA
gcloud secrets add-iam-policy-binding MY_SECRET \
  --member="serviceAccount:$(gcloud iam service-accounts list --format='value(email)' --filter='displayName:Compute Engine default')" \
  --role="roles/secretmanager.secretAccessor"

# Deploy with secret
gcloud run deploy SERVICE --source . --region REGION --allow-unauthenticated \
  --set-secrets "MY_SECRET=MY_SECRET:latest"
```

## Useful Commands

```bash
# Stream logs
gcloud run services logs tail SERVICE --region REGION

# List services
gcloud run services list --region REGION

# Get service URL
gcloud run services describe SERVICE --region REGION --format "value(status.url)"

# Delete service
gcloud run services delete SERVICE --region REGION
```

## Build Failure Diagnostics (Cloud Run `--source`)

When `gcloud run deploy --source .` fails with a generic "Build failed" message, inspect Cloud Build directly:

```bash
# 1) List recent builds (global default)
gcloud builds list --limit=10 --sort-by=~createTime

# 2) Show details, including logUrl and per-step status
gcloud builds describe BUILD_ID

# 3) Stream logs for that build
gcloud builds log BUILD_ID --stream
```

For regional/2nd-gen build resources, include `--region`:

```bash
gcloud builds list --region REGION --limit=10 --sort-by=~createTime
gcloud builds describe BUILD_ID --region REGION
gcloud builds log BUILD_ID --region REGION --stream
```

If no build is visible after a failed source deploy, run an explicit build to surface the exact Docker push/build error:

```bash
gcloud builds submit --tag REGION-docker.pkg.dev/PROJECT_ID/REPO/IMAGE:debug
```

## CI/Headless Auth

```bash
gcloud auth activate-service-account --key-file=key.json
gcloud config set project PROJECT_ID
```

## Troubleshooting

| Issue | Fix |
|---|---|
| Build fails (generic from `run deploy`) | Use `gcloud builds list`, `gcloud builds describe BUILD_ID`, and `gcloud builds log BUILD_ID --stream` |
| Build cannot push image (`artifactregistry.repositories.uploadArtifacts` denied) | Grant build SA `roles/artifactregistry.writer` on project/repo; if needed also grant `roles/logging.logWriter` |
| 403 on deploy | Need `roles/run.admin` and `roles/cloudbuild.builds.editor` |
| App crashes on start | Check logs: `gcloud run services logs tail SERVICE --region REGION` |
| Port mismatch | Set `--port` to match app, or have app read `PORT` env var |
| Cold start slow | Set `--min-instances 1` (stays warm, costs more) |
| Timeout on long requests | Increase with `--timeout 300` (max 3600s) |

### IAM fix for Artifact Registry push failures

```bash
PROJECT_ID=your-project-id
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

# Build SA may be compute default in newer projects
BUILD_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$BUILD_SA" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$BUILD_SA" \
  --role="roles/logging.logWriter"
```

If your project uses the Cloud Build legacy SA, grant the same roles to:
`$PROJECT_NUMBER@cloudbuild.gserviceaccount.com`.
