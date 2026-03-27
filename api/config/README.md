## Configuração da API SharePoint

Este diretório concentra a configuração do backend ativo.

## Arquivos

- `.env`
	- Credenciais Graph e parâmetros de runtime.
- `config.js`
	- Validação de ambiente com Joi e defaults do servidor.

## Variáveis esperadas no `.env`

- `TENANT_ID`
- `CLIENT_ID`
- `CERT_THUMBPRINT`
- `CERT_PRIVATE_KEY_PATH`
- `GRAPH_SCOPE`
- `REQUEST_TIMEOUT_SECONDS`
- `RETRY_ATTEMPTS`
- `CORS_ORIGINS`
- `LOG_LEVEL`

## Regras do fluxo ativo

- O backend usa autenticação por certificado.
- O arquivo PEM deve conter certificado público e chave privada.
- O thumbprint configurado deve corresponder ao certificado carregado.
- O escopo padrão é `https://graph.microsoft.com/.default`.

## Uso no código

```js
import config from './config/config.js';

const apiPort = config.PORT;
const apiPrefix = config.API_PREFIX;
```
