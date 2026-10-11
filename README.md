# Deploy and Host Langfuse with Railway

Langfuse is an open-source LLM engineering platform for tracing, evaluating and cost-tracking LLM applications and agents. This community template deploys the complete Langfuse v4 stack on Railway: web app, background worker, ClickHouse, Postgres, Redis and a Railway Bucket, with the first organization, project, API keys and admin account created automatically.

## About Hosting Langfuse

Self-hosted Langfuse v4 is not a single container. The web service receives traces from the Langfuse SDKs, OpenTelemetry or integrations such as LiteLLM and stores each raw event in S3-compatible storage. A separate worker turns those events into rows in ClickHouse, the analytical database that powers the trace explorer, dashboards and full-text search. Postgres stores users, projects, prompts and API keys, and Redis carries the job queues and caches. This template wires all of it together over Railway's private network, generates every secret, keeps ClickHouse tuned for a small footprint and uses a Railway Bucket for event, media and export storage, so you get a production-shaped deployment without editing configuration files.

## Common Use Cases

- Trace every LLM call, tool call and agent step in production, with latency, token usage and cost per request.
- Version and deploy prompts from a central prompt registry, then compare prompt versions with datasets and experiments.
- Run LLM-as-a-judge and human annotation workflows to score answer quality over time.
- Keep LLM telemetry inside your own infrastructure for data-residency or compliance reasons.
- Act as the observability backend for an LLM gateway such as LiteLLM.

## Dependencies for Langfuse Hosting

- Langfuse web (`langfuse/langfuse`) and worker (`langfuse/langfuse-worker`) images, version 4.56.0
- ClickHouse 26.8 LTS (Langfuse v4 needs 25.12 or newer)
- PostgreSQL (Railway Postgres 18)
- Redis (Railway Redis 8.2)
- S3-compatible object storage (Railway Bucket)

### Deployment Dependencies

- Langfuse self-hosting guide: https://langfuse.com/self-hosting
- Configuration reference: https://langfuse.com/self-hosting/configuration
- Headless initialization: https://langfuse.com/self-hosting/administration/headless-initialization
- ClickHouse requirements: https://langfuse.com/self-hosting/deployment/infrastructure/clickhouse
- Blob storage (S3) settings: https://langfuse.com/self-hosting/deployment/infrastructure/blobstorage
- Upstream docker-compose: https://github.com/langfuse/langfuse/blob/main/docker-compose.yml
- Railway Buckets: https://docs.railway.com/storage-buckets

### Implementation Details

| Service | Role | Public | Storage |
|---|---|---|---|
| langfuse-web | UI, public API, OTLP endpoint, migrations | Yes (port 3000) | – |
| langfuse-worker | Queue processing, evaluations, exports | No | – |
| ClickHouse | Traces, observations, scores | No | Volume `/var/lib/clickhouse` |
| Postgres | Users, projects, prompts, keys | No | Volume |
| Redis | Queues and cache | No | Volume |
| Bucket | Raw events, media, batch exports | – | Railway Bucket |

**First login**

1. Enter your email in `LANGFUSE_INIT_USER_EMAIL` when deploying (the only required input).
2. Wait for `langfuse-web` to become healthy (first start runs database migrations and can take several minutes).
3. Open the web domain and sign in with that email and the generated `LANGFUSE_INIT_USER_PASSWORD` from the `langfuse-web` variables. Change the password in your profile.
4. Use `LANGFUSE_INIT_PROJECT_PUBLIC_KEY` and `LANGFUSE_INIT_PROJECT_SECRET_KEY` with `LANGFUSE_HOST=https://{your-web-domain}` in the Langfuse SDKs.

Public sign-up is disabled (`AUTH_DISABLE_SIGNUP=true`). To let invited teammates create accounts, set it to `false`, invite them, and switch it back once they have joined.

**Scaling:** add replicas to `langfuse-worker` for higher ingestion throughput and to `langfuse-web` for more API/UI traffic; both are stateless. ClickHouse scales vertically (more RAM/CPU) on Railway.

**Pinning and upgrades:** web and worker are pinned to `4.56.0`; always upgrade both to the same version. Change the image tag on both services, check the Langfuse changelog for breaking changes, and redeploy; migrations run automatically on web start. ClickHouse is pinned in `services/clickhouse/Dockerfile`.

### Why Deploy Langfuse on Railway?

Railway runs the five services and the bucket as one project with private networking, generated secrets, volumes and per-second usage billing, so you can operate a full Langfuse v4 stack without managing servers or Kubernetes. Scaling the worker or web service is a replica setting, and upgrades are an image tag change.
