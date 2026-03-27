# Arquitetura e codigo

## Visao de arquitetura

O projeto esta dividido em tres camadas principais:

1. API Node.js/Express em api/
2. Frontend estatico em web/
3. Scripts operacionais em scripts/

Fluxo principal:

1. Requisicao chega nas rotas /api/v1/sharepoint/*
2. Controller valida entrada e aplica envelope de resposta
3. Service executa chamada ao Microsoft Graph
4. Resultado retorna ao controller para serializacao JSON/CSV/XLSX

## Backend API

### Bootstrap

- Arquivo: api/server.js
- Responsabilidades:
  - criar app Express em createApp
  - aplicar middleware de seguranca (helmet), CORS, logs e rate limiter
  - servir frontend em /web
  - publicar manifesto da API em /
  - registrar tratadores globais de 404 e erro com correlationId

### Rotas

- Arquivo: api/routes/sharepoint.routes.js
- Prefixo efetivo: /api/v1/sharepoint
- Grupos de rota:
  - autenticacao e config
  - sites, drives, bibliotecas, arquivos e pastas
  - grupos, usuarios e licencas
  - times/canais/membros
  - permissoes de item
  - exportacao
  - administracao de App Registration
  - governanca de import/export, status de operacoes e auditoria

### Controllers

- Arquivo: api/controllers/sharepointController.js
- Papel:
  - validacao de parametros obrigatorios
  - padronizacao do envelope de erro
  - transformacao para exportacao CSV/XLSX
  - orquestracao das chamadas para sharepointGraphService

- Arquivo: api/controllers/sharepointGovernanceController.js
- Papel:
  - expor contrato de pacote de exportacao para interoperabilidade
  - validar e gerar preview de importacao
  - iniciar importacoes assincronas com operationId
  - disponibilizar trilha tecnica de auditoria

Padrao de erro:

```json
{
  "success": false,
  "correlationId": "...",
  "error": {
    "code": "SP_400",
    "message": "Mensagem funcional"
  }
}
```

### Service Graph

- Arquivo: api/services/sharepointGraphService.js
- Papel:
  - autenticacao app-only com ClientCertificateCredential
  - cache de token e renovacao automatica
  - retry exponencial com backoff para 429 e 5xx
  - encapsulamento dos endpoints Graph por recurso

Recursos implementados:

- sites (list)
- drives (list/create/update)
- bibliotecas (list/create/update via list documentLibrary)
- arquivos e pastas
- grupos, usuarios e licencas
- canais Teams e membros
- permissoes de item

### Services de governanca operacional

- Arquivo: api/services/importExportService.js
- Papel:
  - normalizar contratos de importacao
  - validar modos de import (always, skip-if-exists, update, replace-safe)
  - gerar preview de importacao
  - padronizar contrato de pacote de exportacao

- Arquivo: api/services/operationsStoreService.js
- Papel:
  - persistir operacoes assincronas
  - gerenciar estados queued/running/succeeded/failed
  - fornecer consulta por operationId

- Arquivo: api/services/auditTrailService.js
- Papel:
  - persistir eventos tecnicos por acao
  - incluir correlationId e operationId na trilha
  - listar eventos com filtros e paginacao

### Administracao de escopos

- Arquivo: api/services/appRegistrationAdminService.js
- Papel:
  - montar preview do comando Update-GraphAppScopes.ps1
  - validar payload administrativo
  - executar script quando ENABLE_ADMIN_SCRIPT_EXECUTION=true

## Frontend estatico

### Estrutura

- web/index.html: status e autenticacao
- web/operations.html: operacoes SharePoint basicas
- web/collaboration.html: operacoes colaborativas, export e administracao funcional
- web/admin.html: configuracao de escopos da App Registration

### Padrao de integracao frontend

Todas as paginas usam:

- constante API com base /api/v1/sharepoint
- fetch com JSON
- atualizacao visual por output de resposta

Exemplo padrao:

```javascript
const API = '/api/v1/sharepoint';
const data = await fetch(`${API}/users`).then((res) => res.json());
```

## Testes

- api/test/sharepoint.routes.test.js:
  - cobertura de contratos de rota
  - stubs de service para validar comportamento de controller/route
- api/test/web.pages.test.js:
  - smoke tests das paginas web
- api/test/requirements.validation.test.js:
  - matriz de requisitos suportados e gaps
- api/test/sharepoint.governance.routes.test.js:
  - contratos de rotas de governanca e operacao assincrona

## Limites atuais de escopo

- Criacao/modificacao de sites SharePoint permanece fora do escopo estavel do Graph v1.0 neste projeto.
- Conteudo legado SCCM/Intune/Tenable permanece somente em backup/legacy-2026-03-12/.
