# Runbook de incidentes e troubleshooting PostgreSQL

Este runbook cobre os incidentes mais comuns do ambiente PostgreSQL do projeto,
tanto local quanto Azure Database for PostgreSQL Flexible Server.

Cada secao segue a estrutura: **sintoma → diagnostico → resolucao → prevencao**.

---

## INC-01: Nao consigo conectar ao banco

### Sintoma

```text
psql: error: connection to server at "..." failed: Connection refused
psql: error: FATAL: password authentication failed for user "shp_app_user"
psql: error: FATAL: no pg_hba.conf entry for host
```

### Diagnostico

**Local:**

```powershell
# verificar se o servico esta rodando
Get-Service -Name postgresql*

# verificar porta
netstat -an | Select-String "5432"

# testar conectividade
pg_isready -h localhost -p 5432
```

**Azure Flexible Server:**

```powershell
# teste de porta a partir da maquina de administracao
Test-NetConnection -ComputerName shp-mgmt-pg-prod.postgres.database.azure.com -Port 5432

# confirmar firewall: portal Azure > Flexible Server > Networking
# o IP da maquina atual deve estar na lista de regras
```

### Resolucao

**Servico parado (local):**

```powershell
Start-Service -Name postgresql-x64-16
```

**Firewall Azure bloqueando:**

1. Portal do Azure > Flexible Server > **Networking**
2. Adicione o IP atual em **Firewall rules**
3. Save e aguarde 30 segundos

**Senha incorreta:**

```powershell
# conectar como superuser e redefinir senha
psql -h localhost -U postgres
```

```sql
ALTER ROLE shp_app_user WITH PASSWORD 'NovaSenhaSegura';
```

**No Azure:** acesse o portal > Flexible Server > **Reset password** para o admin, depois reconecte e execute o ALTER ROLE.

**pg_hba.conf nao aceita conexao remota (local):**

1. Localize `pg_hba.conf` (geralmente em `C:\Program Files\PostgreSQL\16\data`)
2. Adicione linha:
   ```text
   host    shp_mgmt_db     shp_app_user    0.0.0.0/0    scram-sha-256
   ```
3. Reinicie o servico:
   ```powershell
   Restart-Service -Name postgresql-x64-16
   ```

### Prevencao

- Mantenha lista de IPs autorizados no Azure atualizada
- Documente senhas em Azure Key Vault ou cofre de senhas do time
- Monitore `connections_failed` via Azure Monitor

---

## INC-02: Consultas lentas ou timeout

### Sintoma

- Requests da API demoram mais de 10 segundos
- Timeout nos endpoints de exportacao
- `statement timeout` nos logs

### Diagnostico

```sql
-- ver consultas ativas e tempo de execucao
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > INTERVAL '5 seconds'
  AND state != 'idle'
ORDER BY duration DESC;
```

```sql
-- ver consultas sequenciais (sem uso de indice)
SELECT schemaname, tablename, seq_scan, seq_tup_read, idx_scan
FROM pg_stat_user_tables
WHERE schemaname = 'shp'
ORDER BY seq_scan DESC;
```

```sql
-- analisar plano de uma consulta especifica
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM shp.permissions
WHERE principal_email = 'user@example.com'
ORDER BY exported_at DESC;
```

**No Azure:** Portal > Flexible Server > **Query performance insight** (se o modulo `pg_qs` estiver ativo).

### Resolucao

**Criar indice faltante:**

```sql
-- exemplo: filtro frequente por email nao coberto
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_permissions_email_exported
  ON shp.permissions (principal_email, exported_at DESC);
```

Use `CONCURRENTLY` em producao para nao bloquear escrita.

**Atualizar estatisticas:**

```sql
ANALYZE shp.permissions;
ANALYZE shp.resources;
ANALYZE shp.export_runs;
```

**Cancelar consulta especifica sem derrubar conexao:**

```sql
SELECT pg_cancel_backend(<pid>);
```

**Encerrar conexao problemática:**

