# PostgreSQL: ambiente, modelagem e referencia tecnica

Esta referencia descreve a estrutura recomendada para armazenar dados exportados
do tenant SharePoint/Graph em PostgreSQL.

## Objetivo da base

Armazenar:

- runs de exportacao
- inventario de recursos
- permissoes normalizadas
- payloads brutos para reprocessamento

## Visao logica

```text
export_runs
  -> resources
  -> permissions
```

## Tabela `shp.export_runs`

Responsavel por registrar cada ciclo de exportacao.

Campos principais:

- `id`: chave primaria tecnica
- `tenant_id`: tenant exportado
- `source`: origem da exportacao, por exemplo `tenant-sharepoint-inventory`
- `format`: json, csv, xlsx
- `started_at` / `finished_at`: janela da execucao
- `status`: running, succeeded, failed, partial
- `summary`: resumo agregado em JSONB
- `metadata`: dados adicionais de contexto

## Tabela `shp.resources`

Responsavel por persistir recursos exportados.

Tipos comuns de `resource_type`:

- `site`
- `drive`
- `folder`
- `file`
- `channel`

Campos principais:

- `resource_id`: id do recurso no Graph
- `parent_resource_id`: id logico do pai quando existir
- `site_id`, `drive_id`, `item_id`, `team_id`, `channel_id`: chaves de navegacao
- `display_name`: nome funcional do recurso
- `payload`: raw normalizado ou parcial do recurso

## Tabela `shp.permissions`

Responsavel por persistir permissoes exportadas no padrao:

- `schema_version = sharepoint-permission-v1`

Campos principais:

- `resource_type`
- `resource_name`
- `permission_id`
- `principal_type`
- `principal_id`
- `principal_email`
- `principal_display_name`
- `roles`
- `raw_payload`

## Relacoes recomendadas

- `export_runs.id -> resources.export_run_id`
- `export_runs.id -> permissions.export_run_id`

## Indices recomendados

Operacionais:

- `(tenant_id, started_at desc)` em `export_runs`
- `(export_run_id, resource_type)` em `resources`
- `(export_run_id, resource_type)` em `permissions`
- `(principal_email)` em `permissions`
- `(site_id, drive_id, item_id)` em `resources`
- `(drive_id, item_id)` em `permissions`

JSONB:

- GIN em `permissions.roles`
- GIN em `permissions.raw_payload`
- opcionalmente GIN em `resources.payload`

## Convencoes recomendadas

- usar schema dedicado: `shp`
- separar usuario administrador e usuario da aplicacao
- nao usar `postgres` como usuario da aplicacao
- preferir `TIMESTAMPTZ`
- manter payload bruto para reprocessamento e auditoria

## Estrategia de retencao

Sugestao inicial:

- `export_runs`: 12 meses
- `resources`: 6 a 12 meses, conforme volume
- `permissions`: 12 a 24 meses, conforme requisito de auditoria

## Estrategia de particionamento

Aplicar quando volume crescer de forma recorrente.

Opcao sugerida:

- particionar `resources` e `permissions` por mes usando `exported_at`

Exemplo conceitual:

```sql
CREATE TABLE shp.permissions_2026_03 PARTITION OF shp.permissions
FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
```

## Consultas frequentes

Permissoes por principal:

```sql
SELECT principal_email, resource_type, resource_name, roles
FROM shp.permissions
WHERE principal_email = 'user@example.com';
```

Recursos por site:

```sql
SELECT resource_type, display_name, drive_id, item_id
FROM shp.resources
WHERE site_id = 'site-01'
ORDER BY resource_type, display_name;
```

Ultimo export bem-sucedido:

```sql
SELECT id, tenant_id, source, started_at, finished_at, summary
FROM shp.export_runs
WHERE status = 'succeeded'
ORDER BY started_at DESC
LIMIT 1;
```

## Evolucao futura

Campos que podem entrar depois:

- `content_hash` para deduplicacao
- `tenant_environment` para separar dev/hml/prd
- `source_operation_id` para rastrear execucoes assincronas da API
- `import_run_id` para fechar ciclo export/import
