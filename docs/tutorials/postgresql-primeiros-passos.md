# PostgreSQL: primeiros passos no projeto

Este tutorial mostra como preparar um ambiente PostgreSQL local para armazenar
dados exportados do tenant SharePoint/Graph neste projeto.

Ao final, voce tera:

- um servidor PostgreSQL local em execucao
- um banco dedicado para o projeto
- um usuario de aplicacao com acesso restrito
- tabelas iniciais para runs, recursos e permissoes
- exemplos de consulta e validacao

## Quando usar este tutorial

Use este guia quando:

- o time ainda nao domina PostgreSQL
- for necessario montar um ambiente local rapidamente
- voce quiser uma base segura para comecar antes de produzir migracoes formais

## Opcoes de ambiente

Este tutorial cobre dois caminhos:

| Opcao | Quando usar |
|---|---|
| Opcao 1: local (Windows) | desenvolvimento, testes, primeiros passos |
| Opcao 2: Azure Flexible Server | homologacao e producao |

---

## Opcao 1: ambiente local (desenvolvimento)

Para equipes com baixo conhecimento em PostgreSQL, o caminho mais simples e:

1. instalar PostgreSQL localmente
2. instalar pgAdmin para administracao visual
3. usar `psql` para os comandos basicos

### Instalacao no Windows

1. Baixe PostgreSQL Community Edition.
2. Instale a versao estavel atual.
3. Durante a instalacao, anote:
   - porta do servidor
   - senha do usuario `postgres`
   - pasta de dados
4. Instale pgAdmin se desejar interface grafica.

Padrao mais comum:

- host: `localhost`
- port: `5432`
- superuser: `postgres`

### Validando a instalacao

Abra PowerShell e execute:

```powershell
psql --version
```

Depois teste a conexao:

```powershell
psql -h localhost -p 5432 -U postgres -d postgres
```

---

## Opcao 2: Azure Database for PostgreSQL Flexible Server

Para homologacao e producao, use o servico gerenciado do Azure.
Ele elimina a necessidade de gerenciar SO, patches e backups manualmente.

### Provisionando via Azure Portal

1. No portal do Azure, busque por **Azure Database for PostgreSQL**.
2. Escolha **Flexible Server** e clique em **Create**.
3. Preencha:
   - **Resource group**: use o grupo existente do projeto
   - **Server name**: por exemplo, `shp-mgmt-pg-prod`
   - **Region**: West Europe ou East US 2 (conforme latencia)
   - **PostgreSQL version**: 16
   - **Authentication method**: PostgreSQL authentication
   - **Admin username**: `pgadmin` (nao use `postgres` como nome de admin em producao)
   - **Password**: senha forte, armazenada em Azure Key Vault
4. Em **Compute + storage**:
   - Burstable B2s para dev/staging; General Purpose D4ds_v4 para producao
   - Storage: comece com 32 GB, com auto-grow ativado
5. Em **Networking**:
   - **Connectivity method**: Public access (recommended com firewall rules) OU Private access (VNet Integration)
   - Adicione regra de firewall para o IP de administracao ou use Private Endpoint
   - Marque **Allow public access from any Azure service** apenas se necessario
6. Revise e crie.

### Configurando o firewall

Apos provisionar, va em **Networking** e adicione os IPs necessarios:

```text
Nome da regra      IP inicial       IP final
--------------------------------------------------
DevOps-Runner      203.0.113.10     203.0.113.10
API-AppService     (obtido via Azure portal do App Service)
```

Para conexao temporaria de administracao:

```powershell
# descubra seu IP publico
(Invoke-RestMethod -Uri 'https://api.ipify.org')
```

### Obtendo a string de conexao

No portal do Azure: **Flexible Server > Connect > Connection strings > psql**

Formato:

```text
psql "host=shp-mgmt-pg-prod.postgres.database.azure.com port=5432 dbname=postgres user=pgadmin password=SENHA sslmode=require"
```

Para a aplicacao Node.js, use variaveis de ambiente:

```dotenv
PG_HOST=shp-mgmt-pg-prod.postgres.database.azure.com
PG_PORT=5432
PG_DATABASE=shp_mgmt_db
PG_USER=shp_app_user
PG_PASSWORD=<senha-do-usuario-da-aplicacao>
PG_SSL=true
```

### Notas importantes sobre SSL no Azure

O Azure Flexible Server exige SSL por padrao (`sslmode=require`).
Nao desative esta opcao em producao.

Para `psql`:

```powershell
$env:PGSSLMODE = 'require'
psql -h shp-mgmt-pg-prod.postgres.database.azure.com -U pgadmin -d postgres
```

### Criando banco e usuario de aplicacao no Azure

As etapas de DDL sao identicas ao ambiente local.
Conecte via `psql` (com SSL) e execute os mesmos scripts de:

- criacao de role
- criacao de banco
- criacao de schema
- criacao de tabelas e indices
- grant de permissoes

Veja as secoes seguintes deste tutorial.

## Criando banco e usuario do projeto

Conectado como `postgres`, execute:

