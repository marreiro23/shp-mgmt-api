# shp-mgmt-api

Aplicacao de gestao operacional para SharePoint Online e Microsoft Graph,
com foco em evolucao incremental, API-first, rastreabilidade tecnica e
automacao segura de tarefas administrativas.

## Objetivo do projeto

Este repositorio concentra uma API Node.js/Express para operacoes de
administracao em SharePoint, mantendo contratos existentes e adicionando
recursos de governanca em ciclos curtos.

Principais objetivos:

- manter compatibilidade dos endpoints legados
- ampliar cobertura funcional para operacoes de alto valor
- padronizar importacao, comparacao e exportacao para produtividade operacional
- reforcar seguranca, resiliencia e observabilidade

## Features implementadas

### Core SharePoint + Graph

- autenticacao app-only por certificado
- inventario de sites, bibliotecas, drives e conteudo
- criacao/atualizacao de bibliotecas e drives
- operacoes de pasta/arquivo (create, upload, rename, delete)
- gestao de permissoes por item

### Colaboracao e identidade

- grupos Entra ID (list/create/update/member add/remove)
- usuarios (list/update)
- licencas (list/assign)
- Teams (canais, membros e conteudo)

### Governanca operacional

- preview e execucao de importacao administrativa
- preview e execucao de comparacao (diff de estado)
- operacoes assincronas com operationId
- trilha tecnica de auditoria por acao
- exportacao de resultado de compare em json/csv/xlsx

### Exportacao

- endpoint de exportacao operacional para multiplas fontes
- formatos suportados: json, csv e xlsx
- contrato de pacote de exportacao para interoperabilidade entre tenants

## Arquitetura resumida

```text
.
├── api/
│   ├── controllers/
│   │   ├── sharepointController.js
│   │   ├── sharepointAdminController.js
│   │   └── sharepointGovernanceController.js
│   ├── routes/sharepoint.routes.js
│   ├── services/
│   │   ├── sharepointGraphService.js
│   │   ├── importExportService.js
│   │   ├── compareService.js
│   │   ├── operationsStoreService.js
│   │   └── auditTrailService.js
│   └── test/
├── docs/
├── scripts/
├── web/
└── backup/legacy-2026-03-12/
```

## Requisitos

- Node.js 20.x
- PowerShell 7+ (ou Windows PowerShell 5.1 para scripts legados)
- App Registration com permissoes Graph para SharePoint
- certificado PEM com chave privada e certificado publico
- variaveis de ambiente minimas:
  - TENANT_ID
  - CLIENT_ID
  - CERT_THUMBPRINT
  - CERT_PRIVATE_KEY_PATH

## Como executar

```bash
cd api
npm install
npm run start:lts
```

Testes:

```bash
npm run test:lts
```

## Interface web

- entrada padrao: `/web/operations-center.html`
- entrada legada: `/web/index.html?legacy=1`
- modulo legado de operacoes: `/web/operations.html`
- modulo legado de colaboracao: `/web/collaboration.html`
- modulo legado administrativo: `/web/admin.html`

Observacao: `/web/index.html` redireciona automaticamente para o Operations
Center quando chamado sem `?legacy=1`.

## Endpoints de referencia

- GET /health
- GET /api/v1/config
- GET /api/v1/sharepoint/config
- GET /api/v1/sharepoint/sites
- GET /api/v1/sharepoint/export
- POST /api/v1/sharepoint/admin-governance/import/preview
- POST /api/v1/sharepoint/admin-governance/import/execute
- POST /api/v1/sharepoint/admin-governance/compare/preview
- POST /api/v1/sharepoint/admin-governance/compare/execute
- GET /api/v1/sharepoint/admin-governance/compare/export
- GET /api/v1/sharepoint/operations/:operationId
- GET /api/v1/sharepoint/audit/events

## Scripts operacionais

No diretorio scripts/ estao os utilitarios para validacao e operacao do
ambiente SharePoint/Graph, incluindo setup, testes de endpoints e update de
escopos da App Registration.

Tambem estao disponiveis scripts de automacao Git para bootstrap local,
criacao de branch e validacao de sincronismo da branch main.

## Escopo e limites

- o fluxo principal nao inclui modulos SCCM, GPO, Autopilot, Intune ou Tenable
- conteudo historico permanece isolado em backup/legacy-2026-03-12/
- criacao/modificacao de sites SharePoint permanece fora do escopo estavel

## Documentacao

Consulte docs/ no modelo Diataxis:

- tutorials: onboarding e primeiros passos
- how-to: tarefas operacionais praticas
- reference: contratos, arquitetura, dependencias e endpoints
- explanation: decisoes de design e trade-offs

Documentacao adicional de banco:

- tutorial de onboarding PostgreSQL
- guia operacional de manutencao e expansao
- referencia de schema e indices recomendados
- explicacao da escolha arquitetural do PostgreSQL
