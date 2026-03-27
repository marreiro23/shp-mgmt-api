# Por que PostgreSQL foi escolhido para este projeto

Este documento explica por que PostgreSQL e a opcao mais equilibrada para o
armazenamento dos dados exportados do tenant neste projeto.

## Natureza dos dados

Os dados exportados pela API nao sao puramente tabulares.

Eles misturam:

- estrutura relacional clara
- hierarquia de recursos
- payloads semiestruturados do Microsoft Graph
- necessidade de reprocessamento posterior
- trilha de auditoria e comparacao historica

Isso exige um banco que funcione bem em dois modos ao mesmo tempo:

1. consultas relacionais classicas
2. armazenamento flexivel de JSON sem perda de fidelidade

## Por que PostgreSQL encaixa melhor

### 1. JSONB forte

PostgreSQL trata JSONB como recurso de primeira linha. Isso importa porque o
payload do Graph muda com o tempo e nem todo campo precisa virar coluna no
primeiro momento.

### 2. Boa combinacao de simplicidade e robustez

O time pode comecar com poucas tabelas e poucos indices, e crescer sem trocar
de tecnologia.

### 3. Bom custo-beneficio operacional

Para um projeto que combina inventario, permissoes, historico e import/export,
PostgreSQL entrega muito sem exigir complexidade de plataforma logo no inicio.

### 4. Escalabilidade gradual

E possivel evoluir por etapas:

- local
- VM pequena
- servico gerenciado
- particionamento por tempo

## Por que nao SQL Express como opcao principal

SQL Express funciona para laboratorio e ambientes pequenos, mas tem limites de
edicao que tendem a aparecer cedo quando o historico de export cresce.

Para este projeto, isso aumenta o risco de retrabalho.

## Por que nao MySQL como opcao principal

MySQL tambem e viavel, mas o desenho deste projeto se beneficia mais das
capacidades de JSONB, indexacao e flexibilidade de consulta do PostgreSQL.

## Como reduzir o risco de baixo conhecimento do time

A decisao por PostgreSQL so faz sentido se vier acompanhada de disciplina de
operacao simples.

Por isso, a estrategia recomendada e:

1. poucos objetos iniciais
2. schema dedicado
3. scripts e comandos padronizados
4. documentacao operacional clara
5. evolucao incremental de indices e particoes

## Azure Database for PostgreSQL Flexible Server como plataforma de producao

Para producao, a opcao recomendada e o servico gerenciado do Azure.
Ele entrega os beneficios do PostgreSQL sem a carga de administrar infraestrutura.

### O que o Flexible Server gerencia automaticamente

- patches de SO e do PostgreSQL
- backups automaticos com ponto de restauracao (PITR) ate 35 dias
- alta disponibilidade com failover automatico (zona redundante)
- SSL/TLS obrigatorio por default
- monitoracao via Azure Monitor

### O que o time ainda precisa gerenciar

- regras de firewall e acesso de rede
- usuarios e permissoes do banco
- schema e migracoes de estrutura
- indices e performance de consultas
- politicas de alerta no Azure Monitor

### Camadas de computacao recomendadas por fase

| Fase | SKU sugerido | Quando usar |
|---|---|---|
| Desenvolvimento local | — | primeiros passos, sem custo Azure |
| Staging/homologacao | Burstable B2s | uso intermitente, baixo volume |
| Producao inicial | General Purpose D4ds_v4 | cargas continuas, exportacoes frequentes |
| Producao em crescimento | D8ds_v4 + read replica | volume alto, consultas analiticas separadas |

### Integracao com outros servicos Azure

- **Azure Key Vault**: armazenar senhas do banco, nunca em variaveis de ambiente em texto plano
- **Azure App Service / Container Apps**: variavel `PG_SSL=true` garante conexao cifrada automaticamente
- **Azure Monitor**: alertas em `storage_percent`, `cpu_percent` e `active_connections`
- **Private Endpoint (VNet)**: recomendado para producao com dados sensiveis

## Estrategia de adocao

Fase 1:

- ambiente local
- 3 tabelas principais
- backup logico simples

Fase 2:

- Azure Flexible Server em staging (Burstable)
- monitoracao de crescimento com Azure Monitor
- indices guiados por consulta real
- alertas de storage e conexoes

Fase 3:

- Azure Flexible Server em producao (General Purpose)
- alta disponibilidade ativada
- retencao formal de 35 dias
- particionamento temporal se necessario
- Private Endpoint ativado

## Decisao pratica

PostgreSQL foi escolhido nao porque seja o banco mais sofisticado, mas porque
ele atende melhor ao equilibrio entre:

- flexibilidade de modelagem
- facilidade de crescimento
- capacidade de auditoria
- reutilizacao de exports/imports
- baixo risco de troca futura de plataforma
