# Endpoints: Invoke-RestMethod, curl e Postman

Guia pratico para usar todos os endpoints ativos da API.

## Base e variaveis

PowerShell:

```powershell
$Base = 'http://localhost:3001'
$Api = "$Base/api/v1/sharepoint"
```

Bash:

```bash
BASE="http://localhost:3001"
API="$BASE/api/v1/sharepoint"
```

Postman (Environment):

- baseUrl = `http://localhost:3001`
- apiBase = {{baseUrl}}/api/v1/sharepoint
- siteId, driveId, listId, itemId, teamId, channelId, userId, groupId, permissionId, membershipId

## 1) Endpoints gerais da API

### GET /health

PowerShell:

```powershell
Invoke-RestMethod -Method Get -Uri "$Base/health"
```

curl:

```bash
curl "$BASE/health"
```

Postman:

- Method: GET
- URL: {{baseUrl}}/health

### GET /api/v1/config

PowerShell:

```powershell
Invoke-RestMethod -Method Get -Uri "$Base/api/v1/config"
```

curl:

```bash
curl "$BASE/api/v1/config"
```

Postman:

- Method: GET
- URL: {{baseUrl}}/api/v1/config

## 2) Configuracao e autenticacao SharePoint

### GET /api/v1/sharepoint/config

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/config"
```

```bash
curl "$API/config"
```

Postman: GET {{apiBase}}/config

### POST /api/v1/sharepoint/authenticate

```powershell
Invoke-RestMethod -Method Post -Uri "$Api/authenticate"
```

```bash
curl -X POST "$API/authenticate"
```

Postman: POST {{apiBase}}/authenticate

## 3) Inventario local (base de dados)

### GET /api/v1/sharepoint/inventory/database

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/inventory/database"
```

```bash
curl "$API/inventory/database"
```

Postman: GET {{apiBase}}/inventory/database

## 4) Sites, drives e bibliotecas

### GET /api/v1/sharepoint/sites?search=*&top=10

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/sites?search=*&top=10"
```

```bash
curl "$API/sites?search=*&top=10"
```

Postman: GET {{apiBase}}/sites?search=*&top=10

### GET /api/v1/sharepoint/sites/:siteId/drives

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/sites/$siteId/drives"
```

```bash
curl "$API/sites/$siteId/drives"
```

Postman: GET {{apiBase}}/sites/{{siteId}}/drives

### POST /api/v1/sharepoint/sites/:siteId/drives

```powershell
$body = @{ displayName = 'Drive Operacional'; description = 'Drive criado pela API' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/sites/$siteId/drives" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/sites/$siteId/drives" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Drive Operacional","description":"Drive criado pela API"}'
```

Postman:

- Method: POST
- URL: {{apiBase}}/sites/{{siteId}}/drives
- Body raw JSON:

```json
{
  "displayName": "Drive Operacional",
  "description": "Drive criado pela API"
}
```

