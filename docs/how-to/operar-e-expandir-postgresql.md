# Como operar, manter e expandir o PostgreSQL do projeto

Este guia mostra operacoes comuns de administracao do ambiente PostgreSQL para
equipes com pouca experiencia previa.

## 1. Verificar se o servidor esta disponivel

PowerShell:

```powershell
pg_isready -h localhost -p 5432
```

Resposta esperada:

```text
localhost:5432 - accepting connections
```

## 2. Conectar ao banco

```powershell
psql -h localhost -p 5432 -U shp_app_user -d shp_mgmt_db
```

## 3. Ver tabelas existentes

Dentro do `psql`:

```sql
\dt shp.*
```

## 4. Inserir um novo run manualmente

```sql
INSERT INTO shp.export_runs (tenant_id, source, format, status)
VALUES ('contoso.onmicrosoft.com', 'tenant-sharepoint-inventory', 'json', 'succeeded');
```

## 5. Alterar estrutura com seguranca

Regra pratica:

1. primeiro adicionar coluna nullable
2. depois preencher dados antigos
3. so entao tornar obrigatoria se necessario

Exemplo:

```sql
ALTER TABLE shp.resources
ADD COLUMN external_ref TEXT NULL;

UPDATE shp.resources
SET external_ref = resource_id
WHERE external_ref IS NULL;
```

## 6. Criar novo indice quando a consulta piorar

Exemplo para filtros por `principal_email` e `resource_type`:

```sql
CREATE INDEX IF NOT EXISTS ix_permissions_email_type
  ON shp.permissions (principal_email, resource_type);
```

## 7. Fazer backup logico

PowerShell:

```powershell
pg_dump -h localhost -p 5432 -U postgres -d shp_mgmt_db -F c -f .\backup\shp_mgmt_db.backup
```

## 8. Restaurar backup logico

```powershell
pg_restore -h localhost -p 5432 -U postgres -d shp_mgmt_db .\backup\shp_mgmt_db.backup
```

## 9. Ver tamanho do banco

```sql
SELECT pg_size_pretty(pg_database_size('shp_mgmt_db'));
```

## 10. Ver as maiores tabelas

```sql
SELECT
  schemaname,
  relname,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

## 11. Manutencao basica

Rodar periodicamente:

```sql
VACUUM ANALYZE shp.export_runs;
VACUUM ANALYZE shp.resources;
VACUUM ANALYZE shp.permissions;
```

## 12. Limpar dados antigos

Exemplo: remover exports com mais de 180 dias.

```sql
DELETE FROM shp.export_runs
WHERE started_at < NOW() - INTERVAL '180 days';
```

Observacao:

- isso apaga `resources` e `permissions` relacionados se a FK estiver com `ON DELETE CASCADE`

## 13. Expandir para mais volume

Sinais de que esta na hora de crescer:

- consultas ficando lentas com frequencia
- base acima de dezenas de GB crescendo continuamente
- janelas de backup muito longas
- necessidade de mais historico por tenant

Medidas em ordem pragmatica:

1. revisar indices
2. arquivar dados antigos
3. particionar `resources` e `permissions`
4. mover para instancia gerenciada de producao

## 14. Migrar de local para Azure Database for PostgreSQL Flexible Server

Este e o caminho recomendado para producao. Siga os passos em ordem.

### 14.1 Exportar backup do ambiente local

```powershell
pg_dump `
  -h localhost -p 5432 -U postgres `
  -d shp_mgmt_db `
  --format=custom `
  --no-owner --no-privileges `
  -f .\backup\shp_mgmt_db_migrate.backup
```

Use `--no-owner` e `--no-privileges` para evitar conflitos com usuarios diferentes no Azure.

### 14.2 Provisionar o Flexible Server no Azure

Siga os passos descritos em
`docs/tutorials/postgresql-primeiros-passos.md` (secao Opcao 2).

### 14.3 Criar banco e usuario no Azure

```powershell
$env:PGSSLMODE = 'require'
psql -h shp-mgmt-pg-prod.postgres.database.azure.com -U pgadmin -d postgres
```

Execute no `psql`:

