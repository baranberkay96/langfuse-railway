#!/bin/sh
# Sizes the Node heap for small Railway plans, then runs upstream's entrypoint.
#
# Node derives its default heap limit from the container's memory. At the Trial
# plan's 1 GB per service that default is too small for Langfuse web, which then
# stops with "JavaScript heap out of memory" right after start. Up to 2 GiB of
# container memory the heap is set to 75% of it; above that Node's default stays.
# LANGFUSE_NODE_HEAP_MB overrides the value; a max-old-space-size already in
# NODE_OPTIONS is left alone.
set -eu

readonly SMALL_LIMIT_BYTES=2147483648

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
