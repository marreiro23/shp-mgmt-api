# Sincronização Automática de Recursos

## Visão Geral

A aplicação `shp-mgmt-api` agora sincroniza automaticamente os dados do SharePoint, Teams e Entra ID para o PostgreSQL. Essa sincronização garante que os filtros da aplicação estejam sempre atualizados com os dados mais recentes do ambiente.

## Como Funciona

### 1. Sincronização Automática no Bootstrap

Quando o servidor inicia, o `resourceSyncService` é ativado automaticamente:

```
[server] Running initial resource sync...
[ResourceSyncService] Starting full sync run...
[ResourceSyncService] Syncing sites...
[ResourceSyncService] Syncing users...
[ResourceSyncService] Syncing groups...
[ResourceSyncService] Syncing teams...
```

A sincronização periódica é executada a cada 5 minutos (configurável via variável de ambiente `SYNC_INTERVAL_MS`).

### 2. Configuração

#### Intervalo de Sincronização

Para alterar o intervalo de sincronização, defina a variável de ambiente:

```bash
# Sincronizar a cada 10 minutos (em milissegundos)
export SYNC_INTERVAL_MS=600000
```

#### Banco de Dados

Os dados sincronizados são persistidos em tabelas PostgreSQL dedicadas:

- `shp.sharepoint_sites` - Sites SharePoint
- `shp.sharepoint_users` - Usuários do Entra ID
- `shp.sharepoint_groups` - Grupos M365
- `shp.sharepoint_teams` - Times Microsoft Teams
- `shp.sharepoint_drives` - Drives (bibliotecas)
- `shp.sharepoint_libraries` - Bibliotecas de documentos
- E muito mais...

### 3. Endpoints de Lista com Cache Local

Todos os endpoints de lista retornam dados do banco de dados local por padrão:

#### Sites
```
GET /api/v1/sharepoint/sites?search=*&top=25
```
Resposta:
```json
{
  "success": true,
  "count": 10,
  "data": [...],
  "dataSource": "local-db"
}
```

#### Usuários
```
GET /api/v1/sharepoint/users?search=&top=25
```

#### Grupos
```
GET /api/v1/sharepoint/groups?search=&top=25
```

#### Times (NOVO)
```
GET /api/v1/sharepoint/teams?search=&top=25
```

#### Forçar Sincronização via Graph API

Para ignorar o cache local e buscar dados frescos do Graph API:

```
GET /api/v1/sharepoint/sites?refresh=true
GET /api/v1/sharepoint/users?refresh=true&search=john
```

Resposta com dado atualizado:
```json
{
  "success": true,
  "count": 10,
  "data": [...],
  "dataSource": "graph"
}
```

## Endpoints de Sincronização Manual

### 1. Status da Sincronização

```http
GET /api/v1/sharepoint/sync/status
```

Resposta:
```json
{
  "success": true,
  "sync": {
    "running": true,
    "lastSyncAt": "2026-03-27T10:15:30.123Z",
    "intervalMs": 300000
  }
}
```

### 2. Sincronização Completa

Sincroniza sites, usuários, grupos e times:

```http
POST /api/v1/sharepoint/sync/run-full
```

Resposta:
```json
{
  "success": true,
  "message": "Sincronização completa iniciada.",
  "syncStartedAt": "2026-03-27T10:15:30.123Z"
}
```

### 3. Sincronizar Recursos Específicos

#### Apenas Sites
```http
POST /api/v1/sharepoint/sync/run-sites
```

#### Apenas Usuários
```http
POST /api/v1/sharepoint/sync/run-users
```

#### Apenas Grupos
```http
POST /api/v1/sharepoint/sync/run-groups
```

#### Apenas Times
```http
POST /api/v1/sharepoint/sync/run-teams
```

#### Drives e Bibliotecas (para todos os sites)
```http
POST /api/v1/sharepoint/sync/run-drives-and-libraries
```

## Integração no Frontend

### Função de Inicialização na Aplicação

O frontend agora carrega os dados do banco de dados automaticamente no startup:

```javascript
async function initializeDataCache() {
  // Executa todas as funções populate em paralelo
  await Promise.all([
    populateSites(),
    populateGroups(),
    populateUsers(),
    populateTeams()
  ]);
  
  // Selects e filtros estão agora preenchidos
}

// Chamada automática no bootstrap
bootstrap();
```

### Buscar Dados Mais Recentes

Cada função `populate*` tem um parâmetro de atualização:

```javascript
// Buscar do BD local (padrão)
await populateSites();

// Forçar sincronização com Graph API
await populateSites({ refresh: true });
```

### Cascade de Campos

Quando a seleção em um campo muda, campos dependentes são populados automaticamente:

