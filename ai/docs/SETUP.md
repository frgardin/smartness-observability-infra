# Setup Guide

## Master Node

1. Clone repository
2. Run: `./scripts/deploy-master.sh`
3. Access: https://<master-ip>:3000 (admin/admin)

## Slave Nodes

1. Copy slave directory: `scp -r slave/ user@<slave-ip>:~/`
2. Install: `ssh user@<slave-ip> 'cd ~/slave && sudo ./install.sh'`
3. Add target: `./scripts/add-target.sh <slave-ip> <hostname>`

## Ports

- 9090: Prometheus
- 3000: Grafana
- 9093: Alertmanager
- 9100: Node Exporter
- 8080: cAdvisor
- 9115: Blackbox Exporter