```sql
SELECT pg_terminate_backend(<pid>);
```

### Prevencao

- Execute `VACUUM ANALYZE` semanalmente nas tabelas principais
- Monitore `pg_stat_user_tables.seq_scan` crescendo
- Configure alerta de `cpu_percent > 80` no Azure Monitor

---

## INC-03: Armazenamento quase cheio

### Sintoma

- Alerta `storage_percent > 75` no Azure Monitor
- Erros de escrita nos logs: `ERROR: could not extend file`
- `pg_dump` falha por espaco insuficiente

### Diagnostico

```sql
-- tamanho total do banco
SELECT pg_size_pretty(pg_database_size('shp_mgmt_db'));

-- maiores tabelas
SELECT
  schemaname,
  relname,
  pg_size_pretty(pg_total_relation_size(relid)) AS total,
  pg_size_pretty(pg_relation_size(relid)) AS data_only,
  pg_size_pretty(pg_indexes_size(relid)) AS indexes
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'shp'
ORDER BY pg_total_relation_size(relid) DESC;

-- tuplas mortas acumuladas (bloat)
SELECT schemaname, relname, n_dead_tup, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'shp'
ORDER BY n_dead_tup DESC;
```

### Resolucao

**Limpar dados expirados (operacao segura):**

```sql
-- confirmar o que sera apagado antes
SELECT COUNT(*), MIN(started_at), MAX(started_at)
FROM shp.export_runs
WHERE started_at < NOW() - INTERVAL '180 days';

-- apagar se confirmado
DELETE FROM shp.export_runs
WHERE started_at < NOW() - INTERVAL '180 days';
```

A FK `ON DELETE CASCADE` remove `resources` e `permissions` associados automaticamente.

**Liberar espaco fisico apos delete:**

```sql
VACUUM FULL shp.export_runs;
VACUUM FULL shp.resources;
VACUUM FULL shp.permissions;
```

Atencao: `VACUUM FULL` bloqueia escrita na tabela durante a execucao. Use fora do horario de pico.

**Aumentar storage no Azure Flexible Server:**

Portal do Azure > Flexible Server > **Compute + Storage > Storage**

- Aumente o valor (ex: de 64 GB para 128 GB)
- O Azure aplica sem downtime
- Se **Storage Auto-grow** estiver ativo, o Azure expande automaticamente ao atingir 85%

Verifique se auto-grow esta ativo:

1. Portal > Flexible Server > Compute + Storage
2. Confirme que **Enable storage auto-grow** esta marcado

### Prevencao

- Ative **Storage Auto-grow** no provisionamento
- Configure alerta: `storage_percent > 75`
- Revise politica de retencao a cada 3 meses

---

## INC-04: Pool de conexoes esgotado

### Sintoma

```text
FATAL: sorry, too many clients already
error: remaining connection slots are reserved for non-replication superuser connections
```

### Diagnostico

```sql
-- ver limite e uso atual
SELECT max_conn, used_conn, (max_conn - used_conn) AS disponivel
FROM
  (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') mc,
  (SELECT COUNT(*) AS used_conn FROM pg_stat_activity) ua;

-- ver conexoes por estado e usuario
SELECT usename, state, COUNT(*)
FROM pg_stat_activity
GROUP BY usename, state
ORDER BY count DESC;

-- ver conexoes idle acumuladas
SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'idle';
```

**Limite padrao no Azure Flexible Server por SKU:**

| SKU | max_connections |
|---|---|
| Burstable B2s | 50 |
| General Purpose D4ds_v4 | 859 |
| General Purpose D8ds_v4 | 1716 |

### Resolucao