### GET /api/v1/sharepoint/sites/:siteId/libraries

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/sites/$siteId/libraries"
```

```bash
curl "$API/sites/$siteId/libraries"
```

Postman: GET {{apiBase}}/sites/{{siteId}}/libraries

### POST /api/v1/sharepoint/sites/:siteId/libraries

```powershell
$body = @{ displayName = 'Contratos 2026'; description = 'Biblioteca documental' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/sites/$siteId/libraries" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/sites/$siteId/libraries" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Contratos 2026","description":"Biblioteca documental"}'
```

Postman: POST {{apiBase}}/sites/{{siteId}}/libraries

### PATCH /api/v1/sharepoint/sites/:siteId/libraries/:listId

```powershell
$body = @{ displayName = 'Contratos Atualizados'; description = 'Nova descricao' } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$Api/sites/$siteId/libraries/$listId" -ContentType 'application/json' -Body $body
```

```bash
curl -X PATCH "$API/sites/$siteId/libraries/$listId" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Contratos Atualizados","description":"Nova descricao"}'
```

Postman: PATCH {{apiBase}}/sites/{{siteId}}/libraries/{{listId}}

### PATCH /api/v1/sharepoint/drives/:driveId

```powershell
$body = @{ name = 'Drive Renomeado'; description = 'Descricao atualizada' } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$Api/drives/$driveId" -ContentType 'application/json' -Body $body
```

```bash
curl -X PATCH "$API/drives/$driveId" \
  -H "Content-Type: application/json" \
  -d '{"name":"Drive Renomeado","description":"Descricao atualizada"}'
```

Postman: PATCH {{apiBase}}/drives/{{driveId}}

## 5) Arquivos, pastas e metadados

### GET /api/v1/sharepoint/drives/:driveId/children?path=

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/drives/$driveId/children?path=Documentos/Projetos"
```

```bash
curl "$API/drives/$driveId/children?path=Documentos/Projetos"
```

Postman: GET {{apiBase}}/drives/{{driveId}}/children?path=Documentos/Projetos

### GET /api/v1/sharepoint/drives/:driveId/files-metadata?path=&top=

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/drives/$driveId/files-metadata?path=Documentos&top=100"
```

```bash
curl "$API/drives/$driveId/files-metadata?path=Documentos&top=100"
```

Postman: GET {{apiBase}}/drives/{{driveId}}/files-metadata?path=Documentos&top=100

### POST /api/v1/sharepoint/drives/:driveId/folders

```powershell
$body = @{ name = 'NovaPasta'; parentPath = 'Documentos' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/drives/$driveId/folders" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/drives/$driveId/folders" \
  -H "Content-Type: application/json" \
  -d '{"name":"NovaPasta","parentPath":"Documentos"}'
```

Postman: POST {{apiBase}}/drives/{{driveId}}/folders

### POST /api/v1/sharepoint/drives/:driveId/files

```powershell
$body = @{ fileName = 'nota.txt'; parentPath = 'Documentos'; content = 'conteudo do arquivo' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/drives/$driveId/files" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/drives/$driveId/files" \
  -H "Content-Type: application/json" \
  -d '{"fileName":"nota.txt","parentPath":"Documentos","content":"conteudo do arquivo"}'
```

Postman: POST {{apiBase}}/drives/{{driveId}}/files

### PATCH /api/v1/sharepoint/drives/:driveId/items/:itemId

```powershell
$body = @{ newName = 'nota-v2.txt' } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$Api/drives/$driveId/items/$itemId" -ContentType 'application/json' -Body $body
```

```bash
curl -X PATCH "$API/drives/$driveId/items/$itemId" \
  -H "Content-Type: application/json" \
  -d '{"newName":"nota-v2.txt"}'
```

Postman: PATCH {{apiBase}}/drives/{{driveId}}/items/{{itemId}}

### DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId

```powershell
Invoke-RestMethod -Method Delete -Uri "$Api/drives/$driveId/items/$itemId"
```

```bash
curl -X DELETE "$API/drives/$driveId/items/$itemId"
```

Postman: DELETE {{apiBase}}/drives/{{driveId}}/items/{{itemId}}

## 6) Permissoes de item

### GET /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/drives/$driveId/items/$itemId/permissions"
```

```bash
curl "$API/drives/$driveId/items/$itemId/permissions"
```

Postman: GET {{apiBase}}/drives/{{driveId}}/items/{{itemId}}/permissions

### POST /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions

```powershell
$body = @{
  recipients = @(@{ email = 'user@example.com' })
  roles = @('write')
  message = 'Acesso concedido pela API'
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Post -Uri "$Api/drives/$driveId/items/$itemId/permissions" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/drives/$driveId/items/$itemId/permissions" \
  -H "Content-Type: application/json" \
  -d '{"recipients":[{"email":"user@example.com"}],"roles":["write"],"message":"Acesso concedido pela API"}'
```

Postman: POST {{apiBase}}/drives/{{driveId}}/items/{{itemId}}/permissions

### DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions/:permissionId

```powershell
Invoke-RestMethod -Method Delete -Uri "$Api/drives/$driveId/items/$itemId/permissions/$permissionId"
```

```bash
curl -X DELETE "$API/drives/$driveId/items/$itemId/permissions/$permissionId"
```

Postman: DELETE {{apiBase}}/drives/{{driveId}}/items/{{itemId}}/permissions/{{permissionId}}

## 7) Grupos Entra ID

### GET /api/v1/sharepoint/groups?search=&top=

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/groups?search=Financeiro&top=25"
```

```bash
curl "$API/groups?search=Financeiro&top=25"
```

Postman: GET {{apiBase}}/groups?search=Financeiro&top=25

### POST /api/v1/sharepoint/groups

```powershell
$body = @{ displayName='Time Financeiro'; mailNickname='financeiro'; description='Grupo para financeiro' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/groups" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/groups" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Time Financeiro","mailNickname":"financeiro","description":"Grupo para financeiro"}'
```

Postman: POST {{apiBase}}/groups

### PATCH /api/v1/sharepoint/groups/:groupId

```powershell
$body = @{ description='Descricao atualizada' } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$Api/groups/$groupId" -ContentType 'application/json' -Body $body
```

```bash
curl -X PATCH "$API/groups/$groupId" \
  -H "Content-Type: application/json" \
  -d '{"description":"Descricao atualizada"}'
```

Postman: PATCH {{apiBase}}/groups/{{groupId}}

### POST /api/v1/sharepoint/groups/:groupId/members

```powershell
$body = @{ memberObjectId='00000000-0000-0000-0000-000000000000' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/groups/$groupId/members" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/groups/$groupId/members" \
  -H "Content-Type: application/json" \
  -d '{"memberObjectId":"00000000-0000-0000-0000-000000000000"}'
```

Postman: POST {{apiBase}}/groups/{{groupId}}/members

### DELETE /api/v1/sharepoint/groups/:groupId/members/:memberObjectId

```powershell
Invoke-RestMethod -Method Delete -Uri "$Api/groups/$groupId/members/$memberObjectId"
```

```bash
curl -X DELETE "$API/groups/$groupId/members/$memberObjectId"
```

Postman: DELETE {{apiBase}}/groups/{{groupId}}/members/{{memberObjectId}}

## 8) Usuarios e licencas

### GET /api/v1/sharepoint/users?search=&top=

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/users?search=Maria&top=25"
```

```bash
curl "$API/users?search=Maria&top=25"
```

Postman: GET {{apiBase}}/users?search=Maria&top=25

### PATCH /api/v1/sharepoint/users/:userId

```powershell
$body = @{ jobTitle='Analista Senior' } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$Api/users/$userId" -ContentType 'application/json' -Body $body
```

```bash
curl -X PATCH "$API/users/$userId" \
  -H "Content-Type: application/json" \
  -d '{"jobTitle":"Analista Senior"}'
```

Postman: PATCH {{apiBase}}/users/{{userId}}

### GET /api/v1/sharepoint/users/:userId/licenses

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/users/$userId/licenses"
```

```bash
curl "$API/users/$userId/licenses"
```

Postman: GET {{apiBase}}/users/{{userId}}/licenses

### POST /api/v1/sharepoint/users/:userId/licenses

```powershell
$body = @{
  addLicenses = @(@{ skuId = '00000000-0000-0000-0000-000000000000' })
  removeLicenses = @()
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Post -Uri "$Api/users/$userId/licenses" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/users/$userId/licenses" \
  -H "Content-Type: application/json" \
  -d '{"addLicenses":[{"skuId":"00000000-0000-0000-0000-000000000000"}],"removeLicenses":[]}'
```

Postman: POST {{apiBase}}/users/{{userId}}/licenses

## 9) Teams: canais, membros e conteudo

### GET /api/v1/sharepoint/teams/:teamId/channels

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/teams/$teamId/channels"
```

```bash
curl "$API/teams/$teamId/channels"
```

Postman: GET {{apiBase}}/teams/{{teamId}}/channels

### POST /api/v1/sharepoint/teams/:teamId/channels

```powershell
$body = @{ displayName='Projetos'; description='Canal de projetos'; membershipType='standard' } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/teams/$teamId/channels" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/teams/$teamId/channels" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Projetos","description":"Canal de projetos","membershipType":"standard"}'
```

Postman: POST {{apiBase}}/teams/{{teamId}}/channels

### PATCH /api/v1/sharepoint/teams/:teamId/channels/:channelId

```powershell
$body = @{ description='Canal atualizado' } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$Api/teams/$teamId/channels/$channelId" -ContentType 'application/json' -Body $body
```

```bash
curl -X PATCH "$API/teams/$teamId/channels/$channelId" \
  -H "Content-Type: application/json" \
  -d '{"description":"Canal atualizado"}'
```

Postman: PATCH {{apiBase}}/teams/{{teamId}}/channels/{{channelId}}

### GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/members

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/teams/$teamId/channels/$channelId/members"
```

```bash
curl "$API/teams/$teamId/channels/$channelId/members"
```

Postman: GET {{apiBase}}/teams/{{teamId}}/channels/{{channelId}}/members

### POST /api/v1/sharepoint/teams/:teamId/channels/:channelId/members

```powershell
$body = @{ userId='00000000-0000-0000-0000-000000000000'; roles=@('owner') } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/teams/$teamId/channels/$channelId/members" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/teams/$teamId/channels/$channelId/members" \
  -H "Content-Type: application/json" \
  -d '{"userId":"00000000-0000-0000-0000-000000000000","roles":["owner"]}'
```

Postman: POST {{apiBase}}/teams/{{teamId}}/channels/{{channelId}}/members

### DELETE /api/v1/sharepoint/teams/:teamId/channels/:channelId/members/:membershipId

```powershell
Invoke-RestMethod -Method Delete -Uri "$Api/teams/$teamId/channels/$channelId/members/$membershipId"
```

```bash
curl -X DELETE "$API/teams/$teamId/channels/$channelId/members/$membershipId"
```

Postman: DELETE {{apiBase}}/teams/{{teamId}}/channels/{{channelId}}/members/{{membershipId}}

### GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/content?topMessages=25

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/teams/$teamId/channels/$channelId/content?topMessages=25"
```

```bash
curl "$API/teams/$teamId/channels/$channelId/content?topMessages=25"
```

Postman: GET {{apiBase}}/teams/{{teamId}}/channels/{{channelId}}/content?topMessages=25

## 10) Exportacao

### GET /api/v1/sharepoint/export

Exemplo JSON:

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/export?source=users&format=json"
```

```bash
curl "$API/export?source=users&format=json"
```

Exemplo CSV:

```powershell
Invoke-WebRequest -Method Get -Uri "$Api/export?source=team-channels&format=csv&teamId=$teamId" -OutFile "team-channels.csv"
```

```bash
curl "$API/export?source=team-channels&format=csv&teamId=$teamId" -o team-channels.csv
```

Exemplo XLSX:

```powershell
Invoke-WebRequest -Method Get -Uri "$Api/export?source=users&format=xlsx" -OutFile "users.xlsx"
```

```bash
curl "$API/export?source=users&format=xlsx" -o users.xlsx
```

Postman:

- Method: GET
- URL: {{apiBase}}/export?source=users&format=xlsx
- Use Send and Download para salvar arquivo

Sources suportados:

- drive-files
- site-drives
- site-libraries
- team-channels
- team-channel-content
- team-channel-members
- groups
- users
- user-licenses
- item-permissions

## 11) Admin App Registration

### GET /api/v1/sharepoint/admin/app-registration

```powershell
Invoke-RestMethod -Method Get -Uri "$Api/admin/app-registration"
```

```bash
curl "$API/admin/app-registration"
```

Postman: GET {{apiBase}}/admin/app-registration

### POST /api/v1/sharepoint/admin/update-scopes

```powershell
$body = @{
  tenantId = 'a1c06ffc-77b3-4fb3-b57d-86eab41da4a2'
  clientId = '38f802d4-2d72-4f44-8a43-fbd371f8d34c'
  whatIf = $true
  execute = $false
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/admin/update-scopes" -ContentType 'application/json' -Body $body
```

```bash
curl -X POST "$API/admin/update-scopes" \
  -H "Content-Type: application/json" \
  -d '{"tenantId":"a1c06ffc-77b3-4fb3-b57d-86eab41da4a2","clientId":"38f802d4-2d72-4f44-8a43-fbd371f8d34c","whatIf":true,"execute":false}'
```

Postman: POST {{apiBase}}/admin/update-scopes

## Dicas de uso no Postman

1. Crie um Environment com baseUrl e apiBase.
2. Use variaveis de path para ids dinamicos.
3. Para requests com body, selecione Body -> raw -> JSON.
4. Para exportacao em arquivo, use Send and Download.
5. Para sequencias, crie uma Collection com pastas:
   - Config/Auth
   - Sites/Drives/Libraries
   - Files
   - Permissions
   - Groups/Users/Licenses
   - Teams
   - Export
   - Admin