```sql
CREATE ROLE shp_app_user WITH
  LOGIN
  PASSWORD 'TroqueEstaSenhaAgora';

CREATE DATABASE shp_mgmt_db
  WITH
  OWNER = postgres
  ENCODING = 'UTF8';

GRANT CONNECT ON DATABASE shp_mgmt_db TO shp_app_user;
```

Agora entre no banco:

```powershell
psql -h localhost -p 5432 -U postgres -d shp_mgmt_db
```

## Criando schema da aplicacao

```sql
CREATE SCHEMA IF NOT EXISTS shp AUTHORIZATION postgres;

GRANT USAGE ON SCHEMA shp TO shp_app_user;
GRANT CREATE ON SCHEMA shp TO shp_app_user;
```

## Criando tabelas iniciais

```sql
CREATE TABLE IF NOT EXISTS shp.export_runs (
  id BIGSERIAL PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  source TEXT NOT NULL,
  format TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ NULL,
  status TEXT NOT NULL DEFAULT 'running',
  summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS shp.resources (
  id BIGSERIAL PRIMARY KEY,
  export_run_id BIGINT NOT NULL REFERENCES shp.export_runs(id) ON DELETE CASCADE,
  tenant_id TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  parent_resource_id TEXT NULL,
  site_id TEXT NULL,
  drive_id TEXT NULL,
  item_id TEXT NULL,
  team_id TEXT NULL,
  channel_id TEXT NULL,
  display_name TEXT NULL,
  web_url TEXT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  exported_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shp.permissions (
  id BIGSERIAL PRIMARY KEY,
  export_run_id BIGINT NOT NULL REFERENCES shp.export_runs(id) ON DELETE CASCADE,
  tenant_id TEXT NOT NULL,
  schema_version TEXT NOT NULL DEFAULT 'sharepoint-permission-v1',
  resource_type TEXT NOT NULL,
  resource_name TEXT NULL,
  site_id TEXT NULL,
  drive_id TEXT NULL,
  item_id TEXT NULL,
  team_id TEXT NULL,
  channel_id TEXT NULL,
  permission_id TEXT NULL,
  principal_type TEXT NULL,
  principal_id TEXT NULL,
  principal_email TEXT NULL,
  principal_display_name TEXT NULL,
  roles JSONB NOT NULL DEFAULT '[]'::jsonb,
  inherited_from JSONB NULL,
  link JSONB NULL,
  invitation JSONB NULL,
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  exported_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Criando indices basicos

```sql
CREATE INDEX IF NOT EXISTS ix_export_runs_tenant_started
  ON shp.export_runs (tenant_id, started_at DESC);

CREATE INDEX IF NOT EXISTS ix_resources_run_type
  ON shp.resources (export_run_id, resource_type);

CREATE INDEX IF NOT EXISTS ix_resources_site_drive_item
  ON shp.resources (site_id, drive_id, item_id);

CREATE INDEX IF NOT EXISTS ix_permissions_run_type
  ON shp.permissions (export_run_id, resource_type);

CREATE INDEX IF NOT EXISTS ix_permissions_principal_email
  ON shp.permissions (principal_email);

CREATE INDEX IF NOT EXISTS ix_permissions_drive_item
  ON shp.permissions (drive_id, item_id);

CREATE INDEX IF NOT EXISTS ix_permissions_roles_gin
  ON shp.permissions USING GIN (roles);

CREATE INDEX IF NOT EXISTS ix_permissions_raw_payload_gin
  ON shp.permissions USING GIN (raw_payload);
```

## Permissoes para o usuario da aplicacao

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA shp TO shp_app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA shp TO shp_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA shp
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO shp_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA shp
GRANT USAGE, SELECT ON SEQUENCES TO shp_app_user;
```

## Testando insercao

```sql
INSERT INTO shp.export_runs (tenant_id, source, format, status, summary)
VALUES (
  'contoso.onmicrosoft.com',
  'tenant-permissions-standard',
  'json',
  'succeeded',
  '{"permissions": 120, "sites": 15}'::jsonb
)
RETURNING id;
```

## Consultando dados

Ultimos runs:

```sql
SELECT id, tenant_id, source, format, status, started_at
FROM shp.export_runs
ORDER BY started_at DESC
LIMIT 10;
```

Permissoes por usuario:

```sql
SELECT principal_email, resource_type, resource_name, roles, exported_at
FROM shp.permissions
WHERE principal_email = 'user@example.com'
ORDER BY exported_at DESC;
```

Arquivos exportados de um drive:

```sql
SELECT display_name, drive_id, item_id, web_url
FROM shp.resources
WHERE resource_type = 'file'
  AND drive_id = 'drive-01';
```

## Resultado esperado

Ao final, voce deve conseguir:

- acessar o banco com `psql`
- visualizar tabelas no schema `shp`
- inserir e consultar dados sem erro

## Proximo passo

Depois deste tutorial, siga para:

- [Referencia de ambiente e schema](../reference/postgresql-ambiente-e-schema.md)
- [Como operar, manter e expandir o PostgreSQL](operar-e-expandir-postgresql.md)
- [Runbook de incidentes e troubleshooting](runbook-incidentes-postgresql.md)
