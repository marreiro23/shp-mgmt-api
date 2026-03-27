# Teste da API

Guia completo para testar a API shp-mgmt-api com diferentes ferramentas e scripts.

## Índice

1. [Test Suite Node.js](#test-suite-nodejs)
2. [Shell Script Bash](#shell-script-bash) 
3. [Postman Collection](#postman-collection)
4. [Testes Manuais com cURL](#testes-manuais-com-curl)
5. [Validação de Endpoints](#validação-de-endpoints)

---

## Test Suite Node.js

### Descrição

Script Node.js que testa automaticamente todos os endpoints principais da API com validação de respostas HTTP.

**Arquivo**: `scripts/api-test-suite.js`

### Uso

#### Pré-requisitos

- Node.js instalado
- Servidor da API rodando (`npm start`)

#### Executar Testes

```bash
# Rodar teste simples (faz requests a localhost:3001)
node scripts/api-test-suite.js

# Ou em outro formato (se implementado):
npm test
```

#### Recurso de Testes

O script testa automaticamente:

- ✅ Health Check (`GET /health`)
- ✅ Configuração da API (`GET /config`)
- ✅ Listagem de Sites (`GET /sites`)
- ✅ Listagem de Grupos (`GET /groups`)
- ✅ Listagem de Usuários (`GET /users`)
- ✅ Listagem de Teams (`GET /teams`)
- ✅ Status de Sincronização (`GET /sync/status`)
- ✅ Drives (se sites existem)
- ✅ Bibliotecas
- ✅ Registros do Banco de Dados
- ✅ Auditoria

#### Interpretação de Saída

```
[PASS] Health Check (HTTP 200) ✓
[PASS] List Sites (HTTP 200) ✓
[FAIL] Create Root Site (Expected 201, got 400) ✗
  Response: {"success":false,"error":{"code":"..."}}

═══════════════════════════════════════════
Test Summary
Passed: 42
Failed: 2
Success Rate: 95%
═══════════════════════════════════════════
```

**Cores de Saída**:
- 🟢 Verde = Teste passou
- 🔴 Vermelho = Teste falhou  
- 🟡 Amarelo = Seção/Header

---

## Shell Script Bash

### Descrição

Script bash que facilita testes via cURL com suporte a diferentes operações de forma modular.

**Arquivo**: `scripts/api-tests.sh`

### Uso

#### Pré-requisitos

- Bash/Shell (Linux, macOS, ou Windows com Git Bash/WSL)
- `curl` instalado
- Servidor da API rodando

#### Sintaxe

```bash
bash api-tests.sh [API_URL] [OPERATION]
```

#### Parâmetros

- `[API_URL]` (opcional): URL base da API (padrão: `http://localhost:3001`)
- `[OPERATION]` (opcional): Tipo de operação a executar (padrão: `all`)

#### Operações Disponíveis

```bash
# Testes de saúde
bash api-tests.sh                           # Tudo (padrão)
bash api-tests.sh http://localhost:3001 health

# Testes de recursos
bash api-tests.sh http://localhost:3001 sites
bash api-tests.sh http://localhost:3001 groups
bash api-tests.sh http://localhost:3001 users
bash api-tests.sh http://localhost:3001 teams
bash api-tests.sh http://localhost:3001 sync
bash api-tests.sh http://localhost:3001 db

# Testes de criação de sites
bash api-tests.sh http://localhost:3001 create-root-site
bash api-tests.sh http://localhost:3001 clone-site
bash api-tests.sh http://localhost:3001 create-subsite

# URL diferente
bash api-tests.sh http://api.example.com:3001 sites
```

#### Exemplos de Saída

```bash
$ bash api-tests.sh

═══════════════════════════════════════════════════════════════
1. Health & Configuration Tests
═══════════════════════════════════════════════════════════════
[TEST] GET /health
[PASS] Health Check (HTTP 200)
  Response: {"status":"ok","message":"API is running"}

[TEST] GET /config
[PASS] API Config (HTTP 200)
  Response: {"success":true,"data":{"authMode":"appOnly",...

═══════════════════════════════════════════════════════════════
Test Summary
Passed: 15
Failed: 0
Success Rate: 100%
═══════════════════════════════════════════════════════════════
```

#### Variáveis de Ambiente

```bash
# Usar URL customizada via variável
export API_URL="http://api.example.com:3001"
bash api-tests.sh $API_URL health
```

---

## Postman Collection

### Descrição

Coleção JSON pré-configurada com todos os endpoints da API, pronta para importar no Postman ou Insomnia.

**Arquivo**: `postman-collection.json`

### Uso

#### Importar no Postman

1. Abrir Postman
2. Clicar em **Import** (no canto superior esquerdo)
3. Selecionar **Upload Files**
4. Escolher `postman-collection.json`
5. Clicar em **Import**

#### Configurar Variáveis

Após importar, configurar as variáveis do ambiente:

1. Clicar na aba **Environments** ou nas variáveis da coleção
2. Atualizar:
   - `base_url`: `http://localhost:3001` (ou seu servidor)
   - `api_url`: `http://localhost:3001/api/v1/sharepoint`
   - `parent_site_id`: ID real do seu site SharePoint (opcional)

#### Estrutura da Coleção

```
📦 SharePoint Management API
├── 📁 Health & Config
│   ├── Health Check
│   └── API Config
├── 📁 SharePoint Sites
│   ├── List Sites
│   ├── Search Sites
│   └── List Teams
├── 📁 Create Sites
│   ├── Create Subsite
│   ├── Create Root Site (Global Marketing)
│   ├── Create Root Site (Team Site)
│   ├── Clone Existing Site
│   └── Clone as Subsite
├── 📁 Microsoft 365 Groups
├── 📁 Entra ID Users
├── 📁 Synchronization
░   ├── Get Sync Status
│   ├── Run Full Sync
│   ├── Sync Sites Only
│   ├── Sync Users Only
│   ├── Sync Groups Only
│   └── Sync Teams Only
├── 📁 Database Records
│   ├── Get DB Sites
│   ├── Get DB Users
│   ├── Get DB Groups
│   ├── Get DB Teams
│   └── Get DB Drives
└── 📁 Audit & Activity
    ├── Get Audit Trail
    └── Get Command History
```

#### Executar Testes

1. Selecionar uma pasta (ex: "Health & Config")
2. Clicar em **Run** ou usar Postman Runner
3. Verificar resultados (status code, tempo de resposta, validações)

#### Recursos Especiais

- **Timestamps**: Use `{{$timestamp}}` para criar nomes únicos
- **Variáveis**: Todos os campos de URL usam `{{variable}}` para substituição
- **Descrições**: Cada endpoint tem descrição detalhada do que testador

---

## Testes Manuais com cURL

### Listagem de Sites

```bash
curl -X GET "http://localhost:3001/api/v1/sharepoint/sites" \
  -H "Content-Type: application/json"
```

### Criar Subsite

```bash
curl -X POST "http://localhost:3001/api/v1/sharepoint/sites/{parentSiteId}/sites" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "Novo Subsite",
    "name": "novo-subsite",
    "description": "Criado via cURL",
    "createType": "subsite"
  }'
```

### Criar Site de Nível Root

```bash
curl -X POST "http://localhost:3001/api/v1/sharepoint/sites/unused/sites" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "Global Marketing",
    "name": "gm-root",
    "description": "Site raiz para marketing global",
    "createType": "root",
    "template": "STS#3"
  }'
```

### Clonar Site Existente

```bash
curl -X POST "http://localhost:3001/api/v1/sharepoint/sites/unused/sites" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "Marketing Clone",
    "name": "marketing-clone",
    "createType": "clone",
    "cloneFromSiteId": "example.sharepoint.com,00000000-0000-0000-0000-000000000000,00000000-0000-0000-0000-000000000000"
  }'
```

### Verificar Status de Sincronização

```bash
curl -X GET "http://localhost:3001/api/v1/sharepoint/sync/status" \
  -H "Content-Type: application/json"
```

### Rodar Sincronização Manual

```bash
curl -X POST "http://localhost:3001/api/v1/sharepoint/sync/run-full" \
  -H "Content-Type: application/json"
```

---

## Validação de Endpoints

### Checklist de Testes

- [ ] **Health & Config**
  - [ ] GET /health → 200
  - [ ] GET /config → 200

- [ ] **Listagem de Recursos**
  - [ ] GET /sites → 200
  - [ ] GET /groups → 200
  - [ ] GET /users → 200
  - [ ] GET /teams → 200

- [ ] **Sincronização**
  - [ ] GET /sync/status → 200
  - [ ] POST /sync/run-full → 202 ou sucesso
  - [ ] POST /sync/run-sites → 202 ou sucesso

- [ ] **Criação de Sites** (requer permissões admin)
  - [ ] POST /sites/{parentId}/sites (subsite) → 201
  - [ ] POST /sites/unused/sites (root) → 201
  - [ ] POST /sites/unused/sites (clone) → 201

- [ ] **Banco de Dados**
  - [ ] GET /database/records?table=sharepoint_sites → 200
  - [ ] GET /database/records?table=sharepoint_users → 200
  - [ ] GET /database/records?table=sharepoint_teams → 200

### Interpretação de Códigos HTTP

| Código | Significado | Ação |
| --- | --- | --- |
| 200 | OK | ✅ Teste passou |
| 201 | Created | ✅ Recurso criado com sucesso |
| 202 | Accepted | ✅ Operação assíncrona iniciada |
| 400 | Bad Request | ❌ Verifique parâmetros |
| 401 | Unauthorized | ❌ Verifique autenticação |
| 403 | Forbidden | ❌ Sem permissão (requer admin) |
| 404 | Not Found | ❌ Recurso não existe |
| 500 | Server Error | ❌ Erro no servidor |

---

## Troubleshooting

### "Connection refused"

```bash
# Verificar se servidor está rodando
curl http://localhost:3001/health

# Se não responder, iniciar servidor
npm start
```

### "Invalid SiteId"

Ao criar subsite, o `parentSiteId` deve ser um ID válido do SharePoint:

```
Formato válido: "example.sharepoint.com,xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx,xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Criação de Root Site Falha

Requer:
- ✅ Conta com permissões de admin de tenant
- ✅ Credenciais corretas no `.env`
- ✅ Scopes necessários configurados no App Registration

### Testes de Clonagem Falham

Verificar:
- ✅ `cloneFromSiteId` é um site existente
- ✅ Acesso à leitura do site de origem
- ✅ Permissões para criar novo site

---

## Próximos Passos

1. ✅ Executar `scripts/api-test-suite.js` para validação rápida
2. ✅ Usar `scripts/api-tests.sh` para testes modulares
3. ✅ Importar `postman-collection.json` no Postman para testes visuais
4. ✅ Consultar [docs/reference/endpoints.md](./reference/endpoints.md) para detalhes de cada endpoint
5. ✅ Revisar [docs/SYNC.md](./SYNC.md) para sincronização de recursos

