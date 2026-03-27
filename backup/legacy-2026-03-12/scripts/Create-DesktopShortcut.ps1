#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cria atalho na área de trabalho para iniciar a API de CVE Management

.DESCRIPTION
    Este script cria um atalho na área de trabalho do usuário que:
    - Executa o script de inicialização da API
    - Usa ícone personalizado
    - Configura para executar em janela normal

.NOTES
    Autor: CVE Management System
    Versão: 1.0.0
#>

[CmdletBinding()]
param()

# Caminhos
$RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StartScriptPath = Join-Path $RepositoryRoot "Start-CVEManagementAPI.ps1"
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopPath "CVE Management API.lnk"

Write-Host "`n🔧 Criando atalho na área de trabalho...`n" -ForegroundColor Cyan

# Verificar se o script de inicialização existe
if (-not (Test-Path $StartScriptPath)) {
    Write-Host "❌ ERRO: Script de inicialização não encontrado!" -ForegroundColor Red
    Write-Host "   Esperado: $StartScriptPath" -ForegroundColor Yellow
    exit 1
}

try {
    # Criar objeto WScript.Shell para criar o atalho
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

    # Configurar propriedades do atalho
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$StartScriptPath`""
    $Shortcut.WorkingDirectory = $RepositoryRoot
    $Shortcut.Description = "Inicia o servidor da API de Gerenciamento de CVE"
    $Shortcut.WindowStyle = 1  # 1 = Normal, 3 = Maximized, 7 = Minimized

    # Tentar usar ícone do PowerShell
    $PowerShellIcon = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe,0"
    if (Test-Path $PowerShellIcon.Split(',')[0]) {
        $Shortcut.IconLocation = $PowerShellIcon
    }

    # Salvar atalho
    $Shortcut.Save()

    Write-Host "✅ Atalho criado com sucesso!" -ForegroundColor Green
    Write-Host "   Localização: $ShortcutPath" -ForegroundColor Gray
    Write-Host "   Script: $StartScriptPath" -ForegroundColor Gray

    # Perguntar se deseja abrir a área de trabalho
    Write-Host "`n💡 Deseja abrir a área de trabalho? (S/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host

    if ($response -match '^[SsYy]') {
        Start-Process "explorer.exe" -ArgumentList $DesktopPath
    }

    Write-Host "`n✨ Concluído! Use o atalho 'CVE Management API' na área de trabalho para iniciar o servidor.`n" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ ERRO ao criar atalho: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}
