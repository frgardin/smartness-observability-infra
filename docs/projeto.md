# Smartness Observability Infrastructure

Documentação do projeto de monitoramento distribuído construído com Prometheus, Grafana e Ansible.

---

## O que é esse projeto

Um sistema de observabilidade centralizado capaz de monitorar 40+ máquinas simultaneamente. Uma máquina central (master) coleta e visualiza métricas de todas as outras (slaves). O objetivo é ter visibilidade em tempo real de CPU, memória, disco e rede de toda a frota de máquinas.

---

## Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                    MASTER NODE                       │
│                                                      │
│  ┌─────────────┐   ┌─────────────┐                  │
│  │ Prometheus  │   │   Grafana   │                  │
│  │  :9090      │◄──│   :3000     │                  │
│  │             │   │             │                  │
│  │ file_sd/    │   │ dashboards/ │                  │
│  │ targets.json│   │ provisioning│                  │
│  └──────┬──────┘   └─────────────┘                  │
│         │ pull /metrics a cada 15s                   │
└─────────┼───────────────────────────────────────────┘
          │ HTTP :9100
          ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────┐
│   SLAVE 01       │  │   SLAVE 02       │  │  ...     │
│  node_exporter   │  │  node_exporter   │  │  40+     │
│  :9100 (systemd) │  │  :9100 (systemd) │  │ máquinas │
└──────────────────┘  └──────────────────┘  └──────────┘
          ▲
          │ instala via SSH
┌─────────────────┐
│     Ansible     │
│  playbooks/     │
│  deploy.yml     │
└─────────────────┘
```

**Modelo pull**: o Prometheus vai até cada máquina buscar as métricas. As slaves não precisam saber onde fica o master — elas só expõem o endpoint `/metrics` na porta 9100.

---

## Stack de tecnologias

| Tecnologia | Função |
|---|---|
| **Prometheus** | Banco de séries temporais. Coleta e armazena métricas de todas as máquinas |
| **Grafana** | Visualização. Dashboards interativos com gráficos e tabelas |
| **Node Exporter** | Agente nas slaves. Expõe métricas de SO (CPU, RAM, disco, rede) via HTTP |
| **Ansible** | Automação. Instala o node-exporter em todas as máquinas via SSH |
| **Docker Compose** | Orquestração do master. Sobe Prometheus + Grafana com um único comando |

---

## Estrutura de arquivos

```
smartness-observability-infra/
│
├── compose.yml                          # Orquestração do master (Prometheus + Grafana)
├── prometheus.yml                       # Configuração do Prometheus (scrape, file_sd)
│
├── file_sd/
│   └── targets.json                     # Lista dinâmica de slaves para o Prometheus scraping
│
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml           # Conecta Grafana ao Prometheus automaticamente
│       └── dashboards/
│           ├── dashboard.yml            # Diz ao Grafana onde encontrar os JSONs
│           ├── node-metrics.json        # Dashboard por máquina (CPU, RAM, disco, rede)
│           └── fleet-overview.json      # Dashboard de frota (todas as máquinas de uma vez)
│
└── ansible/
    ├── inventory/
    │   └── hosts.yml                    # Lista das 40+ máquinas slaves
    ├── group_vars/
    │   └── all.yml                      # Variáveis: versão do node-exporter, porta, usuário
    ├── templates/
    │   └── targets.json.j2              # Template que gera o file_sd/targets.json
    ├── roles/
    │   └── node_exporter/
    │       ├── tasks/main.yml           # Passos de instalação: usuário, binário, systemd
    │       ├── handlers/main.yml        # Restart automático quando o serviço muda
    │       └── templates/
    │           └── node_exporter.service.j2  # Unit file do systemd
    └── playbooks/
        └── deploy.yml                   # Playbook principal: instala + atualiza targets.json
```

---

## Como funciona o descobrimento de targets (file_sd)

O Prometheus não tem os IPs das slaves fixos na configuração. Em vez disso, ele lê um arquivo JSON dinamicamente:

```json
// file_sd/targets.json
[
  {"targets": ["10.0.0.10:9100"], "labels": {"hostname": "maquina-01"}},
  {"targets": ["10.0.0.11:9100"], "labels": {"hostname": "maquina-02"}}
]
```

Quando o Ansible faz deploy em uma nova máquina, ele **regenera esse arquivo automaticamente** com todos os hosts do inventário. O Prometheus recarrega o arquivo a cada 30 segundos — sem restart, sem intervenção manual.

O `relabel_configs` no `prometheus.yml` usa o label `hostname` como `instance`, então no Grafana você vê `maquina-01` em vez de `10.0.0.10:9100`.

---

## Rodando o master

### Pré-requisitos
- Docker e Docker Compose instalados
- Portas 9090 (Prometheus) e 3000 (Grafana) livres

### Subir

```bash
docker compose up -d
```

### Verificar saúde

```bash
# Prometheus
curl http://localhost:9090/-/healthy

