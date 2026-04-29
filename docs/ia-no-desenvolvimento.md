# Como a IA auxiliou no desenvolvimento desse projeto

Esse documento registra o papel do Claude (IA da Anthropic) no processo de construção da infraestrutura de observabilidade. O objetivo é ser honesto sobre o que foi feito pela IA, o que foi decidido pelo desenvolvedor, e o que essa colaboração produziu.

---

## Modelo de colaboração

O desenvolvimento seguiu um padrão de **ensino iterativo**: o desenvolvedor declarava o que queria aprender ou construir, e a IA explicava os conceitos, gerava o código, diagnosticava problemas e ajustava conforme o feedback. Nenhuma etapa foi "automatizada sem entendimento" — cada bloco de código foi acompanhado de explicação do porquê.

---

## O que a IA fez em cada etapa

### 1. Explicação dos fundamentos do Prometheus

Antes de escrever qualquer código, o desenvolvedor pediu uma explicação aprofundada dos conceitos da documentação oficial. A IA traduziu e detalhou em português:

- **Modelo de dados multidimensional** — o que são time series, labels e por que isso é mais poderoso que métricas com nomes estáticos
- **PromQL** — como a linguagem opera sobre dimensões, com exemplos do simples (instant vector) ao complexo (agregações e ratios)
- **Pull model** — por que buscar métricas é melhor que recebê-las, e quando o Pushgateway faz sentido
- **Service discovery** — diferença entre static config e file_sd, e quando cada um é adequado

Isso estabeleceu o vocabulário e o modelo mental antes de qualquer implementação.

---

### 2. Configuração inicial do Docker Compose e Prometheus

A IA ajudou a construir o `compose.yml` e o `prometheus.yml` mínimos: um container Prometheus scrapeando a si mesmo. Cada campo foi explicado — por que `scrape_interval: 15s`, o que `static_configs` significa, o que acontece em `/metrics`.

**Decisão do desenvolvedor**: começar minimal (só Prometheus) antes de adicionar mais serviços.

---

### 3. Adição do Node Exporter e diagnóstico de rede

Aqui surgiu o primeiro problema real: o Node Exporter foi configurado com `network_mode: host` (seguindo a recomendação oficial para capturar interfaces de rede reais), mas o Prometheus não conseguia alcançá-lo.

**Processo de diagnóstico conduzido pela IA:**
1. Verificou que o node-exporter respondia no host (`curl localhost:9100/metrics` funcionou)
2. Testou de dentro do container Prometheus (`wget host.docker.internal:9100`) — falhou com timeout
3. Identificou a causa: no Linux, o Docker bridge não roteia automaticamente para o host, diferente do Mac/Windows
4. Propôs a solução correta: remover `network_mode: host` do node-exporter, expor a porta normalmente, e referenciar pelo nome de serviço Docker (`node_exporter:9100`)

**O que foi aprendido**: a diferença de comportamento do Docker entre Linux e Mac/Windows, e como o DNS interno do Docker resolve nomes de serviço.

---

### 4. Adição do Grafana com provisionamento como código

A IA explicou por que usar provisionamento (arquivos YAML/JSON no repositório) em vez de configurar manualmente pela UI: repeatability, versionamento, e inicialização automática.

Foram criados:
- Datasource apontando para `http://prometheus:9090` (via nome de serviço Docker)
- Dashboard inicial com variável `$instance` e três painéis (CPU %, RAM %, Disco %)

**Problema de UID**: na primeira tentativa, a IA usou `"uid": "-- Default --"` no JSON do dashboard, que não funciona em dashboards provisionados. Após ver o erro nos logs (`Datasource provisioning error: data source not found`), a solução foi definir um UID explícito (`"uid": "prometheus"`) no arquivo de datasource e referenciar esse mesmo UID no dashboard.

**O que foi aprendido**: como o Grafana provisiona datasources e dashboards via arquivos, e o problema de conflito de estado com volumes Docker persistentes.

---

### 5. Queries de PromQL para métricas de sistema

A IA ensinou as queries para CPU, RAM, disco e rede, explicando a lógica por trás de cada uma:

**CPU** — por que calcular `100 - idle` em vez de somar user+system+iowait (evita lacunas de modos não monitorados). Por que usar `avg by (instance)` para agregar múltiplos cores.

**RAM** — por que `MemAvailable` é mais confiável que `MemFree` no Linux (o kernel usa RAM livre como cache de disco, que aparece como "usada" mas está disponível).