```sql
CREATE ROLE shp_app_user WITH LOGIN PASSWORD 'SenhaSeguraAqui';
CREATE DATABASE shp_mgmt_db WITH OWNER = pgadmin ENCODING = 'UTF8';
GRANT CONNECT ON DATABASE shp_mgmt_db TO shp_app_user;
```

### 14.4 Restaurar backup no Azure

```powershell
$env:PGSSLMODE = 'require'
pg_restore `
  -h shp-mgmt-pg-prod.postgres.database.azure.com `
  -U pgadmin `
  -d shp_mgmt_db `
  --no-owner --role=shp_app_user `
  .\backup\shp_mgmt_db_migrate.backup
```

### 14.5 Recriar grants de schema (se necessario)

Conectado ao banco no Azure:

```sql
GRANT USAGE ON SCHEMA shp TO shp_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA shp TO shp_app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA shp TO shp_app_user;
```

### 14.6 Validar consultas e indices

```sql
\dt shp.*
SELECT COUNT(*) FROM shp.export_runs;
SELECT COUNT(*) FROM shp.resources;
SELECT COUNT(*) FROM shp.permissions;
```

### 14.7 Redirecionar string de conexao da aplicacao

Atualize as variaveis de ambiente da aplicacao:

```dotenv
PG_HOST=shp-mgmt-pg-prod.postgres.database.azure.com
PG_PORT=5432
PG_DATABASE=shp_mgmt_db
PG_USER=shp_app_user
PG_PASSWORD=SenhaSeguraAqui
PG_SSL=true
```

Depois reinicie a aplicacao e valide que os endpoints respondem corretamente.

## 15. Operar backups gerenciados no Azure Flexible Server

O Azure Flexible Server realiza backups automaticos diariamente.
Nao e necessario executar `pg_dump` manualmente para o backup principal.

### Ver politica de backup

Portal do Azure > Flexible Server > **Backup and restore**

- Periodo de retencao: padrao 7 dias, maximo 35 dias
- Tipo: backup completo + WAL (point-in-time recovery)

### Point-in-time restore

Portal do Azure > Flexible Server > **Restore**

1. Escolha a data e hora para restauracao
2. O Azure cria um **novo servidor** (nao sobrescreve o atual)
3. Direcione a aplicacao para o novo servidor apos validacao
4. Apague o servidor antigo quando seguro

Nao e possivel restaurar diretamente no mesmo servidor pelo portal — isso e uma protecao contra sobrescrita acidental.

### Backup logico adicional (recomendado para migracao ou auditoria)

```powershell
$env:PGSSLMODE = 'require'
pg_dump `
  -h shp-mgmt-pg-prod.postgres.database.azure.com `
  -U pgadmin -d shp_mgmt_db `
  --format=custom --no-owner `
  -f .\backup\shp_mgmt_db_$(Get-Date -Format 'yyyyMMdd').backup
```

## 16. Monitorar com Azure Monitor

Portal do Azure > Flexible Server > **Metrics**

Metricas mais relevantes:

| Metrica | Alerta recomendado |
|---|---|
| `cpu_percent` | > 80% por mais de 5 minutos |
| `memory_percent` | > 85% |
| `storage_percent` | > 75% |
| `connections_failed` | qualquer valor aumentando |
| `active_connections` | proximo ao limite do SKU |
| `pg_replica_log_delay_in_bytes` | se usar replica de leitura |

### Criar alerta

Portal do Azure > Flexible Server > **Alerts > Create alert rule**

Exemplo: alerta quando `storage_percent > 75`:

1. Condition: `storage_percent` maior que `75`
2. Action Group: email ou webhook (Teams, PagerDuty)
3. Nome: `shp-pg-storage-alto`

## 17. Erros comuns

`password authentication failed for user`

- usuario/senha incorretos
- metodo de autenticacao do `pg_hba.conf` diferente do esperado

`database does not exist`

- banco ainda nao criado
- string de conexao apontando para nome incorreto

`permission denied for schema shp`

- usuario nao recebeu `USAGE` e `CREATE` no schema

## 18. Padrao de mudanca recomendado para o time

Antes de qualquer mudanca estrutural:

1. fazer backup
2. testar em ambiente local
3. aplicar em homologacao
4. registrar a mudanca em documentacao ou migracao versionada
