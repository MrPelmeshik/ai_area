#!/bin/sh

PORT=${PORT:-3000}
SUBDOMAIN=${SUBDOMAIN:-}
HOST=${HOST:-https://localtunnel.me}

if [ -n "$SUBDOMAIN" ]; then
  echo "Starting localtunnel on port $PORT with subdomain: $SUBDOMAIN..."
  exec lt --port "$PORT" --host "$HOST" --subdomain "$SUBDOMAIN" --print-requests
else
  echo "Starting localtunnel on port $PORT..."
  exec lt --port "$PORT" --host "$HOST" --print-requests
fi

