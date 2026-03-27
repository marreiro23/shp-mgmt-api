<#
.SYNOPSIS
    Inicia a shp-mgmt-api em background (Windows PowerShell / pwsh).

.DESCRIPTION
    Verifica e instala dependências, inicializa o banco de dados PostgreSQL
    na primeira execução, e inicia o servidor Node.js como um background job.

    PRIMEIRA EXECUÇÃO (clone do repositório):
        O script detecta automaticamente a ausência do arquivo .setup-complete
        e executa a sequência completa de setup:
            1. Verifica / instala Node.js
            2. Verifica / instala PostgreSQL (via winget)
            3. Executa Initialize-Database.ps1 (cria DB, schema, usuário)
            4. Instala dependências npm
            5. Marca setup como concluído (.setup-complete)

    EXECUÇÕES SUBSEQUENTES:
        Verifica apenas se o serviço PostgreSQL está ativo (se PG_HOST=localhost)
        e inicia a API normalmente.

.PARAMETER Setup
    Força a re-execução completa do setup, mesmo que .setup-complete exista.

.PARAMETER SkipDb
    Ignora toda a parte de banco de dados (útil se o BD for externo/Azure).

.PARAMETER SkipBrowser
    Não abre o navegador ao final.

.EXAMPLE
    # Primeira vez (ou qualquer execução normal)
    .\Start-API-Background.ps1

.EXAMPLE
    # Forçar re-setup completo
    .\Start-API-Background.ps1 -Setup

.EXAMPLE
    # API com BD externo (Azure Flexible Server) - sem checar PostgreSQL local
    .\Start-API-Background.ps1 -SkipDb

.NOTES
    Requisitos: Windows 10/11, PowerShell 5.1+ ou pwsh 7+
    Para Azure Flexible Server, defina as vars PG_* no arquivo api/.env
    antes de executar (ou use Initialize-Database.ps1 com -PgHost).
#>

