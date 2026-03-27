## Services ativos

Este diretorio concentra os servicos de dominio e infraestrutura usados pela
API SharePoint.

## Mapa de servicos

### sharepointGraphService.js

Camada de acesso ao Microsoft Graph para recursos SharePoint, Teams e Entra.

Capacidades:

- autenticacao app-only via ClientCertificateCredential
- validacao de certificado por thumbprint
- cache de token com renovacao automatica
- retry com backoff para 429 e 5xx
- operacoes de sites, bibliotecas, drives, itens, permissoes, grupos, usuarios,
  licencas e canais Teams

### inventoryDbService.js

Persistencia local de inventario para apoio operacional e diagnostico.

Capacidades:

- registro incremental de sites, drives, bibliotecas e arquivos
- base local em JSON sob api/data/inventory
- funcoes de consulta para endpoint de inventario

### appRegistrationAdminService.js

Servico administrativo para gerenciamento assistido de escopos da App
Registration.

Capacidades:

- validacao de payload administrativo
- preview do comando PowerShell
- execucao protegida por feature/flag de ambiente

### importExportService.js

Engine de importacao administrativa e contrato de pacote de exportacao.

Capacidades:

- normalizacao e validacao de requests de import
- modos suportados: always, skip-if-exists, update, replace-safe
- ordem de dependencia: library -> folder -> permission
- execucao efetiva de import por tipo com resumo de created/updated/skipped

### compareService.js

Engine de comparacao de estado entre pacote baseline e ambiente atual.

Capacidades:

- comparacao por tipo: library, folder, permission
- status por item: equal, different, missing
- consolidacao de diffs por objeto
- suporte a includeUnchanged

### operationsStoreService.js

Persistencia de operacoes assincronas.

Capacidades:

- cria operationId
- gerencia estados queued/running/succeeded/partial/failed
- armazena payload, resultado e erro de execucao

### auditTrailService.js

Trilha tecnica de auditoria para rastreabilidade operacional.

Capacidades:

- grava eventos por acao
- inclui operationId e correlationId
- consulta paginada com filtros

## Relacionamento arquitetural

- routes/sharepoint.routes.js -> controllers/* -> services/*
- configuracao central em api/config/config.js
- segredos e credenciais no api/.env
