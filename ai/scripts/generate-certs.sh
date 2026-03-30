#!/bin/bash

set -e

CERTS_DIR="$(dirname "$0")/../master/nginx/certs"

mkdir -p "$CERTS_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERTS_DIR/server.key" \
  -out "$CERTS_DIR/server.crt" \
  -subj "/CN=localhost"

echo "Certificates generated"
