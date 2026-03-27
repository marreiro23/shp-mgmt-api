# Dependencias

## Runtime da API

Arquivo fonte: api/package.json

## Dependencias de producao

- @azure/identity
  - Uso: autenticacao app-only por certificado (ClientCertificateCredential)
  - Impacto: sem esta biblioteca, a API nao autentica no Graph

- @microsoft/microsoft-graph-client
  - Uso: suporte ao ecossistema Graph (atualmente menor uso direto no service)
  - Impacto: facilita expansoes futuras para client Graph tipico

- axios
  - Uso: cliente HTTP para chamadas Graph
  - Impacto: controla timeout, headers e captura de erros HTTP

- cors
  - Uso: politica CORS da API
  - Impacto: permite chamadas do frontend local

- dotenv
  - Uso: carregamento de variaveis de ambiente
  - Impacto: injeta configuracoes sensiveis sem hardcode

- express
  - Uso: servidor HTTP e roteamento
  - Impacto: base da API REST

- express-rate-limit
  - Uso: limitacao de taxa em /api
  - Impacto: reduz abuso e rajadas de requisicao

- helmet
  - Uso: headers de seguranca HTTP
  - Impacto: endurecimento baseline da API

- isomorphic-fetch
  - Uso: suporte fetch em cenarios de teste/compatibilidade
  - Impacto: uniformiza chamadas HTTP em ambiente Node

- joi
  - Uso: validacoes de schema (presente no projeto)
  - Impacto: melhora robustez de entrada

- morgan
  - Uso: logging HTTP
  - Impacto: observabilidade de requests/responses

- xlsx
  - Uso: geracao de exportacao .xlsx
  - Impacto: habilita entrega de planilhas no endpoint de export

## Dependencias de desenvolvimento

- chai
  - Uso: assercoes em testes

- joi-to-swagger
  - Uso: potencial geracao de schema/swagger a partir de Joi

- mocha
  - Uso: runner de testes

- nodemon
  - Uso: hot reload no desenvolvimento

## Scripts npm relevantes

- npm run start
  - sobe API com Node atual
- npm run start:lts
  - sobe API com Node 20 via npx
- npm test
  - executa verify:ascii + mocha
- npm run test:lts
  - roda testes com Node 20 explicitamente

## Dependencias operacionais externas

- Microsoft Graph API v1.0
- Microsoft Entra ID (tenant + app registration)
- Certificado com chave privada para fluxo app-only
- PowerShell para scripts de setup e update de escopos

## Compatibilidade de versao

- engines.node: >=20.0.0 <21
- Recomendacao: executar API e testes sempre com Node 20.x para evitar divergencias de runtime.
