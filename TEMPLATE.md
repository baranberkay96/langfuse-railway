# Langfuse v4 LLM Observability Stack — Railway template spec

## Listing

- **Name:** Langfuse v4 LLM Observability Stack (LISTINGS.md name with the pinned major version inserted after the software name)
- **Description (75 chars):** Trace, evaluate and cost-track every LLM call. Langfuse v4 with ClickHouse.
  - Changed from LISTINGS.md ("... Langfuse v3 with ClickHouse.") because the current stable Langfuse release is v4.56.0; v3 is the previous major. Same length.
- **Category:** AI/ML
- **Tags:** langfuse, llm, observability, tracing, evaluation, clickhouse, opentelemetry

## Base market template

- **Chosen base: `exma_H` "Langfuse v3"** (158 active / 691 total projects). It already had the right topology (web + worker + ClickHouse + Redis + Postgres + object storage). Kept: service split, ClickHouse on a volume, shared variable layout between web and worker.
- `gmbqa_` "Langfuse v2": single container on Langfuse v2 (Postgres only). Obsolete architecture; nothing taken.
- `agentic-data-stack-lite-langfuse-cloud`: a LibreChat + ClickHouse MCP demo that sends traces to Langfuse Cloud; not a self-hosted Langfuse. Nothing taken.
- `_upstream`: none for this app.

## Pinned versions

| Service | Image / source | Tag | Release date | Checked |
|---|---|---|---|---|
| langfuse-web | `langfuse/langfuse` | `4.56.0` | 2026-10-09 | 2026-10-10 |
| langfuse-worker | `langfuse/langfuse-worker` | `4.56.0` | 2026-10-09 | 2026-10-10 |
| ClickHouse | `clickhouse/clickhouse-server` (Dockerfile in `services/clickhouse`) | `26.8.23.6` (26.8 LTS line) | 2026-10-10 build | 2026-10-10 |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl` | `18` | Railway base | 2026-10-10 |
| Redis | `redis` | `8.2` | Railway base | 2026-10-10 |
| Bucket | Railway Bucket (S3-compatible) | n/a | n/a | 2026-10-10 |

Langfuse v4 requires ClickHouse >= 25.12 (26.4+ recommended), Postgres >= 15, Redis >= 7. The upstream compose still pins ClickHouse 25.12; this template uses the newer 26.8 LTS line, which satisfies the documented minimum and recommendation.

## Architecture

Only `langfuse-web` is public. Everything else talks over Railway private networking (`*.railway.internal`). The bucket is reached over its public S3 endpoint (Railway Buckets have no private networking).

```
            HTTPS (public domain)
                    |
             [langfuse-web :3000] ----------------------+
              |      |       |                          |
   Prisma     |      | HTTP  | ioredis (queues/cache)   | S3 (events, media, exports)
              v      v       v                          v
        [Postgres] [ClickHouse :8123/:9000] [Redis]   [Bucket] (t3.storageapi.dev)
              ^      ^       ^                          ^
              |      |       |                          |
             [langfuse-worker :3030 /api/health] -------+
