<#
.SYNOPSIS
    Testa o gerenciador de conexões da API

.DESCRIPTION
    Script para testar conexões configuradas no VS Code e endpoints da API.

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Test-ConnectionManager.ps1
#>

# Carregar configuração centralizada
try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

Write-Host "`n════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   Connection Manager - Teste Rápido" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$apiUrl = "http://$($Config.Api.Host):$($Config.Api.Port)$($Config.Api.Prefix)"

# Teste 1: Health Check da API
Write-Host "[1] Testando API Health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://$($Config.Api.Host):$($Config.Api.Port)/health" -Method Get
    Write-Host "    API Status: " -NoNewline
    Write-Host "OK" -ForegroundColor Green
} catch {
    Write-Host "    API Status: " -NoNewline
    Write-Host "FALHOU - API nao esta rodando!" -ForegroundColor Red
    Write-Host "`nInicie a API primeiro:" -ForegroundColor Yellow
    Write-Host "  cd cves/api" -ForegroundColor Gray
    Write-Host "  npm start`n" -ForegroundColor Gray
    exit 1
}

# Teste 2: Intune Config
Write-Host "`n[2] Testando Intune Config..." -ForegroundColor Yellow
try {
    $intuneConfig = Invoke-RestMethod -Uri "$apiUrl/intune/config" -Method Get
    Write-Host "    Intune Config: " -NoNewline
    if ($intuneConfig.success) {
        Write-Host "OK" -ForegroundColor Green
        Write-Host "    Tenant ID: $($intuneConfig.data.tenantId)" -ForegroundColor Gray
        Write-Host "    Authenticated: $($intuneConfig.data.isAuthenticated)" -ForegroundColor Gray
    } else {
        Write-Host "FALHOU" -ForegroundColor Red
    }
} catch {
    Write-Host "    Intune Config: " -NoNewline
    Write-Host "ERRO - $_" -ForegroundColor Red
}

# Teste 3: SCCM SQL Tools Connections
Write-Host "`n[3] Testando SCCM SQL Tools Connections..." -ForegroundColor Yellow
try {
    $sccmConn = Invoke-RestMethod -Uri "$apiUrl/sccm/sqltools-connections" -Method Get
    Write-Host "    SCCM Connections: " -NoNewline
    if ($sccmConn.success -and $sccmConn.data.Count -gt 0) {
        Write-Host "OK ($($sccmConn.data.Count) conexoes encontradas)" -ForegroundColor Green
        foreach ($conn in $sccmConn.data) {
            Write-Host "    - $($conn.name): $($conn.server)\$($conn.database) ($($conn.authenticationType))" -ForegroundColor Gray
        }
    } else {
        Write-Host "AVISO - Nenhuma conexao SQL configurada no VS Code" -ForegroundColor Yellow
        Write-Host "`n    Configure uma conexao SQL no VS Code:" -ForegroundColor Yellow
        Write-Host "    1. Instale a extensao: ms-mssql.mssql" -ForegroundColor Gray
        Write-Host "    2. Pressione Ctrl+Shift+P" -ForegroundColor Gray
        Write-Host "    3. Digite: 'MS SQL: Add Connection'" -ForegroundColor Gray
        Write-Host "    4. Configure: Server=$($Config.SCCM.Server), Database=$($Config.SCCM.Database)`n" -ForegroundColor Gray
    }
} catch {
    Write-Host "    SCCM Connections: " -NoNewline
    Write-Host "ERRO - $_" -ForegroundColor Red
}

# Teste 4: Tenable Vulnerabilities
Write-Host "`n[4] Testando Tenable Vulnerabilities..." -ForegroundColor Yellow
try {
    $tenable = Invoke-RestMethod -Uri "$apiUrl/tenable/vulnerabilities?limit=5" -Method Get
    Write-Host "    Tenable API: " -NoNewline
    if ($tenable.success) {
        Write-Host "OK (encontrados $($tenable.count) vulnerabilidades)" -ForegroundColor Green
    } else {
        Write-Host "AVISO - Nenhuma vulnerabilidade" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    Tenable API: " -NoNewline
    Write-Host "ERRO - $_" -ForegroundColor Red
}

# Teste 5: Custom Queries
Write-Host "`n[5] Testando Custom Queries..." -ForegroundColor Yellow
try {
    $queries = Invoke-RestMethod -Uri "$apiUrl/queries/list" -Method Get
    Write-Host "    Custom Queries: " -NoNewline
    if ($queries.success -and $queries.data.Count -gt 0) {
        Write-Host "OK (encontradas $($queries.data.Count) queries)" -ForegroundColor Green
    } else {
        Write-Host "OK (nenhuma query customizada)" -ForegroundColor Green
    }
} catch {
    Write-Host "    Custom Queries: " -NoNewline
    Write-Host "ERRO - $_" -ForegroundColor Red
}

Write-Host "`n════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  TESTES CONCLUIDOS" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════`n" -ForegroundColor Green