**Encerrar conexoes idle acumuladas:**

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND query_start < NOW() - INTERVAL '30 minutes';
```

**Usar PgBouncer (embutido no Azure Flexible Server):**

O Azure Flexible Server inclui PgBouncer gerenciado sem custo adicional:

1. Portal do Azure > Flexible Server > **PgBouncer**
2. Ative e configure:
   - `pgbouncer.default_pool_size`: recomendado 20-50 por worker da aplicacao
   - `pgbouncer.pool_mode`: `transaction` (recomendado para APIs REST)
3. Atualize a string de conexao da aplicacao para usar a porta do PgBouncer: **6432**

```dotenv
PG_HOST=shp-mgmt-pg-prod.postgres.database.azure.com
PG_PORT=6432
PG_DATABASE=shp_mgmt_db
PG_USER=shp_app_user
PG_PASSWORD=SenhaSeguraAqui
PG_SSL=true
```

### Prevencao

- Use PgBouncer em producao desde o inicio
- Configure `idleTimeoutMillis` e `max` no pool da aplicacao Node.js
- Monitore `active_connections` proximo ao limite

---

## INC-05: Transacao longa bloqueando operacoes

### Sintoma

- Insercoes ou atualizacoes travam sem retornar
- Logs da aplicacao acumulam erros de lock timeout
- `pg_stat_activity` mostra transacao `idle in transaction` ha muito tempo

### Diagnostico

```sql
-- transacoes abertas ha mais de 5 minutos
SELECT pid, usename, state, wait_event_type, wait_event,
       now() - xact_start AS duracao_transacao, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND (now() - xact_start) > INTERVAL '5 minutes'
ORDER BY duracao_transacao DESC;

-- ver bloqueios ativos
SELECT bl.pid AS bloqueado_pid,
       a.usename AS bloqueado_usuario,
       ka.pid AS bloqueador_pid,
       ka.usename AS bloqueador_usuario,
       a.query AS query_bloqueada
FROM pg_catalog.pg_locks bl
JOIN pg_catalog.pg_stat_activity a ON bl.pid = a.pid
JOIN pg_catalog.pg_locks kl ON kl.transactionid = bl.transactionid AND kl.pid != bl.pid
JOIN pg_catalog.pg_stat_activity ka ON kl.pid = ka.pid
WHERE bl.granted = false;
```

### Resolucao

```sql
-- cancelar query sem encerrar conexao
SELECT pg_cancel_backend(<pid_bloqueador>);

-- encerrar conexao bloqueadora (mais agressivo)
SELECT pg_terminate_backend(<pid_bloqueador>);
```

### Prevencao

- Configure `idle_in_transaction_session_timeout = 10min` no servidor
  - No Azure: Portal > Server parameters > `idle_in_transaction_session_timeout`
- Configure `statement_timeout` por role da aplicacao:
  ```sql
  ALTER ROLE shp_app_user SET statement_timeout = '30s';
  ```

---

## INC-06: Falha em migracao de schema

### Sintoma

- Script DDL falhou no meio da execucao
- Tabela ficou em estado inconsistente
- Coluna adicionada mas constraint nao aplicada

### Diagnostico

```sql
-- verificar estrutura atual
\d shp.resources
\d shp.permissions

-- ver constraints existentes
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'shp.resources'::regclass;
```

### Resolucao

**Reverter coluna adicionada com erro:**

```sql
-- somente se a coluna nao tem dados criticos ainda
ALTER TABLE shp.resources DROP COLUMN IF EXISTS <nome_coluna_erro>;
```

**Recriar indice corrompido:**

```sql
REINDEX INDEX CONCURRENTLY ix_resources_run_type;
```

**Padrao seguro para alteracoes em producao:**

Execute sempre dentro de uma transacao explicita para poder reverter:

```sql
BEGIN;

ALTER TABLE shp.resources ADD COLUMN external_ref TEXT NULL;

-- valide aqui antes de COMMIT
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'shp' AND table_name = 'resources'
  AND column_name = 'external_ref';

