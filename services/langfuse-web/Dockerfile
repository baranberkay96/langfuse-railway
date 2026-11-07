# Langfuse web for Railway: the unmodified upstream image plus a start script that
# sizes the Node heap from the container's memory limit (see railway-heap.sh).
FROM langfuse/langfuse:4.56.0@sha256:b1948c7c0931f277975b985e30e73536b1bca5822705ddd9a89ba7c1ed79b3ee

COPY --chmod=0755 railway-heap.sh /usr/local/bin/railway-heap.sh

# Upstream's entrypoint and command, with the heap script in front. Setting
# ENTRYPOINT clears the inherited CMD, so it is repeated here.
ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/railway-heap.sh", "./web/entrypoint.sh"]
CMD ["/bin/sh", "-c", "if [ -n \"$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION\" ]; then node --import dd-trace/initialize.mjs ./web/server.js --keepAliveTimeout 110000; else node ./web/server.js --keepAliveTimeout 110000; fi"]
