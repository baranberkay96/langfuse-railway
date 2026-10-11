# Notice

## Upstream software

- **Langfuse** — MIT (Expat) for the core; code under `ee/`, `web/src/ee/`, `worker/src/ee/` is under the Langfuse enterprise license (not enabled by this template). Copyright (c) 2023-2026 ClickHouse, Inc. Images used: `langfuse/langfuse:4.56.0`, `langfuse/langfuse-worker:4.56.0` (published by Langfuse on Docker Hub).
- **ClickHouse** — Apache-2.0. Image `clickhouse/clickhouse-server:26.8.23.6` (published by ClickHouse, Inc.).
- **PostgreSQL** — PostgreSQL License. Image `ghcr.io/railwayapp-templates/postgres-ssl:18` (Railway).
- **Redis** — Redis 8 is available under RSALv2/SSPLv1/AGPLv3. Image `redis:8.2` (Docker official image).

## Verified against

| What | Source | Version / ref | Checked |
|---|---|---|---|
| Service topology and environment variables | https://github.com/langfuse/langfuse/blob/main/docker-compose.yml | main at release v4.56.0 (2026-10-09) | 2026-10-10 |
| Headless init code (`LANGFUSE_INIT_*`, email/password rules) | https://github.com/langfuse/langfuse/blob/main/web/src/initialize.ts and `web/src/env.mjs` | v4.56.0 | 2026-10-10 |
| Worker bind address / port (`HOSTNAME`, `PORT`) | `worker/src/index.ts`, `worker/src/env.ts` | v4.56.0 | 2026-10-10 |
| ClickHouse version requirement (>= 25.12, 26.4 recommended) | https://langfuse.com/self-hosting/deployment/infrastructure/clickhouse | docs | 2026-10-10 |
| v3 → v4 infrastructure changes | https://langfuse.com/self-hosting/upgrade/upgrade-guides/upgrade-v3-to-v4 | docs | 2026-10-10 |
| S3 variables and path-style guidance | https://langfuse.com/self-hosting/deployment/infrastructure/blobstorage | docs | 2026-10-10 |
| Health endpoints | https://langfuse.com/self-hosting/configuration/health-readiness-endpoints | docs | 2026-10-10 |
| Low-memory ClickHouse settings | https://clickhouse.com/docs/operations/tips | docs | 2026-10-10 |
| Railway Bucket behaviour (endpoint, virtual-hosted style, variables) | https://docs.railway.com/storage-buckets | docs | 2026-10-10 |
| Image tags exist | Docker Hub `langfuse/langfuse`, `langfuse/langfuse-worker`, `clickhouse/clickhouse-server` | 4.56.0, 26.8.23.6 | 2026-10-10 |

## Adapted code

None. `services/clickhouse/Dockerfile` and `config.d/zz-railway.xml` were written for this template from the ClickHouse documentation. Postgres and Redis service definitions are copied from this repository's `_railway-base` files.

## Reference only (not copied)

- Railway marketplace templates `exma_H` (Langfuse v3), `gmbqa_` (Langfuse v2) and `agentic-data-stack-lite-langfuse-cloud`: configuration read for ideas; no text or files copied. No license is attached to them.

## Trademarks

Langfuse is a trademark of its respective owner; ClickHouse, PostgreSQL and Redis belong to their respective owners. This is a community template and is not affiliated with or endorsed by Langfuse or ClickHouse, Inc.