# Grafana
curl http://localhost:3000/api/health
```

### Acessar

| Serviço | URL | Login |
|---|---|---|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | — |

---

## Adicionando slaves com Ansible

### 1. Editar o inventário

```yaml
# ansible/inventory/hosts.yml
all:
  children:
    slaves:
      hosts:
        maquina-01:
          ansible_host: 10.0.0.10
        maquina-03:            # nova máquina
          ansible_host: 10.0.0.12
```

### 2. Rodar o playbook

```bash
# Testar conectividade primeiro
ansible slaves -i ansible/inventory/hosts.yml -m ping

# Dry-run para ver o que vai acontecer
ansible-playbook ansible/playbooks/deploy.yml \
  -i ansible/inventory/hosts.yml --check

# Deploy real
ansible-playbook ansible/playbooks/deploy.yml \
  -i ansible/inventory/hosts.yml
```

O playbook:
1. Cria usuário de sistema `node_exporter` em cada máquina
2. Baixa e instala o binário do node-exporter
3. Cria e ativa o serviço systemd
4. Abre a porta 9100 no firewall (se ufw estiver ativo)
5. Atualiza `file_sd/targets.json` com todos os hosts

Em até 30 segundos após o playbook terminar, a nova máquina aparece no Prometheus e no Grafana.

---

## Dashboards do Grafana

### Fleet Overview
Visão de toda a frota em uma tabela. Mostra simultaneamente para cada máquina:
- Status (UP / DOWN)
- CPU %
- RAM Usada e RAM Total
- Disco % na partição raiz

Ideal para detectar rapidamente qual máquina está com problema.

### Node Metrics
Dashboard detalhado por máquina. Selecione a máquina no dropdown "Machine" no topo. Seções:

**Overview** — valores instantâneos: CPU %, RAM Usada, RAM Total, Disk Usado, Disk Total, Uptime

**CPU**
- Gráfico de uso % separado por modo (user, system, iowait)
- Load Average 1m / 5m / 15m

**Memory**
- RAM ao longo do tempo (total, used, available, cached)
- Swap usado vs total

**Disk**
- Espaço por partição em bytes (total e usado)
- Taxa de leitura e escrita em bytes/s

**Network**
- Throughput de recebimento e envio em bytes/s por interface

---

## Conceitos fundamentais

### Pull model
O Prometheus **busca** as métricas. Cada slave expõe um endpoint HTTP `/metrics` com todos os valores em texto. O Prometheus conecta nesse endpoint a cada 15 segundos e armazena o que encontrar.

### Time series
Cada métrica é uma série de valores ordenados no tempo. Uma série é identificada pelo nome da métrica + conjunto de labels:
```
node_cpu_seconds_total{instance="maquina-01", mode="user"} → série A
node_cpu_seconds_total{instance="maquina-01", mode="idle"} → série B
node_cpu_seconds_total{instance="maquina-02", mode="user"} → série C
```

### PromQL
Linguagem de consulta do Prometheus. Exemplos usados nesse projeto:

```promql
# CPU em uso (tudo que não é idle), janela de 1 minuto
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)

# RAM usada
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Disk I/O em bytes/s
rate(node_disk_read_bytes_total[5m])
```

### Idempotência (Ansible)
Rodar o playbook dez vezes produz o mesmo resultado que rodar uma vez. Se o node-exporter já estiver instalado e na versão correta, o Ansible não faz nada. Isso permite reexecutar sem medo em caso de falha parcial.

---

## Comandos úteis

```bash
# Ver todos os targets e seu status
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health: .health}'

# Quantas máquinas estão sendo monitoradas
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Recarregar configuração do Prometheus sem restart
curl -X POST http://localhost:9090/-/reload

# Ver logs do Prometheus
docker compose logs prometheus -f

# Ver logs do Grafana
docker compose logs grafana -f

# Reiniciar só o Grafana (para recarregar dashboards)
docker compose restart grafana
```