-- se ok: COMMIT
-- se nao: ROLLBACK
COMMIT;
```

### Prevencao

- Sempre use transacoes explicitas para DDL em producao
- Teste o script completo em ambiente local antes
- Guarde o script reverso (DROP COLUMN, DROP INDEX) junto com o script principal

---

## INC-07: Verificar e restaurar backup

### Verificar backup logico local

```powershell
# listar conteudo do backup sem restaurar
pg_restore --list .\backup\shp_mgmt_db.backup | Select-String "TABLE DATA"
```

Saida esperada mostra as tabelas com contagem de registros no cabecalho.

### Restaurar backup logico em ambiente de teste

```powershell
# criar banco de restauracao temporario
psql -h localhost -U postgres -c "CREATE DATABASE shp_mgmt_db_restore;"

# restaurar
pg_restore `
  -h localhost -U postgres `
  -d shp_mgmt_db_restore `
  --no-owner `
  .\backup\shp_mgmt_db.backup

# conectar e validar
psql -h localhost -U postgres -d shp_mgmt_db_restore -c "SELECT COUNT(*) FROM shp.export_runs;"

# apagar banco temporario apos validacao
psql -h localhost -U postgres -c "DROP DATABASE shp_mgmt_db_restore;"
```

### Restaurar via Point-in-Time no Azure

1. Portal do Azure > Flexible Server > **Restore**
2. Selecione data e hora da restauracao desejada
3. Defina nome para o novo servidor (ex: `shp-mgmt-pg-restore-20260327`)
4. O Azure cria o novo servidor em 10-30 minutos
5. Conecte ao servidor restaurado e valide os dados
6. Se ok, atualize a string de conexao da aplicacao
7. Apague o servidor restaurado quando nao for mais necessario

Custo: o servidor restaurado cobra normalmente enquanto existir.

---

## INC-08: Log analysis

### Localizar logs locais (Windows)

Logs do PostgreSQL local ficam em:

```text
C:\Program Files\PostgreSQL\16\data\log\
```

Arquivo mais recente:

```powershell
Get-ChildItem "C:\Program Files\PostgreSQL\16\data\log\" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
```

Filtrar erros:

```powershell
Select-String -Path "C:\Program Files\PostgreSQL\16\data\log\postgresql-*.log" `
  -Pattern "ERROR|FATAL|PANIC"
```

### Localizar logs no Azure Flexible Server

Portal do Azure > Flexible Server > **Logs** (Azure Monitor - Log Analytics)

Query KQL para erros recentes:

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DBFORPOSTGRESQL"
| where Category == "PostgreSQLLogs"
| where Message has "ERROR" or Message has "FATAL"
| project TimeGenerated, Message
| order by TimeGenerated desc
| take 50
```

Habilitar logs de consultas lentas:

Portal > Flexible Server > **Server parameters**

| Parametro | Valor recomendado |
|---|---|
| `log_min_duration_statement` | `5000` (5 segundos em ms) |
| `log_statement` | `ddl` |
| `log_connections` | `on` |
| `pg_qs.query_capture_mode` | `all` (habilita Query Performance Insight) |

---

## Checklist de saude periodica

Execute quinzenalmente:

```sql
-- 1. tabelas com mais tuplas mortas (precisam de VACUUM)
SELECT schemaname, relname, n_dead_tup
FROM pg_stat_user_tables
WHERE schemaname = 'shp'
ORDER BY n_dead_tup DESC;

-- 2. indices nunca usados (candidatos a remocao)
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE schemaname = 'shp'
  AND idx_scan = 0
ORDER BY indexname;

-- 3. tamanho das tabelas
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS total
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'shp'
ORDER BY pg_total_relation_size(relid) DESC;

-- 4. ultimo vacuum e analyze
SELECT relname, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'shp'
ORDER BY last_autovacuum ASC NULLS FIRST;
```

---

## Contatos e escalada

| Nivel | Acao |
|---|---|
| L1 | Validar conectividade, reiniciar servico local, verificar firewall Azure |
| L2 | Analisar locks, tunar indices, executar VACUUM |
| L3 | Restaurar backup, migracao de dados, aumentar SKU |
| Incidente critico | Acionar responsavel do ambiente Azure, considerar PITR |
