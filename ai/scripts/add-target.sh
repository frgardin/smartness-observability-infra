#!/bin/bash

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ip-address> <hostname> [environment]"
    exit 1
fi

IP=$1
HOSTNAME=$2
ENVIRONMENT=${3:-production}

TARGETS_FILE="$(dirname "$0")/../master/prometheus/file_sd/targets.json"

echo "Adding target $HOSTNAME ($IP) to monitoring..."

if [ ! -f "$TARGETS_FILE" ]; then
    echo "[]" > "$TARGETS_FILE"
fi

if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    apt-get update && apt-get install -y jq
fi

jq ". += [{\"targets\": [\"$IP:9100\"], \"labels\": {\"job\": \"node-exporter\", \"hostname\": \"$HOSTNAME\", \"environment\": \"$ENVIRONMENT\"}}]" "$TARGETS_FILE" > tmp.json && mv tmp.json "$TARGETS_FILE"

jq ". += [{\"targets\": [\"$IP:8080\"], \"labels\": {\"job\": \"cadvisor\", \"hostname\": \"$HOSTNAME\", \"environment\": \"$ENVIRONMENT\"}}]" "$TARGETS_FILE" > tmp.json && mv tmp.json "$TARGETS_FILE"

echo "✓ Added $HOSTNAME to monitoring"
echo "Prometheus will discover targets within 30 seconds"
