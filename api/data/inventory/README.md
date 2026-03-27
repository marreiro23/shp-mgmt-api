# Inventario SharePoint

Diretorio reservado para dados locais associados ao fluxo SharePoint Graph.

## Convencao sugerida

- `inventory-db.json` (base de dados local persistente)
- `inventory_sharepoint_sites_YYYY-MM-DD_HH-MM-SS.json`
- `inventory_sharepoint_drives_YYYY-MM-DD_HH-MM-SS.json`
- `inventory_sharepoint_items_YYYY-MM-DD_HH-MM-SS.json`

## Uso

- Persistir snapshots de validacao quando necessario.
- Comparar execucoes de listagem entre periodos diferentes.
- Alimentar auditorias internas sem expor dados sensiveis.

## Base de dados local

- Arquivo principal: `inventory-db.json`
- Estrutura armazenada:
  - `sites`
  - `drives`
  - `libraries`
  - `files`
- Endpoint para leitura da base:
  - `GET /api/v1/sharepoint/inventory/database`

Essa base e atualizada automaticamente quando endpoints de listagem/criacao/atualizacao de sites, drives, bibliotecas e arquivos sao executados.
