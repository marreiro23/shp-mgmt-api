## Controllers ativos

## sharepointController.js

- Expõe o status de configuração e autenticação do Graph.
- Lista sites SharePoint.
- Lista drives por site.
- Lista children por drive/pasta.
- Cria pasta.
- Faz upload de arquivo texto.
- Renomeia item.
- Remove item.

## Convenções

- Prefixo base: `/api/v1/sharepoint/*`
- Envelope de erro: `success`, `correlationId`, `error.code`, `error.message`
- As mensagens retornadas ao cliente são estáveis; detalhes sensíveis não são expostos
