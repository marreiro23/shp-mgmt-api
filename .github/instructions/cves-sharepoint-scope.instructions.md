---
applyTo: '*'
description: 'Escopo CVES refatorado para SharePoint Online via Microsoft Graph. Evitar regressão para módulos legados SCCM/Intune/Tenable no fluxo principal.'
---

# CVES SharePoint Scope

## Escopo primário

- O projeto CVES está focado em SharePoint Online usando Microsoft Graph.
- Endpoints principais devem ser expostos em `/api/v1/sharepoint/*`.
- A autenticação deve usar `client_credentials` e variáveis de ambiente.

## Regras de implementação

- Priorize operações de sites, drives, pastas e arquivos.
- Trate erros de Graph com envelope estável (`success`, `error.code`, `error.message`, `correlationId`).
- Não registrar tokens, segredos ou material criptográfico em logs.
- Aplicar timeout e retry com backoff para erros transitórios (`429`, `5xx`).

## Backend

- Rotas legadas SCCM/Intune/Tenable não fazem parte do fluxo principal.
- Módulos descontinuados devem permanecer apenas em `backup/legacy-*`.
- `server.js` deve carregar somente rotas ativas do escopo SharePoint.

## Frontend

- Páginas principais devem refletir operações SharePoint Graph.
- Evitar chamadas para endpoints legados em páginas ativas.

## Scripts

- Scripts ativos devem validar e executar operações do novo escopo Graph + SharePoint.
- Scripts legados devem ser mantidos apenas em backup para referência histórica.
