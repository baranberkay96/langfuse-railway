# ClickHouse for Langfuse on Railway.
# Stock upstream image (LTS line, >= 25.12 as required by Langfuse v4) plus a small
# config override that lowers cache sizes and disables noisy system log tables so the
# server stays comfortable on a few GB of RAM and a small volume.
FROM clickhouse/clickhouse-server:26.8.23.6

COPY config.d/zz-railway.xml /etc/clickhouse-server/config.d/zz-railway.xml

# Data lives on the Railway volume mounted at /var/lib/clickhouse.
# The image entrypoint creates CLICKHOUSE_USER / CLICKHOUSE_PASSWORD on first start
# and listens on :: and 0.0.0.0 (HTTP 8123, native 9000).
