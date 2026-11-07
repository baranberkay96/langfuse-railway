#!/bin/sh
# Sizes the Node heap for small Railway plans, then runs upstream's entrypoint.
#
# Node derives its default heap limit from the container's memory, and up to
# 2 GiB that default is smaller than what Langfuse web needs. Up to 2 GiB the
# heap is set to 75% of the container memory; above that Node's default stays.
# Below 1.5 GiB Langfuse web cannot run at all: about 26 s after start its live
# heap is ~720 MiB (measured on Railway), so the Trial (1 GB) and Free (0.5 GB)
# plans fail with "JavaScript heap out of memory". The script says so in the log.
# LANGFUSE_NODE_HEAP_MB overrides the value; a max-old-space-size already in
# NODE_OPTIONS is left alone.
set -eu

readonly SMALL_LIMIT_BYTES=2147483648
readonly MIN_LIMIT_BYTES=1610612736

memory_limit() {
  if [ -r /sys/fs/cgroup/memory.max ]; then
    cat /sys/fs/cgroup/memory.max
  elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    cat /sys/fs/cgroup/memory/memory.limit_in_bytes
  else
    echo max
  fi
}

heap_mb="${LANGFUSE_NODE_HEAP_MB:-}"
limit="$(memory_limit)"
if [ -z "$heap_mb" ]; then
  case "$limit" in
    '' | max | *[!0-9]*) ;;
    *)
      if [ "$limit" -le "$SMALL_LIMIT_BYTES" ]; then
        heap_mb=$((limit / 1048576 * 3 / 4))
      fi
      if [ "$limit" -lt "$MIN_LIMIT_BYTES" ]; then
        echo "[railway] ERROR: this service may use only $((limit / 1048576)) MiB of memory. Langfuse web needs at least 1.5 GiB and stops with 'JavaScript heap out of memory' below that. Railway's Trial and Free plans cap services at 1 GB and 0.5 GB: use the Hobby plan or raise the service's memory limit." >&2
      fi
      ;;
  esac
fi

case "$heap_mb" in
  '') ;;
  *[!0-9]*) echo "[railway] LANGFUSE_NODE_HEAP_MB must be a number of MiB; ignored" >&2 ;;
  *)
    case " ${NODE_OPTIONS:-} " in
      *max-old-space-size*) ;;
      *)
        NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--max-old-space-size=$heap_mb"
        export NODE_OPTIONS
        echo "[railway] Node heap limit ${heap_mb} MiB (container memory limit: ${limit})" >&2
        ;;
    esac
    ;;
esac

exec "$@"
