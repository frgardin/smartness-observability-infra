# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Smartness Observability Infrastructure — a distributed monitoring system for 20+ machines using Prometheus and Grafana with full security implementation. The project was recently restarted clean (see `restart-project` commit).

## Architecture

The system follows a **master/slave** topology:

- **Master node**: Central observability stack (Prometheus, Grafana, Alertmanager, Nginx reverse proxy) deployed via Docker Compose
- **Slave nodes**: Lightweight agent stack (Node Exporter, cAdvisor, Blackbox Exporter) deployed on each monitored machine

```
Master Node (Gateway)
  └── Nginx (TLS termination, :443/:80)
       ├── Prometheus (:9090) — metrics DB, file-based service discovery
       ├── Grafana (:3000) — dashboards & visualization
       └── Alertmanager (:9093) — alert routing

Slave Nodes (each monitored machine)
  ├── Node Exporter (:9100) — system metrics (CPU, mem, disk, net)
  ├── cAdvisor (:8080) — container metrics
  └── Blackbox Exporter (:9115) — HTTP/TCP/ICMP probes
```

## Key Design Decisions

- **Service discovery**: File-based (`file_sd`) via `master/prometheus/file_sd/targets.json` — targets are added/removed by editing this JSON, no Prometheus restart needed
- **Security**: TLS termination at Nginx; mTLS between master and slaves; certs generated via `scripts/generate-certs.sh`
- **Slave deployment**: Two options — Docker Compose (`slave/docker-compose.yml`) or native install (`slave/install.sh`)
- **Prometheus retention**: 30 days
- **Metric filtering**: `metric_relabel_configs` in `prometheus.yml` filters node metrics to key ones (cpu, memory, filesystem, network) to reduce storage

## Common Commands

### Master node
```bash
# Start all master services
docker compose -f master/docker-compose.yml up -d

# Reload Prometheus config without restart (requires --web.enable-lifecycle flag)
curl -X POST http://localhost:9090/-/reload

# Add a new slave target
./scripts/add-target.sh <slave-ip> <slave-hostname>

# Generate TLS certificates
./scripts/generate-certs.sh

# Deploy master
./scripts/deploy-master.sh
```

### Slave node
```bash
# Start slave agents via Docker Compose
docker compose -f slave/docker-compose.yml up -d

# Install natively on a remote machine (run as root)
./slave/install.sh
```

### Health checks
```bash
# Check Prometheus health
curl http://localhost:9090/-/healthy

# Check Grafana health
curl http://localhost:3000/api/health

# Check Alertmanager health
curl http://localhost:9093/-/healthy
```

## Service Ports

| Service         | Port  | Note                        |
|-----------------|-------|-----------------------------|
| Nginx HTTPS     | 443   | Public-facing entry point   |
| Nginx HTTP      | 80    | Redirects to HTTPS          |
| Prometheus      | 9090  | Internal only               |
| Grafana         | 3000  | Internal only               |
| Alertmanager    | 9093  | Internal only               |
| Node Exporter   | 9100  | On each slave               |
| cAdvisor        | 8080  | On each slave               |
| Blackbox Exp.   | 9115  | On each slave               |

## Directory Layout (intended)

```
smartness-observability-infra/
├── master/
│   ├── docker-compose.yml
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   ├── alerts/          # Alert rules (*.yml)
│   │   └── file_sd/         # Service discovery targets (targets.json)
│   ├── grafana/
│   │   └── provisioning/
│   │       ├── dashboards/
│   │       └── datasources/
│   ├── alertmanager/
│   │   └── alertmanager.yml
│   └── nginx/
│       ├── nginx.conf
│       └── certs/
├── slave/
│   ├── docker-compose.yml
│   ├── install.sh
│   └── config/
│       └── blackbox/
│           └── config.yml
└── scripts/
    ├── add-target.sh
    ├── deploy-master.sh
    └── generate-certs.sh
```
