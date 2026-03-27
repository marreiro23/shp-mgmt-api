# Primeiros passos

## Objetivo

Subir a API localmente, validar autenticacao Microsoft Graph e executar o fluxo basico nas paginas web.

## Pre-requisitos

- Node.js 20.x
- npm
- App Registration com autenticacao por certificado
- Arquivo de certificado com chave privada e certificado publico

## Passo 1 - Configurar ambiente da API

No arquivo api/.env, configure:

```env
TENANT_ID=<tenant-id>
CLIENT_ID=<client-id>
CERT_THUMBPRINT=<thumbprint-sha1>
CERT_PRIVATE_KEY_PATH=../certs/sharepoint-file-manager-api.pem
GRAPH_SCOPE=https://graph.microsoft.com/.default
PORT=3001
HOST=localhost
```

Notas:

- CERT_PRIVATE_KEY_PATH e resolvido em relacao a pasta api/.
- O thumbprint deve corresponder ao certificado informado no caminho.

## Passo 2 - Instalar e iniciar

Na pasta api/:

```bash
npm install
npm run start:lts
```

## Passo 3 - Verificar saude da API

Abra no navegador:

- [health](http://localhost:3001/health)
- [manifesto raiz](http://localhost:3001/)

Resultados esperados:

- health retorna status OK
- raiz retorna manifesto com endpoints ativos e paginas web

## Passo 4 - Validar frontend

Abra:

- [index](http://localhost:3001/web/index.html)
- [operations](http://localhost:3001/web/operations.html)
- [collaboration](http://localhost:3001/web/collaboration.html)
- [admin](http://localhost:3001/web/admin.html)

Fluxo recomendado:

1. Em index.html, execute autenticacao Graph.
2. Em operations.html, liste sites e drives.
3. Em collaboration.html, execute pelo menos uma consulta de export e uma operacao de grupo/usuario.
4. Em admin.html, visualize recomendacoes de permissoes da App Registration.

## Passo 5 - Executar testes

Na pasta api/:

```bash
npm test
```

O comando executa:

- verificacao ASCII
- testes de configuracao
- testes de rotas
- smoke tests das paginas web

## Proximo passo

Para ampliar recursos no frontend usando novos endpoints da API, siga o guia [Expandir recursos da API nas paginas HTML](../how-to/expandir-recursos-nas-paginas-html.md).
