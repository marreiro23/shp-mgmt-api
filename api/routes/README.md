## Rotas ativas

Este arquivo documenta o mapeamento do router de negocio principal:

- arquivo: routes/sharepoint.routes.js
- prefixo efetivo: /api/v1/sharepoint

## Grupos de rotas

### Configuracao e autenticacao

- GET /api/v1/sharepoint/config
- GET /api/v1/sharepoint/inventory/database
- POST /api/v1/sharepoint/authenticate

### SharePoint sites, bibliotecas e drives

- GET /api/v1/sharepoint/sites
- GET /api/v1/sharepoint/sites/:siteId/drives
- POST /api/v1/sharepoint/sites/:siteId/drives
- GET /api/v1/sharepoint/sites/:siteId/libraries
- POST /api/v1/sharepoint/sites/:siteId/libraries
- PATCH /api/v1/sharepoint/sites/:siteId/libraries/:listId
- PATCH /api/v1/sharepoint/drives/:driveId

### Itens de biblioteca e metadados

- GET /api/v1/sharepoint/drives/:driveId/children
- GET /api/v1/sharepoint/drives/:driveId/files-metadata
- POST /api/v1/sharepoint/drives/:driveId/folders
- POST /api/v1/sharepoint/drives/:driveId/files
- PATCH /api/v1/sharepoint/drives/:driveId/items/:itemId
- DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId

### Permissoes

- GET /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions
- POST /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions
- DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions/:permissionId

### Entra e colaboracao

- GET /api/v1/sharepoint/groups
- POST /api/v1/sharepoint/groups
- PATCH /api/v1/sharepoint/groups/:groupId
- POST /api/v1/sharepoint/groups/:groupId/members
- DELETE /api/v1/sharepoint/groups/:groupId/members/:memberObjectId
- GET /api/v1/sharepoint/users
- PATCH /api/v1/sharepoint/users/:userId
- GET /api/v1/sharepoint/users/:userId/licenses
- POST /api/v1/sharepoint/users/:userId/licenses
- GET /api/v1/sharepoint/teams/:teamId/channels
- POST /api/v1/sharepoint/teams/:teamId/channels
- PATCH /api/v1/sharepoint/teams/:teamId/channels/:channelId
- GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/members
- POST /api/v1/sharepoint/teams/:teamId/channels/:channelId/members
- DELETE /api/v1/sharepoint/teams/:teamId/channels/:channelId/members/:membershipId
- GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/content

### Exportacao operacional

- GET /api/v1/sharepoint/export

### Administracao e governanca

- GET /api/v1/sharepoint/admin/app-registration
- POST /api/v1/sharepoint/admin/update-scopes
- GET /api/v1/sharepoint/admin-governance/export/package
- POST /api/v1/sharepoint/admin-governance/import/preview
- POST /api/v1/sharepoint/admin-governance/import/execute
- POST /api/v1/sharepoint/admin-governance/compare/preview
- POST /api/v1/sharepoint/admin-governance/compare/execute
- GET /api/v1/sharepoint/admin-governance/compare/export
- GET /api/v1/sharepoint/operations/:operationId
- GET /api/v1/sharepoint/audit/events

## Middlewares aplicados no servidor

- helmet
- CORS
- parser JSON/urlencoded
- logger customizado
- rate limiting para /api
- tratamento padrao de erro com correlationId
