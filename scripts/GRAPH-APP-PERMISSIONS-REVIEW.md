# Revisao de permissoes Microsoft Graph (App Registration)

## Escopo dos recursos novos

- Exportacao CSV/JSON
- Listagem de arquivos e metadados em drives SharePoint
- Listagem de canais do Microsoft Teams
- Listagem de conteudo de canal (mensagens + arquivos)
- Adicao e remocao de membros em canais do Teams
- Adicao e remocao de membros em grupos Entra ID

## Permissoes de aplicativo recomendadas

As permissoes abaixo sao para fluxo `client_credentials` (application permissions):

- `Sites.ReadWrite.All`
  - Necessaria para listar e operar itens em SharePoint/Teams files
- `Files.ReadWrite.All`
  - Necessaria para operacoes em arquivos e metadados em drives
- `Channel.ReadBasic.All`
  - Necessaria para listar canais de um time
- `ChannelMessage.Read.All`
  - Necessaria para ler mensagens do canal
- `ChannelMember.ReadWrite.All`
  - Necessaria para adicionar/remover membros de canal
- `GroupMember.ReadWrite.All`
  - Necessaria para adicionar/remover membros de grupos Entra ID

## Permissoes opcionais (somente se o fluxo exigir)

- `Group.Read.All`
  - Se houver necessidade de listar/gravar validacoes de grupos antes da operacao
- `User.Read.All`
  - Se houver necessidade de resolver usuarios por UPN/email no backend

## Principio do menor privilegio

- Se a API nao precisa escrever arquivos, prefira `Sites.Read.All` e `Files.Read.All`.
- Se a API nao precisa alterar membros de canais, remova `ChannelMember.ReadWrite.All`.
- Se a API nao precisa alterar grupos, remova `GroupMember.ReadWrite.All`.

## Consentimento administrativo

Essas permissoes exigem consentimento administrativo no tenant. O script `Update-GraphAppScopes.ps1` pode aplicar os escopos e, opcionalmente, criar as atribuicoes de app role para acelerar o processo de consentimento.

## Fonte unica de configuracao

- Catalogo JSON compartilhado: `config/graph-app-permissions.json`
- Script operacional: `scripts/Update-GraphAppScopes.ps1`
- Pagina administrativa: `/web/admin.html`