**Disco** — por que filtrar `fstype!~"tmpfs|overlay|devtmpfs"` (evitar partições virtuais que poluem os resultados).

---

### 6. Diagnóstico de query incorreta de CPU

O desenvolvedor rodou `stress-ng` para testar 100% de CPU e o gráfico mostrou apenas ~20%. A IA diagnosticou o problema:

**Causa**: `rate(node_cpu_seconds_total[5m])` calcula a taxa média dos últimos 5 minutos. Se o stress-ng rodou por 1 minuto dentro de uma janela de 5 minutos, o resultado é ~20% (1/5 do tempo). O Load Average reagia instantaneamente porque é calculado pelo kernel, mas o `rate()` suaviza tudo.

**Solução**: trocar `[5m]` por `[1m]` nas queries de CPU. A IA explicou o tradeoff: `[1m]` é mais reativo mas mostra mais ruído; `[5m]` é mais suave mas esconde picos curtos. Para CPU de produção, `[1m]` é o padrão da indústria.

---

### 7. Melhoria do dashboard com valores absolutos

A IA enriqueceu o dashboard com:
- Stat panels no topo (CPU %, RAM Usada/Total, Disk Usado/Total, Uptime)
- CPU por modo (user, system, iowait separados)
- Load Average separado da % de CPU
- RAM em bytes absolutos (total, used, available, cached)
- Swap
- Disk I/O (leitura/escrita em bytes/s)
- Throughput de rede por interface

Cada painel foi justificado: por que Load Average e CPU % são informações complementares, o que iowait alto indica (gargalo de disco), por que cached RAM não deve ser contada como "usada".

---

### 8. Automação Ansible para 40+ máquinas

Para escalar além de uma máquina, a IA recomendou Ansible e explicou por que é a escolha certa para esse caso:
- Agentless (só SSH, sem instalar nada nas slaves)
- Idempotente (pode rodar N vezes sem problema)
- Integra naturalmente com file_sd (o inventário vira a fonte de verdade dos targets)

A IA projetou a estrutura completa:
- **Role `node_exporter`**: instala binário, cria usuário de sistema sem shell, configura systemd, abre firewall
- **Template Jinja2** que transforma o inventário Ansible em `file_sd/targets.json` — eliminando a necessidade de manutenção manual de dois arquivos
- **`relabel_configs`** no Prometheus para mostrar hostnames amigáveis no Grafana em vez de IPs

---

### 9. Dashboard Fleet Overview

Para visibilidade de toda a frota simultaneamente, a IA criou um dashboard de tabela com uma linha por máquina, mostrando CPU %, RAM, Disco e Status colorido. Isso foi implementado com:
- Múltiplas queries em formato `table` + `instant`
- Transformação `merge` para combinar as queries em uma tabela única
- Transformação `organize` para renomear e ordenar colunas
- `overrides` para aplicar coloração por threshold em CPU % e Disk %

---

## O que foi decidido pelo desenvolvedor (não pela IA)

- Escopo do projeto: monitorar 40+ máquinas com as métricas mais relevantes
- Tecnologia principal: Prometheus + Grafana (escolha feita antes da conversa)
- Abordagem de aprendizado: entender cada peça antes de avançar
- Instalação nas slaves: binário + systemd (em vez de Docker Compose)
- Acesso SSH: por chave (em vez de senha)
- Quando aceitar ou rejeitar sugestões da IA

---

## O que a IA não fez

- **Não tomou decisões de arquitetura sozinha**: cada escolha significativa (topologia, tecnologia de automação, formato de instalação) foi apresentada como opção com tradeoffs explicados
- **Não pulou etapas de aprendizado**: quando o desenvolvedor queria entender antes de avançar, a IA ensinou em vez de só entregar código pronto
- **Não ignorou erros**: todos os problemas reais (rede Docker, UID do datasource, query de CPU) foram diagnosticados com a causa raiz explicada, não apenas com a correção aplicada

---

## Padrão que emergiu

```
Desenvolvedor declara intenção
        ↓
IA explica o conceito subjacente
        ↓
IA gera o código/configuração com justificativa
        ↓
Desenvolvedor testa na prática
        ↓
Problema real aparece (ou não)
        ↓
IA diagnostica com causa raiz
        ↓
Correção aplicada + explicação do porquê
        ↓
Próxima iteração
```

Esse ciclo foi repetido para cada componente adicionado ao sistema. O resultado é que o desenvolvedor não apenas tem a infraestrutura funcionando — ele entende por que cada peça está configurada do jeito que está.
