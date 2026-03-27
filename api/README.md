# API SharePoint Graph

API REST para operações SharePoint Online via Microsoft Graph com autenticação
por certificado.

## Ambiente

Defina no arquivo `.env`:

```env
TENANT_ID=<tenant-id>
CLIENT_ID=<app-id>
CERT_THUMBPRINT=<thumbprint-sha1>
CERT_PRIVATE_KEY_PATH=../certs/sharepoint-file-manager-api.pem
GRAPH_SCOPE=https://graph.microsoft.com/.default
PORT=3001
HOST=localhost
```

## Inicialização

```bash
npm install
npm run start:lts
```

## Interface web

- entrada padrao: `/web/operations-center.html`
- entrada legada: `/web/index.html?legacy=1`
- modulos legados: `/web/operations.html`, `/web/collaboration.html`, `/web/admin.html`

Quando acessado sem query string, `/web/index.html` redireciona para
`/web/operations-center.html`.

## Rotas

- `GET /health`
- `GET /api/v1/config`
- `GET /api/v1/sharepoint/config`
- `POST /api/v1/sharepoint/authenticate`
- `GET /api/v1/sharepoint/sites?search=*&top=10`
- `GET /api/v1/sharepoint/groups?search=Financeiro&top=50`
- `POST /api/v1/sharepoint/groups`
- `PATCH /api/v1/sharepoint/groups/:groupId`
- `GET /api/v1/sharepoint/users?search=Maria&top=50`
- `PATCH /api/v1/sharepoint/users/:userId`
- `GET /api/v1/sharepoint/users/:userId/licenses`
- `POST /api/v1/sharepoint/users/:userId/licenses`
- `GET /api/v1/sharepoint/sites/:siteId/drives`
- `POST /api/v1/sharepoint/sites/:siteId/drives`
- `GET /api/v1/sharepoint/sites/:siteId/libraries`
- `POST /api/v1/sharepoint/sites/:siteId/libraries`
- `PATCH /api/v1/sharepoint/sites/:siteId/libraries/:listId`
- `GET /api/v1/sharepoint/drives/:driveId/children?path=Documentos/Projeto`
- `GET /api/v1/sharepoint/drives/:driveId/files-metadata?path=Documentos&top=100`
- `PATCH /api/v1/sharepoint/drives/:driveId`
- `GET /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions`
- `POST /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions`
- `DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions/:permissionId`
- `POST /api/v1/sharepoint/drives/:driveId/folders`
- `POST /api/v1/sharepoint/drives/:driveId/files`
- `PATCH /api/v1/sharepoint/drives/:driveId/items/:itemId`
- `DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId`
- `GET /api/v1/sharepoint/teams/:teamId/channels`
- `POST /api/v1/sharepoint/teams/:teamId/channels`
- `PATCH /api/v1/sharepoint/teams/:teamId/channels/:channelId`
- `GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/members`
- `GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/content?topMessages=25`
- `POST /api/v1/sharepoint/teams/:teamId/channels/:channelId/members`
- `DELETE /api/v1/sharepoint/teams/:teamId/channels/:channelId/members/:membershipId`
- `POST /api/v1/sharepoint/groups/:groupId/members`
- `DELETE /api/v1/sharepoint/groups/:groupId/members/:memberObjectId`
- `GET /api/v1/sharepoint/export?source=drive-files&format=csv&driveId=<driveId>`
- `GET /api/v1/sharepoint/admin-governance/export/package?source=site-libraries&format=json`
- `POST /api/v1/sharepoint/admin-governance/import/preview`
- `POST /api/v1/sharepoint/admin-governance/import/execute`
- `POST /api/v1/sharepoint/admin-governance/compare/preview`
- `POST /api/v1/sharepoint/admin-governance/compare/execute`
- `GET /api/v1/sharepoint/admin-governance/compare/export?operationId=<id>&format=csv`
- `POST /api/v1/sharepoint/admin-governance/import/permissions-package`
- `GET /api/v1/sharepoint/operations/:operationId`
- `GET /api/v1/sharepoint/audit/events`

