# Endpoints da API

Referencia completa dos endpoints ativos em /api/v1/sharepoint.

## Convencoes de resposta

- Sucesso: success=true
- Erro: success=false com error.code, error.message e correlationId
- Export: resposta com attachment (json, csv ou xlsx)

## Base URL local

- API: [http://localhost:3001/api/v1/sharepoint](http://localhost:3001/api/v1/sharepoint)

## Configuracao e autenticacao

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /config | Estado de configuracao e autenticacao Graph |
| POST | /authenticate | Forca autenticacao app-only com certificado |

## Sites, bibliotecas e drives

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /sites | Lista sites por busca |
| GET | /teams | Lista times (origem: Microsoft Teams) |
| POST | /sites/:parentSiteId/sites | Cria site (subsite, root, ou por clonagem) |
| GET | /sites/:siteId/drives | Lista drives do site |
| POST | /sites/:siteId/drives | Cria drive (provisiona documentLibrary) |
| GET | /sites/:siteId/libraries | Lista bibliotecas do site |
| POST | /sites/:siteId/libraries | Cria biblioteca |
| PATCH | /sites/:siteId/libraries/:listId | Atualiza biblioteca |
| PATCH | /drives/:driveId | Atualiza drive |

### Criacao de Sites

O endpoint `POST /sites/:parentSiteId/sites` suporta tres modos de criacao via parametro `createType`:

#### 1. Criar Subsite (padrão)

Cria um site subordinado dentro de um site pai existente.

```http
POST /api/v1/sharepoint/sites/{parentSiteId}/sites
Content-Type: application/json

{
  "displayName": "Subsite de Projetos",
  "name": "projetos",
  "description": "Subsite para gestao de projetos",
  "createType": "subsite",
  "template": "STS#3"
}
```

Parametros:
- `createType`: "subsite" (obrigatorio neste modo)
- `displayName`: Nome do site (obrigatorio)
- `name`: Identificador unico/URL (obrigatorio)
- `template`: Template do site (opcional, padrao: STS#3 para Team Site)
- `description`: Descricao (opcional)

Nota: O `parentSiteId` e obrigatorio na rota.

#### 2. Criar Site de Nivel Root

Cria um site independente de nivel raiz (nao um subsite). Exemplo: "Global Marketing".

```http
POST /api/v1/sharepoint/sites/unused-param/sites
Content-Type: application/json

{
  "displayName": "Global Marketing",
  "name": "gm-root",
  "description": "Site raiz para marketing global",
  "createType": "root",
  "template": "STS#3"
}
```

Parametros:
- `createType`: "root" (obrigatorio neste modo)
- `displayName`: Nome do site (obrigatorio)
- `name`: Identificador unico (obrigatorio)
- `template`: Template do site (STS#3 para Team Site, STS#0 para blank)
- `description`: Descricao (opcional)
- `parentSiteId`: Sera ignorado neste modo (use "unused-param" na rota)

Nota: A criacao de sites root requer permissoes elevadas de administrador.

#### 3. Clonar Site Existente

Copia a estrutura e template de um site existente.

```http
POST /api/v1/sharepoint/sites/unused-param/sites
Content-Type: application/json

{
  "displayName": "Marketing Clone",
  "name": "marketing-clone",
  "description": "Clone of existing marketing site",
  "createType": "clone",
  "cloneFromSiteId": "example.sharepoint.com,00000000-0000-0000-0000-000000000000,00000000-0000-0000-0000-000000000000"
}
```

Parametros:
- `createType`: "clone" (obrigatorio neste modo)
- `displayName`: Nome do novo site (obrigatorio)
- `name`: Identificador unico (obrigatorio)
- `cloneFromSiteId`: ID do site a ser clonado (obrigatorio)
- `parentSiteId`: Para criar como subsite em um site pai (opcional)
- `description`: Descricao (opcional, incluira referencia ao site de origem)

#### 4. Clonar como Subsite

Combina clonagem com criacao de subsite.

```http
POST /api/v1/sharepoint/sites/{parentSiteId}/sites
Content-Type: application/json

{
  "displayName": "Sales Clone",
  "name": "sales-clone",
  "description": "Clone of sales site under parent",
  "createType": "clone",
  "cloneFromSiteId": "example.sharepoint.com,..."
}
```

Parametros:
- `createType`: "clone"
- `cloneFromSiteId`: ID do site a ser clonado
- `parentSiteId`: Fornecido na rota (requere o site a ser criado como subsite)

Exemplo de criacao de biblioteca:

```http
POST /api/v1/sharepoint/sites/{siteId}/libraries
Content-Type: application/json

{
  "displayName": "Contratos 2026",
  "description": "Biblioteca documental"
}
```

Exemplo de atualizacao de drive:

```http
PATCH /api/v1/sharepoint/drives/{driveId}
Content-Type: application/json

{
  "name": "Drive Operacional",
  "description": "Descricao atualizada"
}
```

## Arquivos, pastas e itens

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /drives/:driveId/children | Lista itens de uma pasta |
| GET | /drives/:driveId/files-metadata | Lista metadados de arquivos |
| POST | /drives/:driveId/folders | Cria pasta |
| POST | /drives/:driveId/files | Upload de arquivo texto |
| PATCH | /drives/:driveId/items/:itemId | Renomeia item |
| DELETE | /drives/:driveId/items/:itemId | Remove item |

Exemplo de upload:

```http
POST /api/v1/sharepoint/drives/{driveId}/files
Content-Type: application/json

{
  "fileName": "nota.txt",
  "parentPath": "Documentos/Relatorios",
  "content": "conteudo do arquivo"
}
```

## Permissoes de item

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /drives/:driveId/items/:itemId/permissions | Lista permissoes do item |
| POST | /drives/:driveId/items/:itemId/permissions | Cria permissao via invite |
| DELETE | /drives/:driveId/items/:itemId/permissions/:permissionId | Remove permissao |

Exemplo de concessao:

```http
POST /api/v1/sharepoint/drives/{driveId}/items/{itemId}/permissions
Content-Type: application/json

{
  "recipients": [{ "email": "user@example.com" }],
  "roles": ["write"],
  "message": "Acesso concedido"
}
```

## Grupos, usuarios e licencas

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /groups | Lista grupos Entra ID |
| POST | /groups | Cria grupo |
| PATCH | /groups/:groupId | Atualiza grupo |
| POST | /groups/:groupId/members | Adiciona membro no grupo |
| DELETE | /groups/:groupId/members/:memberObjectId | Remove membro do grupo |
| GET | /users | Lista usuarios |
| PATCH | /users/:userId | Atualiza usuario |
| GET | /users/:userId/licenses | Lista licencas |
| POST | /users/:userId/licenses | Atribui/remove licencas |

Exemplo de atribuicao de licenca:

```http
POST /api/v1/sharepoint/users/{userId}/licenses
Content-Type: application/json

{
  "addLicenses": [{ "skuId": "00000000-0000-0000-0000-000000000000" }],
  "removeLicenses": []
}
```

## Teams e colaboracao

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /teams/:teamId/channels | Lista canais do time |
| POST | /teams/:teamId/channels | Cria canal |
| PATCH | /teams/:teamId/channels/:channelId | Atualiza canal |
| GET | /teams/:teamId/channels/:channelId/members | Lista membros do canal |
| POST | /teams/:teamId/channels/:channelId/members | Adiciona membro no canal |
| DELETE | /teams/:teamId/channels/:channelId/members/:membershipId | Remove membro do canal |
| GET | /teams/:teamId/channels/:channelId/content | Lista mensagens e arquivos do canal |

## Sincronizacao e Recursos

A API sincroniza periodicamente (a cada 5 minutos por padrao) os seguintes recursos com o banco de dados PostgreSQL:
- SharePoint Sites
- Usuarios Entra ID
- Grupos Microsoft 365
- Teams
- Drives e Bibliotecas

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /sync/status | Obtém status da sincronização (ultima execucao, proxima execucao, erros) |
| POST | /sync/run-full | Executa sincronizacao completa sob demanda |
| POST | /sync/run-sites | Sincroniza apenas sites |
| POST | /sync/run-users | Sincroniza apenas usuarios |
| POST | /sync/run-groups | Sincroniza apenas grupos |
| POST | /sync/run-teams | Sincroniza apenas teams |
| POST | /sync/run-drives-and-libraries | Sincroniza drives e bibliotecas |

Exemplo de obtencao de status:

```http
GET /api/v1/sharepoint/sync/status
```

Resposta esperada:

```json
{
  "success": true,
  "data": {
    "isRunning": false,
    "lastSync": "2024-01-15T10:30:45.123Z",
    "nextSync": "2024-01-15T10:35:45.123Z",
    "syncInterval": 300000,
    "lastError": null,
    "resourceStats": {
      "sites": 42,
      "users": 156,
      "groups": 23,
      "teams": 8
    }
  }
}
```

Exemplo de execucao de sincronizacao sob demanda:

```http
POST /api/v1/sharepoint/sync/run-full
Content-Type: application/json
```

Nota: A sincronizacao comeca automaticamente durante o startup do servidor e continua a cada intervalo configurado.

## Auditoria e Recursos do Banco de Dados

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /database/records | Obtem registros do banco de dados (postgresql) |
| GET | /audit/trail | Obtém trilha de operacoes |


Endpoint:

- GET /export

Parametros:

- format: json, csv, xlsx
- source:
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

Exemplo:

```http
GET /api/v1/sharepoint/export?source=users&format=xlsx
```

## Administracao de App Registration

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /admin/app-registration | Metadados e permissoes recomendadas |
| POST | /admin/update-scopes | Preview/execucao de update de escopos |

## Governanca, operacoes e auditoria

| Metodo | Endpoint | Descricao |
| --- | --- | --- |
| GET | /admin-governance/export/package | Contrato de pacote de exportacao (manifest/dependency-map/identity-map) |
| POST | /admin-governance/import/preview | Preview de importacao com validacao e plano de execucao |
| POST | /admin-governance/import/execute | Inicia importacao assincrona e retorna operationId |
| POST | /admin-governance/compare/preview | Preview de comparacao entre pacote e estado atual |
| POST | /admin-governance/compare/execute | Inicia comparacao assincrona e retorna operationId |
| GET | /admin-governance/compare/export | Exporta diff de comparacao por operationId (json/csv/xlsx) |
| GET | /operations/:operationId | Consulta status de operacao assincrona |
| GET | /audit/events | Lista trilha tecnica de auditoria com filtros e paginacao |

Exemplo de preview de importacao:

```http
POST /api/v1/sharepoint/admin-governance/import/preview
Content-Type: application/json

{
  "mode": "update",
  "sourceTenant": "contoso-source",
  "targetTenant": "contoso-target",
  "dryRun": true,
  "objects": [
    { "type": "library", "id": "lib-01", "name": "Contratos" }
  ]
}
```

Exemplo de execucao assincrona:

```http
POST /api/v1/sharepoint/admin-governance/import/execute
Content-Type: application/json

{
  "mode": "always",
  "dryRun": false,
  "objects": [
    { "type": "folder-policy", "id": "fp-01", "name": "PadraoPastas" }
  ]
}
```

Contrato do engine de import (fase atual):

- `mode`: `always`, `skip-if-exists`, `update`, `replace-safe`
- `objects[].type`: `library`, `folder`, `permission`
- Ordem de execucao por dependencia: `library` -> `folder` -> `permission`
- Requisitos minimos por tipo:
  - `library`: `siteId`, `name`
  - `folder`: `driveId`, `name` (opcional `parentPath`)
  - `permission`: `driveId`, `itemId`, `recipients[]`

Contrato do engine de compare (fase atual):

- `objects[].type`: `library`, `folder`, `permission`
- `includeUnchanged`: controla retorno de itens `equal`
- ordem de comparacao por dependencia: `library` -> `folder` -> `permission`
- status por item: `equal`, `different`, `missing`

## Mapeamento frontend para endpoints

Arquivo frontend principal: web/collaboration.html

| Botao (id) | Endpoint chamado |
| --- | --- |
| btnAuthenticate | POST /authenticate |
| btnListLibraries | GET /sites/:siteId/libraries |
| btnCreateLibrary | POST /sites/:siteId/libraries |
| btnUpdateLibrary | PATCH /sites/:siteId/libraries/:listId |
| btnCreateDrive | POST /sites/:siteId/drives |
| btnUpdateDrive | PATCH /drives/:driveId |
| btnFilesMetadata | GET /drives/:driveId/files-metadata |
| btnListChannels | GET /teams/:teamId/channels |
| btnListChannelMembers | GET /teams/:teamId/channels/:channelId/members |
| btnChannelContent | GET /teams/:teamId/channels/:channelId/content |
| btnAddChannelMember | POST /teams/:teamId/channels/:channelId/members |
| btnRemoveChannelMember | DELETE /teams/:teamId/channels/:channelId/members/:membershipId |
| btnListGroups | GET /groups |
| btnCreateGroup | POST /groups |
| btnUpdateGroup | PATCH /groups/:groupId |
| btnAddGroupMember | POST /groups/:groupId/members |
| btnRemoveGroupMember | DELETE /groups/:groupId/members/:memberObjectId |
| btnListUsers | GET /users |
| btnUpdateUser | PATCH /users/:userId |
| btnListUserLicenses | GET /users/:userId/licenses |
| btnAssignUserLicenses | POST /users/:userId/licenses |
| btnListItemPermissions | GET /drives/:driveId/items/:itemId/permissions |
| btnCreateItemPermission | POST /drives/:driveId/items/:itemId/permissions |
| btnDeleteItemPermission | DELETE /drives/:driveId/items/:itemId/permissions/:permissionId |
| btnExport | GET /export |
| btnPreviewExport | GET /export (format=json) |