```

- SDKs send traces to `langfuse-web` (`/api/public/ingestion`, OTLP `/api/public/otel`). Web writes the raw event to the bucket and enqueues a job in Redis.
- `langfuse-worker` consumes the queue, reads the event from the bucket and writes traces/observations/scores to ClickHouse; it also runs evaluations, exports and retention jobs.
- Postgres holds users, orgs, projects, prompts, API keys and settings. ClickHouse holds all tracing data.
- On first boot `langfuse-web` runs Postgres and ClickHouse migrations, then creates the initial organization, project, API keys and admin user from the `LANGFUSE_INIT_*` variables.

## Services

### langfuse-web

Next.js app + public API. Runs Postgres and ClickHouse migrations on start and performs headless initialization.

- Source: image `langfuse/langfuse:4.56.0`
- Start command: image default
- Pre-deploy command: none
- Healthcheck: `/api/public/ready` (timeout 600 s)
- Public domain: yes, target port `3000`
- TCP proxy: none
- Volume: none
- Restart policy: ON_FAILURE (max 10 retries); replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `PORT` | `3000` | HTTP port of the Next.js server (Railway routes the public domain here). |
| `HOSTNAME` | `::` | Bind address; :: listens on IPv4 and IPv6. |
| `NEXTAUTH_SECRET` | `${{secret(32)}}` | Signs session cookies. Generated once. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Postgres connection string (private network). Prisma migrations run automatically on web start. |
| `NEXTAUTH_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL of this service; used for login callbacks and links. |
| `SALT` | `${{secret(32)}}` | Salt for hashing API keys. Generated once; never change after first deploy. |
| `ENCRYPTION_KEY` | `${{secret(64, "abcdef0123456789")}}` | 256-bit hex key that encrypts stored LLM credentials. Generated once; never change. |
| `CLICKHOUSE_URL` | `http://${{ClickHouse.RAILWAY_PRIVATE_DOMAIN}}:8123` | ClickHouse HTTP endpoint (private network). |
| `CLICKHOUSE_MIGRATION_URL` | `clickhouse://${{ClickHouse.RAILWAY_PRIVATE_DOMAIN}}:9000` | ClickHouse native endpoint used for schema migrations. |
| `CLICKHOUSE_USER` | `${{ClickHouse.CLICKHOUSE_USER}}` | ClickHouse user (reference). |
| `CLICKHOUSE_PASSWORD` | `${{ClickHouse.CLICKHOUSE_PASSWORD}}` | ClickHouse password (reference). |
| `CLICKHOUSE_CLUSTER_ENABLED` | `false` | Single ClickHouse node: do not run DDL ON CLUSTER. |
| `REDIS_CONNECTION_STRING` | `${{Redis.REDIS_URL}}?family=0` | Redis URL for queues and cache. family=0 lets ioredis use IPv4 or IPv6 private DNS. |
| `LANGFUSE_S3_EVENT_UPLOAD_BUCKET` | `${{Bucket.BUCKET}}` | Railway Bucket name for event uploads. |
| `LANGFUSE_S3_EVENT_UPLOAD_PREFIX` | `events/` | Key prefix for event objects inside the bucket. |
| `LANGFUSE_S3_EVENT_UPLOAD_REGION` | `${{Bucket.REGION}}` | Bucket region (Railway Buckets use auto). |
| `LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Bucket S3 endpoint (public; also used for presigned media URLs). |
| `LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` | Bucket access key. |
| `LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` | Bucket secret key. |
| `LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE` | `false` | Railway Buckets use virtual-hosted-style URLs. |
| `LANGFUSE_S3_MEDIA_UPLOAD_BUCKET` | `${{Bucket.BUCKET}}` | Railway Bucket name for media uploads. |
| `LANGFUSE_S3_MEDIA_UPLOAD_PREFIX` | `media/` | Key prefix for media objects inside the bucket. |
| `LANGFUSE_S3_MEDIA_UPLOAD_REGION` | `${{Bucket.REGION}}` | Bucket region (Railway Buckets use auto). |
| `LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Bucket S3 endpoint (public; also used for presigned media URLs). |
| `LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` | Bucket access key. |
| `LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` | Bucket secret key. |
| `LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE` | `false` | Railway Buckets use virtual-hosted-style URLs. |
| `LANGFUSE_S3_BATCH_EXPORT_ENABLED` | `true` | Enable CSV/JSON batch exports from the UI, written to the bucket. |
| `LANGFUSE_S3_BATCH_EXPORT_BUCKET` | `${{Bucket.BUCKET}}` | Railway Bucket name for batch exports. |
| `LANGFUSE_S3_BATCH_EXPORT_PREFIX` | `exports/` | Key prefix for exports. |
| `LANGFUSE_S3_BATCH_EXPORT_REGION` | `${{Bucket.REGION}}` | Bucket region. |
| `LANGFUSE_S3_BATCH_EXPORT_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Bucket S3 endpoint used to upload exports. |
| `LANGFUSE_S3_BATCH_EXPORT_EXTERNAL_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Endpoint used in presigned download links (public bucket endpoint). |
| `LANGFUSE_S3_BATCH_EXPORT_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` | Bucket access key. |
| `LANGFUSE_S3_BATCH_EXPORT_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` | Bucket secret key. |
| `LANGFUSE_S3_BATCH_EXPORT_FORCE_PATH_STYLE` | `false` | Railway Buckets use virtual-hosted-style URLs. |
| `TELEMETRY_ENABLED` | `true` | Anonymous usage telemetry to Langfuse (upstream default). Set false to opt out. |
| `AUTH_DISABLE_SIGNUP` | `true` | Public sign-up is off; the admin below is created headlessly. Set false temporarily to let invited teammates create accounts. |
| `LANGFUSE_INIT_ORG_ID` | `railway-org` | ID of the organization created on first start (headless init). |
| `LANGFUSE_INIT_ORG_NAME` | `My Organization` | Display name of the initial organization. |
| `LANGFUSE_INIT_PROJECT_ID` | `railway-project` | ID of the project created on first start. |
| `LANGFUSE_INIT_PROJECT_NAME` | `My Project` | Display name of the initial project. |
| `LANGFUSE_INIT_PROJECT_PUBLIC_KEY` | `pk-lf-${{secret(32, "abcdef0123456789")}}` | Project public API key (LANGFUSE_PUBLIC_KEY for SDKs). Generated. |
| `LANGFUSE_INIT_PROJECT_SECRET_KEY` | `sk-lf-${{secret(32, "abcdef0123456789")}}` | Project secret API key (LANGFUSE_SECRET_KEY for SDKs). Generated; keep private. |
| `LANGFUSE_INIT_USER_EMAIL` | `` | Email of the first admin user (organization owner). Used to sign in. **(required input)** |
| `LANGFUSE_INIT_USER_NAME` | `Admin` | Display name of the first admin user. |
| `LANGFUSE_INIT_USER_PASSWORD` | `${{secret(24, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Password of the first admin user. Generated; read it from this variable and change it after first login. |

### langfuse-worker

Background processor (ingestion queue, evaluations, batch exports, retention). Stateless; scale with replicas.

- Source: image `langfuse/langfuse-worker:4.56.0`
- Start command: image default
- Pre-deploy command: none
- Healthcheck: `/api/health` (timeout 600 s)
- Public domain: no (listens on `3030` privately)
- TCP proxy: none
- Volume: none
- Restart policy: ON_FAILURE (max 10 retries); replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `PORT` | `3030` | Worker HTTP port (health endpoint only). |
| `HOSTNAME` | `::` | Bind address; :: listens on IPv4 and IPv6. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Postgres connection string (private network). Prisma migrations run automatically on web start. |
| `NEXTAUTH_URL` | `${{langfuse-web.NEXTAUTH_URL}}` | Public URL of langfuse-web; used to build links in emails and integrations. |
| `SALT` | `${{langfuse-web.SALT}}` | Must be identical to langfuse-web (hashes API keys). |
| `ENCRYPTION_KEY` | `${{langfuse-web.ENCRYPTION_KEY}}` | Must be identical to langfuse-web (encrypts stored secrets). |
| `CLICKHOUSE_URL` | `http://${{ClickHouse.RAILWAY_PRIVATE_DOMAIN}}:8123` | ClickHouse HTTP endpoint (private network). |
| `CLICKHOUSE_MIGRATION_URL` | `clickhouse://${{ClickHouse.RAILWAY_PRIVATE_DOMAIN}}:9000` | ClickHouse native endpoint used for schema migrations. |
| `CLICKHOUSE_USER` | `${{ClickHouse.CLICKHOUSE_USER}}` | ClickHouse user (reference). |
| `CLICKHOUSE_PASSWORD` | `${{ClickHouse.CLICKHOUSE_PASSWORD}}` | ClickHouse password (reference). |
| `CLICKHOUSE_CLUSTER_ENABLED` | `false` | Single ClickHouse node: do not run DDL ON CLUSTER. |
| `REDIS_CONNECTION_STRING` | `${{Redis.REDIS_URL}}?family=0` | Redis URL for queues and cache. family=0 lets ioredis use IPv4 or IPv6 private DNS. |
| `LANGFUSE_S3_EVENT_UPLOAD_BUCKET` | `${{Bucket.BUCKET}}` | Railway Bucket name for event uploads. |
| `LANGFUSE_S3_EVENT_UPLOAD_PREFIX` | `events/` | Key prefix for event objects inside the bucket. |
| `LANGFUSE_S3_EVENT_UPLOAD_REGION` | `${{Bucket.REGION}}` | Bucket region (Railway Buckets use auto). |
| `LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Bucket S3 endpoint (public; also used for presigned media URLs). |
| `LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` | Bucket access key. |
| `LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` | Bucket secret key. |
| `LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE` | `false` | Railway Buckets use virtual-hosted-style URLs. |
| `LANGFUSE_S3_MEDIA_UPLOAD_BUCKET` | `${{Bucket.BUCKET}}` | Railway Bucket name for media uploads. |
| `LANGFUSE_S3_MEDIA_UPLOAD_PREFIX` | `media/` | Key prefix for media objects inside the bucket. |
| `LANGFUSE_S3_MEDIA_UPLOAD_REGION` | `${{Bucket.REGION}}` | Bucket region (Railway Buckets use auto). |
| `LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Bucket S3 endpoint (public; also used for presigned media URLs). |
| `LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` | Bucket access key. |
| `LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` | Bucket secret key. |
| `LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE` | `false` | Railway Buckets use virtual-hosted-style URLs. |
| `LANGFUSE_S3_BATCH_EXPORT_ENABLED` | `true` | Enable CSV/JSON batch exports from the UI, written to the bucket. |
| `LANGFUSE_S3_BATCH_EXPORT_BUCKET` | `${{Bucket.BUCKET}}` | Railway Bucket name for batch exports. |
| `LANGFUSE_S3_BATCH_EXPORT_PREFIX` | `exports/` | Key prefix for exports. |
| `LANGFUSE_S3_BATCH_EXPORT_REGION` | `${{Bucket.REGION}}` | Bucket region. |
| `LANGFUSE_S3_BATCH_EXPORT_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Bucket S3 endpoint used to upload exports. |
| `LANGFUSE_S3_BATCH_EXPORT_EXTERNAL_ENDPOINT` | `${{Bucket.ENDPOINT}}` | Endpoint used in presigned download links (public bucket endpoint). |
| `LANGFUSE_S3_BATCH_EXPORT_ACCESS_KEY_ID` | `${{Bucket.ACCESS_KEY_ID}}` | Bucket access key. |
| `LANGFUSE_S3_BATCH_EXPORT_SECRET_ACCESS_KEY` | `${{Bucket.SECRET_ACCESS_KEY}}` | Bucket secret key. |
| `LANGFUSE_S3_BATCH_EXPORT_FORCE_PATH_STYLE` | `false` | Railway Buckets use virtual-hosted-style URLs. |
| `TELEMETRY_ENABLED` | `true` | Anonymous usage telemetry to Langfuse (upstream default). Set false to opt out. |

### ClickHouse

Built from `services/clickhouse/Dockerfile` (stock image + `config.d/zz-railway.xml`).

- Source: repo `baranberkay96/langfuse-railway`, root directory `/services/clickhouse` (Dockerfile build)
- Start command: image default
- Pre-deploy command: none
- Healthcheck: `/ping` (timeout 300 s)
- Public domain: no (listens on `8123` privately)
- TCP proxy: none
- Volume: `/var/lib/clickhouse`
- Restart policy: ON_FAILURE (max 10 retries); replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `CLICKHOUSE_DB` | `default` | Database Langfuse uses. |
| `CLICKHOUSE_USER` | `langfuse` | ClickHouse user created by the image entrypoint on first start. |
| `CLICKHOUSE_PASSWORD` | `${{secret(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | ClickHouse password (alphanumeric so it is safe inside Langfuse migration URLs). |
| `PORT` | `8123` | HTTP port; used by the Railway healthcheck (/ping). |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Give ClickHouse time to flush and shut down cleanly on redeploy. |

### Postgres

Railway base Postgres (`_railway-base/postgres.json`, verbatim).

- Source: image `ghcr.io/railwayapp-templates/postgres-ssl:18`
- Start command: image default
- Pre-deploy command: none
- Healthcheck: none (no HTTP listener / not applicable)
- Public domain: no
- TCP proxy: none
- Volume: `/var/lib/postgresql/data`
- Restart policy: ON_FAILURE (max 10 retries); replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `PGDATA` | `/var/lib/postgresql/data/pgdata` | Location where the database will be initialized |
| `PGHOST` | `${{RAILWAY_PRIVATE_DOMAIN}}` | Railway Private Domain Name. |
| `PGPORT` | `5432` | Port to connect to Postgres. |
| `PGUSER` | `${{ POSTGRES_USER }}` | Required variable for Data panel |
| `PGDATABASE` | `${{POSTGRES_DB}}` | Required variable for the data panel. |
| `PGPASSWORD` | `${{POSTGRES_PASSWORD}}` | Required variable for Data panel |
| `POSTGRES_DB` | `railway` | Default database created when image is started. |
| `DATABASE_URL` | `postgresql://${{PGUSER}}:${{POSTGRES_PASSWORD}}@${{RAILWAY_PRIVATE_DOMAIN}}:5432/${{PGDATABASE}}` | URL to connect to Postgres database. |
| `POSTGRES_USER` | `postgres` | User to connect to Postgres DB |
| `SSL_CERT_DAYS` | `820` | SSL certificate expiry in days. |
| `POSTGRES_PASSWORD` | `${{ secret(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ") }}` | Password to connect to DB |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Allow Postgres to cleanly shut down |

### Redis

Railway base Redis (`_railway-base/redis.json`, verbatim). Langfuse needs `maxmemory-policy noeviction`, which is the Redis default when no maxmemory is set.

- Source: image `redis:8.2`
- Start command: `/bin/sh -c "rm -rf $RAILWAY_VOLUME_MOUNT_PATH/lost+found/ && exec docker-entrypoint.sh redis-server --requirepass $REDIS_PASSWORD --save 60 1 --dir $RAILWAY_VOLUME_MOUNT_PATH"`
- Pre-deploy command: none
- Healthcheck: none (no HTTP listener / not applicable)
- Public domain: no
- TCP proxy: none
- Volume: `/data`
- Restart policy: ON_FAILURE (max 10 retries); replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `REDISHOST` | `${{RAILWAY_PRIVATE_DOMAIN}}` | Private network hostname of the Redis service, only resolvable from services in the same environment |
| `REDISPORT` | `6379` | Port that Redis listens on |
| `REDISUSER` | `default` | Username for authenticating with Redis |
| `REDIS_URL` | `redis://${{ REDISUSER }}:${{ REDIS_PASSWORD }}@${{ REDISHOST }}:${{ REDISPORT }}` | Connection string for connecting to Redis using the private network |
| `REDISPASSWORD` | `${{REDIS_PASSWORD}}` | Alias of REDIS_PASSWORD for clients that expect the unseparated name |
| `REDIS_PASSWORD` | `${{ secret(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ") }}` | Randomly generated password for authenticating with Redis |

### Bucket (Railway Bucket)

- S3-compatible Railway Bucket. Exposes `BUCKET`, `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `REGION`, `ENDPOINT` for references such as `${{Bucket.ENDPOINT}}`.
- Private only, virtual-hosted-style addressing, reachable over the public endpoint (`https://t3.storageapi.dev`).

## Improvements over market templates

1. **Langfuse v4 (4.56.0) instead of floating `:3` tags.** Images pinned to an exact release; ClickHouse moved to the 26.8 LTS line that v4 requires (market used `clickhouse-server:24`, which v4 rejects).
2. **No MinIO.** The market template used `minio/minio` with hardcoded root credentials (`minio` / `miniosecret` in the app config). Replaced by a Railway Bucket for event uploads, media uploads and batch exports, with `FORCE_PATH_STYLE=false` for Railway's virtual-hosted addressing.
3. **Real secrets everywhere.** Market shipped `ENCRYPTION_KEY=000...000` and `CLICKHOUSE_PASSWORD=clickhouse`. Now `ENCRYPTION_KEY` is a generated 64-char hex key, ClickHouse/Postgres/Redis passwords are generated, and web/worker share values by reference.
4. **Headless initialization.** `LANGFUSE_INIT_*` creates the organization, project, a public/secret API key pair and the owner account on first boot, so SDKs can send traces right after deploy. Only the admin email is a required input.
5. **Sign-up closed by default** (`AUTH_DISABLE_SIGNUP=true`) so a public URL does not let strangers create accounts.
6. **Batch exports enabled** (`LANGFUSE_S3_BATCH_EXPORT_*`) — missing in the market template, so UI exports did not work.
7. **Low-memory ClickHouse config** (`services/clickhouse/config.d/zz-railway.xml`): smaller mark/uncompressed caches, high-churn system log tables disabled, 7-day TTL on `query_log`/`part_log`, logs to stdout. Prevents the volume from silently filling with system logs.
8. **Healthchecks** on every HTTP service: web readiness `/api/public/ready`, worker `/api/health`, ClickHouse `/ping`. Market had none on web/worker.
9. **IPv6-safe networking:** web and worker bind `::`; Redis URL uses `family=0` so ioredis resolves IPv4 or IPv6 private DNS (market forced `family=6`).
10. **Railway base Postgres 18 and Redis 8.2** instead of Postgres 16 with a public TCP proxy and the discontinued `bitnami/redis` image. No database is exposed publicly.

## Resource estimate

| Service | Idle RAM | Typical RAM | Typical vCPU | Volume |
|---|---|---|---|---|
| langfuse-web | 0.5 GB | 1.0 GB | 0.3 | – |
| langfuse-worker | 0.4 GB | 1.0 GB | 0.3 | – |
| ClickHouse | 0.7 GB | 2.0 GB | 0.5 | 5–20 GB |
| Postgres | 0.1 GB | 0.25 GB | 0.05 | 1 GB |
| Redis | 0.02 GB | 0.1 GB | 0.02 | < 0.5 GB |
| Bucket | – | – | – | 1–20 GB object storage |
| **Total** | **~1.7 GB** | **~4.4 GB** | **~1.2** | **~7–22 GB** |

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month, Bucket storage $0.015/GB-month.

- **Idle (no traffic):** 1.7 GB × $10 + ~0.15 vCPU × $20 + ~6 GB volume × $0.15 ≈ **$21/month**.
- **Typical (team using it daily, a few hundred thousand observations/month):** 4.4 GB × $10 + 1.2 vCPU × $20 + 20 GB × $0.15 + 10 GB bucket × $0.015 ≈ **$71/month**.
- Heavy ingestion scales mainly ClickHouse RAM/CPU and the worker count.
- Note: uploads from web/worker to the bucket travel over the public network and count as service egress.

**Minimum plan: Hobby.** Trial's 1 GB per service is too small for ClickHouse and for langfuse-web during migrations. Pro is recommended for production (higher per-service limits, replicas for web/worker).

## Verification checklist

1. All five services and the bucket deploy green; `langfuse-web` healthcheck `/api/public/ready` returns 200 (first boot runs migrations; allow up to 10 minutes).
2. `https://<web-domain>/api/public/health` returns `{"status":"OK"}`; worker logs show `Listening` on port 3030 and `/api/health` passes.
3. Sign in with `LANGFUSE_INIT_USER_EMAIL` and the generated `LANGFUSE_INIT_USER_PASSWORD`; the organization "My Organization" and project "My Project" exist. Change the password.
4. Copy `LANGFUSE_INIT_PROJECT_PUBLIC_KEY` / `..._SECRET_KEY` into an SDK (`LANGFUSE_HOST=https://<web-domain>`), send one trace, confirm it appears in the UI within a few seconds (proves web → bucket → Redis → worker → ClickHouse).
5. Check the bucket contains `events/...` objects. Trigger a batch export from the traces table and download it (proves presigned URLs on the Railway Bucket).
6. Redeploy ClickHouse, Postgres and Redis; traces and login survive.
7. Scale `langfuse-worker` to 2 replicas; ingestion keeps working.
8. In ClickHouse, `SELECT timezone()` returns `UTC` and `system.trace_log` does not exist.

## Open questions

- **Railway Bucket CORS:** media is uploaded by SDKs through presigned URLs (server-side, no CORS). If you upload media from a browser, the bucket may need a CORS rule; Railway's docs do not cover CORS configuration.
- **ClickHouse 26.8 vs upstream compose (25.12):** satisfies Langfuse's documented minimum and recommendation, but it is newer than the version in Langfuse's own compose file. If a migration fails, pin `25.12` in `services/clickhouse/Dockerfile`.
- **Postgres 18:** Langfuse documents Postgres 15+ (16 recommended). Postgres 18 is the Railway base image; not verified against Langfuse's CI matrix.
- **Init keys persistence:** `LANGFUSE_INIT_*` is idempotent (upsert). Changing the generated keys later creates an additional key pair; it does not rotate the old one.
- Not deploy-tested in this package (local files only).
