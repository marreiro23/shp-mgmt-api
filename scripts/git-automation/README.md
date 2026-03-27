# Git Automation Scripts

Guia de uso dos scripts PowerShell para automacao de fluxo Git neste repositorio.

## Scripts cobertos

- `../Git-InitLocalRepository.ps1`
- `../Git-NewBranch.ps1`
- `../Git-SyncMainAndValidate.ps1`

## 1) Bootstrap de repositorio local

Script: `../Git-InitLocalRepository.ps1`

Objetivo:

- inicializar repositório local (se ainda nao existir)
- criar/ajustar branch inicial
- adicionar e commitar mudancas
- configurar remoto e fazer push opcional

Exemplo:

```powershell
Set-Location "C:\workdir\api-simple-sharepoint\shp-mgmt-api"

.\scripts\Git-InitLocalRepository.ps1 `
  -RepoPath "." `
  -InitialBranch "main" `
  -CommitMessage "chore: bootstrap local repository" `
  -RemoteName "origin" `
  -RemoteUrl "https://github.com/<org>/<repo>.git" `
  -Push
```

Parâmetros principais:

- `-RepoPath`: pasta do repositório (default `.`)
- `-InitialBranch`: branch inicial (default `main`)
- `-CommitMessage`: mensagem do commit inicial
- `-RemoteName`: nome do remoto (default `origin`)
- `-RemoteUrl`: URL do remoto
- `-Push`: envia para remoto (exige `-RemoteUrl`)

## 2) Criacao de nova branch

Script: `../Git-NewBranch.ps1`

Objetivo:

- criar branch nova a partir de uma base (por padrao `main`)
- opcionalmente atualizar refs remotas antes (`-Fetch`)
- opcionalmente publicar branch no remoto (`-TrackRemote`)

Exemplo:

```powershell
Set-Location "C:\workdir\api-simple-sharepoint\shp-mgmt-api"

.\scripts\Git-NewBranch.ps1 `
  -Name "feature/operations-center-improvements" `
  -From "main" `
  -Fetch `
  -TrackRemote
```

Parâmetros principais:

- `-Name` (obrigatório): nome da nova branch
- `-From`: branch base (default `main`)
- `-Fetch`: faz `git fetch --all --prune`
- `-TrackRemote`: faz push com tracking da nova branch

## 3) Atualizacao da main e validacao de sincronismo

Script: `../Git-SyncMainAndValidate.ps1`

Objetivo:

- atualizar branch `main` local via `pull --ff-only`
- validar estado de sincronismo com `origin/main`
- opcionalmente executar comando de validacao (testes/lint)

Exemplo:

```powershell
Set-Location "C:\workdir\api-simple-sharepoint\shp-mgmt-api"

.\scripts\Git-SyncMainAndValidate.ps1 `
  -MainBranch "main" `
  -RemoteName "origin" `
  -FailIfDirty `
  -ValidationCommand "npm test -- --grep 'Web pages smoke tests'"
```

Parâmetros principais:

- `-MainBranch`: branch principal (default `main`)
- `-RemoteName`: remoto (default `origin`)
- `-FailIfDirty`: falha se houver alteracoes locais
- `-ValidationCommand`: comando adicional para validar apos sync

## Fluxo recomendado

1. Bootstrap inicial (apenas primeira vez):

```powershell
.\scripts\Git-InitLocalRepository.ps1 -InitialBranch main -RemoteUrl "https://github.com/<org>/<repo>.git" -Push
```

2. Criar branch de trabalho:

```powershell
.\scripts\Git-NewBranch.ps1 -Name "feature/minha-feature" -From main -Fetch -TrackRemote
```

3. Antes de subir PR ou iniciar novo ciclo, validar a main:

```powershell
.\scripts\Git-SyncMainAndValidate.ps1 -FailIfDirty -ValidationCommand "npm test -- --grep 'Web pages smoke tests'"
```

## Erros comuns

- "Current directory is not a git repository": execute o comando na pasta raiz do projeto.
- "Main branch is not synchronized": rode o sync novamente e verifique conflitos locais.
- "-Push requires -RemoteUrl": informe `-RemoteUrl` no bootstrap ao usar `-Push`.

## Observacoes

- Os scripts evitam operacoes destrutivas.
- O script de sync usa `--ff-only` para evitar merges automaticos inesperados.
- Se quiser incluir esse fluxo em CI local, use `-ValidationCommand` com sua suite de testes.
