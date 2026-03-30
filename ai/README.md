# Smartness Observability Infrastructure

A comprehensive, enterprise-grade observability solution for monitoring 20+ machines using Prometheus and Grafana with full security implementation.

## Architecture

### Overview
This project implements a distributed monitoring system with:
- **Master Node (Gateway)**: Central Prometheus server, Grafana dashboards, Alertmanager
- **Slave Nodes (Agents)**: Node Exporter, cAdvisor, Blackbox Exporter on each monitored machine
- **Security Layer**: TLS encryption, mTLS authentication, secure communications

### Components

#### Master Node
- **Prometheus**: Metrics collection and time-series database
- **Grafana**: Visualization and dashboarding platform
- **Alertmanager**: Alert routing, grouping, and notifications
- **Nginx**: Reverse proxy with TLS termination and authentication

#### Slave Nodes
- **Node Exporter**: System metrics (CPU, memory, disk, network, filesystem)
- **cAdvisor**: Container metrics (Docker container resource usage)
- **Blackbox Exporter**: Network probing (HTTP, TCP, ICMP, DNS)
- **Process Exporter**: Process-level metrics (optional)

## Features

✅ **Scalability**: Supports 20+ machines with file-based service discovery
✅ **Security**: End-to-end TLS encryption with mTLS authentication
✅ **Flexibility**: Docker Compose and native installation options
✅ **Comprehensive Metrics**: System, container, network, and application metrics
✅ **Pre-configured Alerts**: Ready-to-use alerting rules for common issues
✅ **Dashboard Library**: Production-ready Grafana dashboards
✅ **Easy Deployment**: Automated scripts for master and slave deployment

## Quick Start

### Prerequisites
- Docker and Docker Compose installed on all machines
- Network connectivity between master and slave nodes
- Open ports: 9090 (Prometheus), 3000 (Grafana), 9093 (Alertmanager), 9100 (Node Exporter)

### Master Node Setup

1. **Clone the repository on the master machine:**
   ```bash
   git clone <repository-url>
   cd smartness-observability-infra
   ```

2. **Generate TLS certificates:**
   ```bash
   ./scripts/generate-certs.sh
   ```

3. **Deploy master services:**
   ```bash
   ./scripts/deploy-master.sh
   ```

4. **Access the services:**
   - Grafana: https://<master-ip>:3000 (admin/admin)
   - Prometheus: https://<master-ip>:9090
   - Alertmanager: https://<master-ip>:9093

### Slave Node Setup

1. **Copy slave directory to each machine:**
   ```bash
   scp -r slave/ user@<slave-ip>:~/
   ```

2. **Install and start agents:**
   ```bash
   ssh user@<slave-ip>
   cd ~/slave
   ./install.sh
   ```

3. **Add the slave to monitoring:**
   On master node:
   ```bash
   ./scripts/add-target.sh <slave-ip> <slave-hostname>
   ```

## Project Structure

```
smartness-observability-infra/
├── README.md                          # This file
├── PLAN.md                            # Detailed implementation plan
├── master/                            # Master node configurations
│   ├── docker-compose.yml             # Master services orchestration
│   ├── prometheus/                    # Prometheus configuration
│   │   ├── prometheus.yml             # Main Prometheus config
│   │   ├── alerts/                    # Alerting rules
│   │   └── file_sd/                   # Service discovery files
│   ├── grafana/                       # Grafana configuration
│   │   ├── provisioning/              # Auto-provisioning configs
│   │   └── dashboards/                # Dashboard JSON files
│   ├── alertmanager/                  # Alertmanager configuration
│   └── nginx/                         # Reverse proxy config
│       └── certs/                     # TLS certificates
├── slave/                             # Slave node configurations
│   ├── docker-compose.yml             # Slave agents orchestration
│   ├── install.sh                     # Native installation script
│   └── config/                        # Exporter configurations
├── scripts/                           # Automation scripts
│   ├── deploy-master.sh               # Master deployment script
│   ├── deploy-slave.sh                # Slave deployment script
│   ├── add-target.sh                  # Add monitoring target
│   └── generate-certs.sh              # TLS certificate generation
└── docs/                              # Documentation
    ├── SETUP.md                       # Detailed setup guide
    ├── ARCHITECTURE.md                # Architecture documentation
    └── TROUBLESHOOTING.md             # Troubleshooting guide
```

## Configuration

### Adding New Slave Nodes

1. Install slave agents on the new machine
2. Run the add-target script on master:
   ```bash
   ./scripts/add-target.sh <slave-ip> <hostname>
   ```
3. Prometheus will automatically pick up the new target

### Customizing Alerts

Edit alert rules in `master/prometheus/alerts/`:
- `node_alerts.yml`: System-level alerts
- `container_alerts.yml`: Container-level alerts
- `blackbox_alerts.yml`: Network probing alerts

### Customizing Dashboards

1. Create/edit dashboards in Grafana UI
2. Export dashboard JSON
3. Place in `master/grafana/dashboards/`
4. Restart Grafana to provision

## Security

### TLS Certificates
- Self-signed certificates for development
- Let's Encrypt or custom CA for production
- Certificates stored in `master/nginx/certs/`

### Authentication
- Grafana: Built-in user management
- Prometheus: Basic auth via Nginx
- mTLS: Certificate-based authentication for scraping

### Network Security
- All communications encrypted with TLS
- Firewall rules for port access
- Network segmentation recommended

## Monitoring Metrics

### System Metrics (Node Exporter)
**CPU Monitoring:**
- CPU usage percentage
- CPU load average (1m, 5m, 15m)
- Per-core CPU usage
- CPU throttling events

**Memory (RAM) Monitoring:**
- Memory usage percentage
- Available memory
- Memory usage in bytes
- Swap usage
- Memory pressure

**Disk Monitoring:**
- Disk space usage percentage
- Available disk space
- Disk I/O read/write rates
- Disk latency
- Filesystem usage

### Container Metrics (cAdvisor)
- Container CPU and memory usage
- Container network I/O
- Container disk I/O
- Container restarts and status

### Network Probing (Blackbox Exporter)
- HTTP endpoint availability
- TCP port connectivity
- ICMP ping latency
- DNS resolution time

## Alerting

Pre-configured alerts include:
- High CPU usage (>80% for 5 minutes)
- High memory usage (>85% for 5 minutes)
- Disk space low (<10% free)
- Node down (>1 minute)
- Container restart loops
- HTTP endpoint down
- High latency alerts

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and solutions.

### Quick Checks

1. **Check if services are running:**
   ```bash
   docker-compose ps
   ```

2. **View logs:**
   ```bash
   docker-compose logs -f prometheus
   docker-compose logs -f grafana
   ```

3. **Verify Prometheus targets:**
   - Navigate to https://<master-ip>:9090/targets

4. **Test slave agent:**
   ```bash
   curl http://<slave-ip>:9100/metrics
   ```

## Maintenance

### Backup
- Prometheus data: `master/prometheus/data/`
- Grafana data: `master/grafana/data/`
- Configuration files: All YAML and JSON files

### Updates
```bash
# Pull latest images
docker-compose pull

# Restart services
docker-compose down
docker-compose up -d
```

### Scaling
For 50+ machines, consider:
- Prometheus federation
- Thanos for long-term storage
- Multiple Grafana instances

## Support

For issues, questions, or contributions, please refer to the documentation in the `docs/` directory.

## License

[Your License Here]

## Authors

[Your Name/Organization]