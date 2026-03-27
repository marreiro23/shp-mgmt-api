# Design e decisoes

## Contexto do projeto

O shp-mgmt-api foi consolidado para um escopo primario: SharePoint Online via Microsoft Graph.

O objetivo foi remover dependencias operacionais de modulos legados no fluxo principal, mantendo a API focada em:

- sites, drives, bibliotecas, pastas e arquivos
- colaboracao Microsoft Teams
- grupos e usuarios Entra ID
- exportacao de resultados para consumo operacional

## Por que usar app-only com certificado

O projeto adotou autenticacao app-only com certificado por tres motivos:

1. Evitar dependencia de login interativo para automacao
2. Melhor alinhamento com execucao em backend e scripts
3. Reducao de exposicao de segredo compartilhado (client secret)

Consequencia pratica:

- a API depende de TENANT_ID, CLIENT_ID, CERT_PRIVATE_KEY_PATH e CERT_THUMBPRINT corretos.

## Por que bibliotecas sao tratadas como listas + drives

No Graph, bibliotecas de documentos SharePoint sao listas do tipo documentLibrary com relacao para drive.

No projeto:

- criar biblioteca: POST em /sites/{siteId}/lists com template documentLibrary
- atualizar biblioteca: estrategia via drive associado

Isso evita duplicidade de modelos e simplifica interoperabilidade com operacoes de arquivo.

## Por que manter frontend estatico

As paginas HTML em web/ foram mantidas estaticas para:

1. reduzir complexidade de build/deploy
2. acelerar validacao manual de endpoints
3. facilitar onboard de times operacionais

Trade-off:

- nao ha framework SPA, estado global sofisticado ou roteamento cliente.

## Envelope de erro estavel

A API padroniza erros com:

- success=false
- error.code
- error.message
- correlationId

Isso melhora rastreabilidade e reduz acoplamento no frontend.

## Limites funcionais atuais

- criacao e modificacao de sites SharePoint nao estao expostas como operacao ativa no fluxo principal
- conteudos legados permanecem isolados em backup/legacy-2026-03-12/

## Estrategia para evolucao segura

Sempre evoluir em camadas pequenas:

1. service Graph
2. controller
3. route
4. cobertura de teste
5. exposicao no frontend
6. documentacao

Esse ciclo reduz regressao e mantem rastreabilidade das mudancas.
