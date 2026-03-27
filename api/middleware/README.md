# Middlewares da API

Camada de middlewares usados pelo Express para segurança, logging e CORS.

## cors.js
- Controla origens permitidas com base em `config.CORS_ORIGINS`.
- Permite requisições sem `Origin` (Postman/curl).
- Habilita credenciais e métodos GET/POST/PUT/DELETE/OPTIONS.

## logger.js
- `consoleLogger` (morgan `dev`) para desenvolvimento.
- `fileLogger` grava logs em `logs/api.log` (modo produção).
- `customLogger` adiciona tempo de resposta, status, path, query, body (não-GET) e persiste em arquivo se `LOG_TO_FILE` estiver habilitado.
- Respeita `config.LOG_LEVEL` (exibe detalhes em `debug`).

## rateLimiter.js
- Limita requisições por janela (`RATE_LIMIT_WINDOW_MS`) e máximo (`RATE_LIMIT_MAX_REQUESTS`).
- Retorna mensagem padrão de muitas requisições.
- Usa cabeçalhos `standardHeaders` e desabilita `legacyHeaders`.

## Configuração
- Valores de CORS, logging e rate limit são definidos em `config/config.js` e podem ser ajustados via `.env`.
