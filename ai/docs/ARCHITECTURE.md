# Architecture

## Master Node
- Prometheus: Metrics collection
- Grafana: Visualization
- Alertmanager: Alerts
- Nginx: TLS proxy

## Slave Nodes
- Node Exporter: System metrics
- cAdvisor: Container metrics
- Blackbox Exporter: Network probes

## Data Flow
1. Exporters expose metrics
2. Prometheus scrapes exporters
3. Grafana queries Prometheus
4. Alertmanager sends notifications