[CmdletBinding()]
param(
    [switch]$Setup,
    [switch]$SkipDb,
    [switch]$SkipBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Paths ────────────────────────────────────────────────────────────────────
$repoRoot       = Split-Path -Parent $PSScriptRoot
$apiPath        = Join-Path $repoRoot 'api'
$setupMarker    = Join-Path $repoRoot '.setup-complete'
$initDbScript   = Join-Path $PSScriptRoot 'Initialize-Database.ps1'

# ─── Banner ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '╔════════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║           SHP-MGMT-API  ::  Inicialização da API              ║' -ForegroundColor Cyan
Write-Host '╚════════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

# ─── Funções auxiliares ───────────────────────────────────────────────────────

function Get-EnvVar([string]$key, [string]$default = '') {
    $envFile = Join-Path $apiPath '.env'
    if (Test-Path $envFile) {
        $line = Get-Content $envFile | Where-Object { $_ -match "^${key}=" } | Select-Object -First 1
        if ($line) { return ($line -split '=', 2)[1].Trim() }
    }
    return $default
}

function Install-PostgreSQLViaNPM {
    # Tentativa via winget com IDs conhecidos do PostgreSQL 16
    $pgPackages = @(
        'PostgreSQL.PostgreSQL.16',   # Típico no winget store
        'PostgreSQL.PostgreSQL',       # Genérico (sem versão)
        'EDB.PostgreSQL16'             # Installer EDB
    )

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host '   ⚠️  winget não disponível. Instale o PostgreSQL manualmente:' -ForegroundColor Yellow
        Write-Host '       https://www.postgresql.org/download/windows/' -ForegroundColor Gray
        return $false
    }

    foreach ($pkg in $pgPackages) {
        Write-Host "   Tentando: winget install --id $pkg ..." -ForegroundColor Gray
        $result = winget install --id $pkg --silent `
                    --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ PostgreSQL instalado ($pkg)." -ForegroundColor Green
            # Atualizar PATH para que psql seja encontrado nesta sessão
            $pgBin = 'C:\Program Files\PostgreSQL\16\bin'
            if (Test-Path $pgBin) {
                $env:PATH = "$pgBin;$env:PATH"
            }
            return $true
        }
        Write-Host "      ($pkg) não encontrado ou falhou. Próximo..." -ForegroundColor Gray
    }

    Write-Host ''
    Write-Host '   ❌ Não foi possível instalar o PostgreSQL automaticamente.' -ForegroundColor Red
    Write-Host '      Instale manualmente: https://www.postgresql.org/download/windows/' -ForegroundColor Yellow
    return $false
}

function Test-PostgreSQLAvailable {
    # 1) psql no PATH
    if (Get-Command psql -ErrorAction SilentlyContinue) { return $true }

    # 2) binários no caminho padrão do instalador EDB
    foreach ($ver in @('16','15','14','17')) {
        $bin = "C:\Program Files\PostgreSQL\$ver\bin\psql.exe"
        if (Test-Path $bin) {
            $env:PATH = "$(Split-Path $bin);$env:PATH"
            return $true
        }
    }
    return $false
}

function Assert-PostgreSQLService {
    $svc = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $svc) {
        Write-Host '   ⚠️  Serviço PostgreSQL não encontrado.' -ForegroundColor Yellow
        return $false
    }
    if ($svc.Status -ne 'Running') {
        Write-Host "   🔄 Iniciando serviço '$($svc.Name)'..." -ForegroundColor Yellow
        Start-Service $svc.Name -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $svc.Refresh()
    }
    if ($svc.Status -eq 'Running') {
        Write-Host "   ✅ Serviço '$($svc.Name)' está rodando." -ForegroundColor Green
        return $true
    }
    Write-Host "   ❌ Não foi possível iniciar o serviço '$($svc.Name)'." -ForegroundColor Red
    return $false
}

# ─── Detectar primeira execução ────────────────────────────────────────────────
$isFirstRun = (-not (Test-Path $setupMarker)) -or $Setup.IsPresent

if ($isFirstRun) {
    Write-Host '════════════════════════════════════════════════════════════════' -ForegroundColor Yellow
    if ($Setup.IsPresent) {
        Write-Host '  Modo -Setup: re-executando configuração completa...' -ForegroundColor Yellow
    } else {
        Write-Host '  PRIMEIRA EXECUÇÃO detectada. Iniciando setup do ambiente...' -ForegroundColor Yellow
    }
    Write-Host '════════════════════════════════════════════════════════════════' -ForegroundColor Yellow
    Write-Host ''
}

# ─── Passo 1: Node.js ─────────────────────────────────────────────────────────
try {
    $nodeVersion = node --version 2>&1
    Write-Host "✅ Node.js detectado: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host '❌ Node.js não encontrado!' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Instale Node.js de: https://nodejs.org/  (versão 20 LTS recomendada)' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

# ─── Passo 2: PostgreSQL (apenas na primeira execução ou -Setup) ───────────────
if (-not $SkipDb) {
    if ($isFirstRun) {
        Write-Host ''
        Write-Host '🐘 Verificando PostgreSQL...' -ForegroundColor Cyan

        $pgAvailable = Test-PostgreSQLAvailable
        if (-not $pgAvailable) {
            Write-Host '   PostgreSQL não detectado. Tentando instalar via winget...' -ForegroundColor Yellow
            $installed = Install-PostgreSQLViaNPM
            if (-not $installed) {
                Write-Host ''
                Write-Host '⚠️  PostgreSQL não instalado. A API iniciará sem persistência em banco de dados.' -ForegroundColor Yellow
                Write-Host '   Execute Initialize-Database.ps1 após instalar o PostgreSQL.' -ForegroundColor Gray
                Write-Host ''
            } else {
                $pgAvailable = $true
            }
        } else {
            Write-Host '   ✅ PostgreSQL disponível.' -ForegroundColor Green
        }

        # Executar Initialize-Database.ps1 se PostgreSQL disponível
        if ($pgAvailable) {
            Write-Host ''
            Write-Host '🗄️  Inicializando banco de dados...' -ForegroundColor Cyan
            if (-not (Test-Path $initDbScript)) {
                Write-Host "   ❌ Script não encontrado: $initDbScript" -ForegroundColor Red
                exit 1
            }
            try {
                & $initDbScript -WriteEnvFile
                if ($LASTEXITCODE -ne 0) { throw "Initialize-Database.ps1 retornou código $LASTEXITCODE" }
            } catch {
                Write-Host ''
                Write-Host '❌ Falha na inicialização do banco:' -ForegroundColor Red
                Write-Host "   $($_.Exception.Message)" -ForegroundColor Gray
                Write-Host ''
                Write-Host 'Corrija o problema e execute novamente, ou use -SkipDb para ignorar o BD.' -ForegroundColor Yellow
                exit 1
            }
        }
    } else {
        # Execuções subsequentes: apenas verificar serviço local (se PG_HOST=localhost)
        $pgHost = Get-EnvVar 'PG_HOST' 'localhost'
        if ($pgHost -eq 'localhost' -or $pgHost -eq '127.0.0.1') {
            Write-Host '🐘 Verificando serviço PostgreSQL local...' -ForegroundColor Gray
            Assert-PostgreSQLService | Out-Null
        } else {
            Write-Host "🐘 PostgreSQL externo configurado ($pgHost) - sem verificação de serviço local." -ForegroundColor Gray
        }
    }
}

# ─── Passo 3: Dependências npm ────────────────────────────────────────────────
if (-not (Test-Path (Join-Path $apiPath 'node_modules'))) {
    Write-Host ''
    Write-Host '📦 Instalando dependências npm (npm ci)...' -ForegroundColor Yellow
    Push-Location $apiPath
    try {
        npm ci --silent
        if ($LASTEXITCODE -ne 0) { throw "npm ci falhou" }
    } finally {
        Pop-Location
    }
    Write-Host '   ✅ Dependências instaladas.' -ForegroundColor Green
}

# ─── Passo 4: Marcar setup completo ───────────────────────────────────────────
if ($isFirstRun) {
    "Setup concluído em $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" |
        Set-Content $setupMarker -Encoding UTF8
    Write-Host ''
    Write-Host '✅ Setup concluído. Arquivo .setup-complete criado.' -ForegroundColor Green
}

# ─── Passo 5: Parar servidor existente ────────────────────────────────────────
Get-Job | Where-Object { $_.Name -like '*SHP-MGMT-API*' } | ForEach-Object {
    Write-Host "🛑 Parando servidor anterior (Job ID: $($_.Id))..." -ForegroundColor Yellow
    Stop-Job $_.Id -ErrorAction SilentlyContinue
    Remove-Job $_.Id -ErrorAction SilentlyContinue
}

# ─── Passo 6: Verificar porta 3001 ────────────────────────────────────────────
$portInUse = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue
if ($portInUse) {
    Write-Host '⚠️  Porta 3001 já está em uso!' -ForegroundColor Yellow
    $proc = Get-Process -Id $portInUse.OwningProcess -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "   Processo: $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Gray
    }
    Write-Host '❌ Libere a porta 3001 antes de iniciar a API.' -ForegroundColor Red
    exit 1
}

# ─── Passo 7: Iniciar servidor em background ──────────────────────────────────
Write-Host ''
Write-Host '🚀 Iniciando servidor em background...' -ForegroundColor Cyan

$job = Start-Job -Name 'SHP-MGMT-API-Server' -ScriptBlock {
    param($apiPath)
    Set-Location $apiPath
    npm run start:lts
} -ArgumentList $apiPath

Start-Sleep -Seconds 3

$jobState = Get-Job -Id $job.Id
if ($jobState.State -eq 'Running') {
    Write-Host '✅ Servidor iniciado com sucesso!' -ForegroundColor Green
    Write-Host ''
    Write-Host '📊 Informações do Servidor:' -ForegroundColor Cyan
    Write-Host "   • Job ID  : $($job.Id)" -ForegroundColor White
    Write-Host '   • URL     : http://localhost:3001' -ForegroundColor White
    Write-Host '   • Dashboard: http://localhost:3001/web/index.html' -ForegroundColor White
    Write-Host ''

    try {
        $response = Invoke-WebRequest -Uri 'http://localhost:3001/health' -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host '✅ Health check: OK' -ForegroundColor Green
        }
    } catch {
        Write-Host '⚠️  Health check falhou (servidor ainda pode estar inicializando)' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '📋 Comandos úteis:' -ForegroundColor Cyan
    Write-Host "   • Ver logs : Receive-Job -Id $($job.Id) -Keep" -ForegroundColor Gray
    Write-Host "   • Parar    : Stop-Job -Id $($job.Id); Remove-Job -Id $($job.Id)" -ForegroundColor Gray
    Write-Host '   • Listar   : Get-Job' -ForegroundColor Gray
    Write-Host ''

    if (-not $SkipBrowser) {
        Start-Process 'http://localhost:3001/web/index.html'
        Write-Host '🌐 Navegador aberto!' -ForegroundColor Green
    }

} else {
    Write-Host '❌ Erro ao iniciar servidor!' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Logs do erro:' -ForegroundColor Yellow
    Receive-Job -Id $job.Id
    Remove-Job -Id $job.Id
    exit 1
}

Write-Host ''
Write-Host '💡 Dica: O servidor continuará rodando em background mesmo se você fechar este terminal.' -ForegroundColor Cyan
Write-Host ''
