# Documentacao do Projeto

Esta pasta organiza a documentacao do shp-mgmt-api no modelo Diataxis.

## Mapa da documentacao

- Tutorial:
  - [Primeiros passos](tutorials/primeiros-passos.md)
- How-to:
  - [Expandir recursos da API nas paginas HTML](how-to/expandir-recursos-nas-paginas-html.md)
- Referencia:
  - [Arquitetura e codigo](reference/arquitetura-e-codigo.md)
  - [Dependencias](reference/dependencias.md)
  - [Endpoints da API](reference/endpoints.md)
  - [Uso dos endpoints com Invoke-RestMethod, curl e Postman](reference/endpoints-uso-cli-postman.md)
- Explicacao:
  - [Decisoes de design e limites do escopo](explanation/design-e-decisoes.md)

## Publico alvo

- Desenvolvedores Node.js que vao manter ou evoluir a API.
- Desenvolvedores frontend que vao ampliar as paginas estaticas em web/.
- Operadores tecnicos que precisam entender autenticacao, permissoes e fluxo de execucao.

## Escopo

- Inclui backend API, frontend estatico, testes e scripts ativos relacionados ao fluxo SharePoint + Graph.
- Exclui modulos legados em backup/legacy-2026-03-12/.
