# Interface Web SharePoint

Frontend estático mínimo para validar o fluxo ativo da API SharePoint Graph.

## Páginas ativas

- `index.html`
  - Redireciona por padrão para `operations-center.html`.
  - A interface legada permanece acessível com `index.html?legacy=1`.
  - Health check da API.
  - Visualização da configuração atual de autenticação.
  - Disparo do endpoint de autenticação Graph.

- `operations-center.html`
  - Interface unificada em estilo console operacional.
  - Navegação lateral por módulos: SharePoint, Teams/Entra, Import, Compare, Operações, Auditoria e Exportação.
  - Execução de import/compare com `operationId` e integração com monitoramento assíncrono.
  - Exportação operacional e exportação de diff de compare por `operationId`.
  - Layout desktop-like inspirado no modelo de operação da aplicação de referência.

- `operations.html`
  - Busca de sites.
  - Listagem de bibliotecas.
  - Navegação de pastas e arquivos.
  - Criação de pasta.
  - Upload de arquivo texto.
  - Renomeação e exclusão de item.

- `collaboration.html`
  - Exportação de resultados em CSV, JSON e XLSX.
  - Exportação de drives e bibliotecas por site.
  - Listagem de arquivos e metadados.
  - Listagem, criação e atualização de bibliotecas.
  - Criação e atualização de drives.
  - Listagem de canais do Teams.
  - Listagem de membros de canal.
  - Listagem de conteúdo do canal.
  - Listagem, criação e atualização de grupos.
  - Listagem e atualização de usuários.
  - Listagem e atribuição de licenças de usuários.
  - Listagem, concessão e remoção de permissões de item.
  - Inclusão e remoção de membros de canal.
  - Inclusão e remoção de membros de grupos Entra ID.

- `admin.html`
  - Visualização da matriz recomendada de permissões Graph.
  - Geração de preview do comando `Update-GraphAppScopes.ps1`.
  - Execução remota controlada por ambiente para atualização de escopos.
  - Fluxo guiado para App Registration e consentimento administrativo.

## Integração

- Base da API: `/api/v1/sharepoint`
- As páginas são servidas pelo Express em `/web/*`
- O frontend ativo não depende de SCCM, GPO, Autopilot, Intune ou Tenable

## Validação rápida

1. Inicie a API em `http://localhost:3001`.
2. Abra `/web/index.html` (redirecionamento automático para o Operations Center).
3. Execute autenticação.
4. Acesse `/web/operations-center.html` para o fluxo unificado de operação.
5. Siga para `/web/operations.html` para validar o fluxo legado de sites, drives e arquivos.
6. Use `/web/collaboration.html` para Teams, Entra ID e exportação legada.
7. Use `/web/admin.html` para App Registration e permissões.
