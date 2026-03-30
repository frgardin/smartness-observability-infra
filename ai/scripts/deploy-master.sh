#!/bin/bash

set -e

echo "=== Master Node Deployment ==="

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname "$0")/../master"

if [ ! -f nginx/certs/server.crt ]; then
    echo "Generating TLS certificates..."
    ../scripts/generate-certs.sh
fi

echo "Starting services..."
docker-compose up -d

echo "Waiting for services..."
sleep 30

IP=$(hostname -I | awk '{print $1}')

echo "=== Deployment Complete ==="
echo "Grafana: https://$IP:3000 (admin/admin)"
echo "Prometheus: https://$IP:9090"
