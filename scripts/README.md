# Scripts ativos

Este diretório mantém apenas automações do escopo SharePoint Graph.

- `Start-API-Background.ps1`
  - Sobe a API em background usando Node 20 e abre o painel web.

- `Validate-SharePointSetup.ps1`
  - Confere `.env`, certificado, health e autenticação.

- `Test-SharePointGraphEndpoints.ps1`
  - Valida health, config, autenticação, sites e bibliotecas.

- `Invoke-SharePointFileOps.ps1`
  - Cria pasta e envia um arquivo texto para um drive SharePoint.

- `Update-GraphAppScopes.ps1`
  - Atualiza os escopos (application permissions) da App Registration no Microsoft Graph.
  - Opcionalmente aplica atribuicoes para consentimento administrativo.
  - Pode listar o catalogo recomendado de permissoes e emitir saida JSON para integracao com a UI administrativa.

- `GRAPH-APP-PERMISSIONS-REVIEW.md`
  - Matriz de permissoes recomendadas para os recursos SharePoint + Teams + Entra ID.

- `common/Get-ProjectConfig.ps1`
  - Carrega o `config/config.json` simplificado do projeto.

- `Git-InitLocalRepository.ps1`
  - Inicializa repositório local, cria/ajusta branch inicial, adiciona arquivos, cria commit e opcionalmente configura remoto/push.

- `Git-NewBranch.ps1`
  - Cria nova branch a partir de uma base definida (`main` por padrão) com opcional de fetch e publish remoto.

- `Git-SyncMainAndValidate.ps1`
  - Atualiza branch `main`, valida sincronismo com remoto e executa comando opcional de validação.

- `Import-SharePointPermissionsPackage.ps1`
  - Importa pacote de configuracoes/permissoes no tenant conectado via endpoint administrativo da API.

- `git-automation/README.md`
  - Guia detalhado de uso dos scripts de automação Git (bootstrap, branch e sync da main).

## Uso rápido

```powershell
.\scripts\Start-API-Background.ps1
.\scripts\Validate-SharePointSetup.ps1
.\scripts\Test-SharePointGraphEndpoints.ps1 -ApiBaseUrl "http://localhost:3001/api/v1"
.\scripts\Invoke-SharePointFileOps.ps1 -DriveId "<drive-id>" -ApiBaseUrl "http://localhost:3001/api/v1"
.\scripts\Update-GraphAppScopes.ps1 -TenantId "<tenant-id>" -ClientId "<app-client-id>" -GrantAdminConsentAssignments
.\scripts\Update-GraphAppScopes.ps1 -ListRecommendedPermissions -OutputJson

# automacao git
.\scripts\Git-InitLocalRepository.ps1 -InitialBranch main -CommitMessage "chore: bootstrap" -RemoteUrl "https://github.com/org/repo.git" -Push
.\scripts\Git-NewBranch.ps1 -Name "feature/operations-center" -From main -Fetch -TrackRemote
.\scripts\Git-SyncMainAndValidate.ps1 -MainBranch main -RemoteName origin -FailIfDirty -ValidationCommand "npm test -- --grep 'Web pages smoke tests'"
.\scripts\Import-SharePointPermissionsPackage.ps1 -PackagePath ".\raw\permissions-package.json" -Mode update -DryRun
```

## Fluxo guiado para App Registration

1. Liste a matriz recomendada:

```powershell
.\scripts\Update-GraphAppScopes.ps1 -ListRecommendedPermissions -OutputJson
```

1. Gere um preview seguro sem alterar nada:

```powershell
.\scripts\Update-GraphAppScopes.ps1 -TenantId "<tenant-id>" -ClientId "<app-client-id>" -WhatIf -OutputJson
```

1. Aplique os escopos e, se desejar, as atribuicoes de app role:

```powershell
.\scripts\Update-GraphAppScopes.ps1 -TenantId "<tenant-id>" -ClientId "<app-client-id>" -GrantAdminConsentAssignments -OutputJson
```

## Execucao pela pagina administrativa

- A pagina `/web/admin.html` consome a matriz de permissoes e gera preview do comando.
- Para permitir execucao remota pelo backend, defina `ENABLE_ADMIN_SCRIPT_EXECUTION=true` no ambiente da API.
- Em producao, mantenha esse sinalizador desabilitado por padrao.

## Conteúdo legado

Scripts SCCM, GPO, Autopilot, Intune e correlatos ficam em:

- `backup/legacy-2026-03-12/scripts`