### Importacao administrativa (governanca)

`POST /api/v1/sharepoint/admin-governance/import/preview` e
`POST /api/v1/sharepoint/admin-governance/import/execute` suportam:

- modos: `always`, `skip-if-exists`, `update`, `replace-safe`
- tipos de objeto: `library`, `folder`, `permission`
- ordem de dependencia aplicada pelo engine: `library` -> `folder` -> `permission`

## Payloads

```json
{
  "name": "Relatorios-2026",
  "parentPath": "Documentos"
}
```

```json
{
  "fileName": "nota.txt",
  "parentPath": "Documentos/Relatorios-2026",
  "content": "conteudo do arquivo"
}
```

```json
{
  "newName": "nota-v2.txt"
}
```

```json
{
  "userId": "<user-object-id>",
  "roles": ["owner"]
}
```

```json
{
  "memberObjectId": "<directory-object-id>"
}
```

```json
{
  "displayName": "Time Financeiro",
  "mailNickname": "financeiro",
  "description": "Grupo para times financeiros"
}
```

```json
{
  "displayName": "Contratos 2026",
  "description": "Biblioteca documental do ano",
  "columns": []
}
```

```json
{
  "jobTitle": "Analista Senior"
}
```

```json
{
  "addLicenses": [{ "skuId": "<sku-id>" }],
  "removeLicenses": []
}
```

```json
{
  "recipients": [{ "email": "user@example.com" }],
  "roles": ["write"],
  "message": "Acesso concedido pela API"
}
```

```json
{
  "displayName": "Projetos",
  "description": "Canal de projetos",
  "membershipType": "standard"
}
```

```json
{
  "name": "Drive Operacional",
  "description": "Descricao atualizada do drive"
}
```

## Notas de escopo

- Bibliotecas SharePoint sao tratadas como `lists` com template `documentLibrary` e expostas tambem como `drives` no Microsoft Graph.
- `POST /api/v1/sharepoint/sites/:siteId/drives` provisiona uma nova document library e retorna o drive associado quando disponivel.
- Sites SharePoint continuam somente leitura no Graph v1.0 para este fluxo; criacao e alteracao de sites permanecem fora do escopo estavel da API.

## Exportacao

`GET /api/v1/sharepoint/export` suporta:

- `format=json|csv|xlsx`
- `source=drive-files` (requer `driveId`, aceita `path`, `top`)
- `source=site-drives` (requer `siteId`)
- `source=site-libraries` (requer `siteId`)
- `source=team-channels` (requer `teamId`)
- `source=team-channel-content` (requer `teamId` e `channelId`, aceita `topMessages`)
- `source=groups` (aceita `search`, `top`)
- `source=users` (aceita `search`, `top`)
- `source=user-licenses` (requer `userId`)
- `source=item-permissions` (requer `driveId` e `itemId`)
- `source=team-channel-members` (requer `teamId` e `channelId`)
- `source=tenant-sharepoint-inventory` (aceita `search`, `topSites`, `topItemsPerDrive`, `includePermissions`, `includeChannelPermissions`, `teamIds`)
- `source=tenant-permissions-standard` (aceita `search`, `topSites`, `topItemsPerDrive`, `includeChannelPermissions`, `teamIds`)

O endpoint responde com download (`Content-Disposition: attachment`) nos formatos `.json`, `.csv` ou `.xlsx`.

### Importacao de pacote de permissoes/configuracoes

`POST /api/v1/sharepoint/admin-governance/import/permissions-package` recebe um pacote com array
`permissions` e aplica no tenant conectado (ou simula com `dryRun=true`).

Exemplo:

```json
{
  "mode": "update",
  "dryRun": true,
  "permissions": [
    {
      "resourceType": "file",
      "driveId": "drive-id",
      "itemId": "item-id",
      "principalEmail": "user@example.com",
      "roles": ["read"]
    }
  ]
}
```

## Envelope de erro

```json
{
  "success": false,
  "correlationId": "...",
  "error": {
    "code": "SP_500",
    "message": "Falha ao autenticar no Microsoft Graph."
  }
}
```