```javascript
// Quando seleciona um site
expSiteId.addEventListener('change', async () => {
  await populateDrivesForExport(siteId);
});

// Quando seleciona um time
expTeamId.addEventListener('change', async () => {
  await populateChannelsForExport(teamId);
});

// Quando seleciona um drive
spDriveId.addEventListener('change', async () => {
  await populateItemsInDrive(driveId);
});
```

## Arquitetura de Sincronização

### resourceSyncService.js (Serviço de Sincronização)

Responsabilidades:
- Executar sincronização periódica
- Coordenar sincronização de sites, usuários, grupos, times
- Rastrear tempo da última sincronização
- Gerenciar start/stop do serviço

Métodos principais:
- `start()` - Iniciar sincronização periódica
- `stop()` - Parar sincronização
- `runFullSync()` - Executar sincronização completa
- `syncSites()`, `syncUsers()`, `syncGroups()`, `syncTeams()` - Sincronizar recursos específicos
- `syncAllDrivesAndLibraries()` - Sincronizar drives e bibliotecas para todos os sites

### sharepointGraphService.js (Acesso ao Graph API)

Novos métodos:
- `listTeams(search, top)` - Buscar teams do Graph API

### resourcePersistenceService.js (Persistência no BD)

Novos métodos:
- `upsertTeams(teams)` - Inserir/atualizar times na tabela `shp.sharepoint_teams`

### resourceQueryService.js (Query do BD Local)

Novos métodos:
- `listTeams({ search, top })` - Buscar times do BD local

## Fluxo de Sincronização

```
┌─────────────────────────────────────────────────────────────┐
│                   APP INICIA                                │
├─────────────────────────────────────────────────────────────┤
│  1. pgService.initialize()                                  │
│  2. resourceSyncService.start()                             │
│  3. runFullSync() (imediato)                                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  PRIMEIRA SINCRONIZAÇÃO                      │
├─────────────────────────────────────────────────────────────┤
│  sharePointGraphService.listSites()     ─────→ BD SYNC      │
│  sharePointGraphService.listUsers()     ─────→ BD SYNC      │
│  sharePointGraphService.listGroups()    ─────→ BD SYNC      │
│  sharePointGraphService.listTeams()     ─────→ BD SYNC      │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│              FILTROS ATUALIZADOS NO FRONTEND               │
├─────────────────────────────────────────────────────────────┤
│  initializeDataCache() executa:                             │
│  - populateSites()   (busca do BD local)                    │
│  - populateUsers()   (busca do BD local)                    │
│  - populateGroups()  (busca do BD local)                    │
│  - populateTeams()   (busca do BD local)                    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│         SINCRONIZAÇÃO PERIÓDICA (A CADA 5 MIN)             │
├─────────────────────────────────────────────────────────────┤
│  runFullSync() a cada SYNC_INTERVAL_MS milissegundos        │
│  (Atualiza BD com dados mais recentes)                      │
└─────────────────────────────────────────────────────────────┘
```

## Escalabilidade e Performance

### Otimizações

1. **Cache Local**: Dados são lidos do PostgreSQL (muito mais rápido que Graph API)
2. **Sincronização Assíncrona**: Não bloqueia requisições HTTP
3. **Sincronização Paralela**: Sites, usuários, grupos, times sincronizam em paralelo
4. **Intervalo Configurável**: Pode ser ajustado conforme necessário

### Estimativas de Performance

- **Primeira Sincronização**: ~30-60 segundos (depende do tamanho do tenant)
- **Sincronizações Subsequentes**: ~10-30 segundos
- **Resposta de Endpoint com Cache**: <100ms
- **Resposta de Endpoint com Graph**: ~2-5 segundos

## Troubleshooting

### Sincronização não está acontecendo

1. Verificar logs:
```bash
curl http://localhost:3001/api/v1/sharepoint/sync/status
```

2. Verificar se pgService está disponível:
```bash
curl http://localhost:3001/health
```

3. Verificar permissões de Graph API (necessária delegated permission para listar recursos)

### Dados não estão sendo sincronizados

1. Verificar se há dados no BD:
```sql
SELECT COUNT(*) FROM shp.sharepoint_sites;
SELECT * FROM shp.sharepoint_sites LIMIT 5;
```

2. Forçar sincronização manual:
```bash
curl -X POST http://localhost:3001/api/v1/sharepoint/sync/run-full
```

3. Verificar logs do servidor para erros de Graph API

### Filtros não estão sendo populados

1. Verificar se `initializeDataCache()` foi executada:
```javascript
// No console do browser
initializeDataCache();
```

2. Verificar se há dados no BD:
```bash
curl http://localhost:3001/api/v1/sharepoint/users
```

3. Verificar cors e headers de requisição

## Próximas Melhorias

- [ ] Dashboard de sincronização em tempo real
- [ ] Webhook para sincronizar imediatamente quando novos recursos são criados
- [ ] Compressão de dados históricos
- [ ] Alertas para falhas de sincronização
- [ ] Metadados de sincronização (tempo de execução, recursos processados, etc)
