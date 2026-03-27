# Documentacao do Projeto

Esta pasta organiza a documentacao do shp-mgmt-api no modelo Diataxis.

## Mapa da documentacao

- Tutorial:
  - [Primeiros passos](tutorials/primeiros-passos.md)
  - [PostgreSQL: primeiros passos](tutorials/postgresql-primeiros-passos.md)
- How-to:
  - [Expandir recursos da API nas paginas HTML](how-to/expandir-recursos-nas-paginas-html.md)
  - [Operar, manter e expandir PostgreSQL (inclui Azure Flexible Server)](how-to/operar-e-expandir-postgresql.md)
  - [Runbook de incidentes e troubleshooting PostgreSQL](how-to/runbook-incidentes-postgresql.md)
- Referencia:
  - [Arquitetura e codigo](reference/arquitetura-e-codigo.md)
  - [Dependencias](reference/dependencias.md)
  - [Endpoints da API](reference/endpoints.md)
  - [Uso dos endpoints com Invoke-RestMethod, curl e Postman](reference/endpoints-uso-cli-postman.md)
  - [PostgreSQL: ambiente e schema](reference/postgresql-ambiente-e-schema.md)
- Explicacao:
  - [Decisoes de design e limites do escopo](explanation/design-e-decisoes.md)
  - [Por que PostgreSQL foi escolhido](explanation/postgresql-como-plataforma-de-dados.md)

## Publico alvo

- Desenvolvedores Node.js que vao manter ou evoluir a API.
- Desenvolvedores frontend que vao ampliar as paginas estaticas em web/.
- Operadores tecnicos que precisam entender autenticacao, permissoes e fluxo de execucao.

## Escopo

- Inclui backend API, frontend estatico, testes e scripts ativos relacionados ao fluxo SharePoint + Graph.
- Exclui modulos legados em backup/legacy-2026-03-12/.
