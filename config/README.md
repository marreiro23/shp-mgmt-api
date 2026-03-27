## Configuração centralizada

Este diretório contém o `config.json` simplificado do projeto.

## Objetivo do arquivo

- Centralizar paths do workspace.
- Expor defaults do host da API.
- Definir metadados do projeto SharePoint.
- Permitir que scripts PowerShell leiam a mesma base estrutural.

## Seções principais

- `application`
- `paths`
- `api`
- `logging`
- `powershell`
- `sharepoint`
- `features`
- `web`

## Uso no PowerShell

```powershell
$Config = & (Join-Path $PSScriptRoot '..\scripts\common\Get-ProjectConfig.ps1')
Write-Host $Config.Api.Port
Write-Host $Config.SharePoint.Scope
```

## Observações

- O `config.json` não substitui o `.env` da API para credenciais sensíveis.
- O fluxo ativo não inclui SCCM, GPO, Autopilot, Intune ou Tenable.
