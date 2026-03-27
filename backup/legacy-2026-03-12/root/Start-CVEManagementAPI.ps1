<#
.SYNOPSIS
    Wrapper de Inicialização da API CVE Management System

.DESCRIPTION
    Script PowerShell para inicializar a API CVE Management System com:
    - Inicialização automática do servidor Node.js
    - Abertura automática do navegador na interface web
    - Monitoramento de log em tempo real via CMTrace.exe

.PARAMETER NoBrowser
    Se especificado, não abre o navegador automaticamente

.PARAMETER NoLog
    Se especificado, não abre o CMTrace para visualização de log

.PARAMETER Port
    Porta para o servidor (padrão: 3001)

.EXAMPLE
    .\Start-CVEManagementAPI.ps1
    Inicia a API, abre o navegador e o log viewer

.EXAMPLE
    .\Start-CVEManagementAPI.ps1 -NoBrowser
    Inicia a API e log viewer sem abrir o navegador

.EXAMPLE
    .\Start-CVEManagementAPI.ps1 -Port 8080
    Inicia a API na porta 8080

.NOTES
    Nome do arquivo: Start-CVEManagementAPI.ps1
    Autor: CVE Management System
    Data: 10 de Janeiro de 2026
    Versão: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$NoBrowser,

    [Parameter(Mandatory = $false)]
    [switch]$NoLog,

    [Parameter(Mandatory = $false)]
    [int]$Port = 3001
)

# ============================================================================
# CONFIGURAÇÕES
# ============================================================================

$ErrorActionPreference = "Stop"
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$apiDir = Join-Path $baseDir "api"
$logFile = Join-Path $baseDir "logs\api.log"
$cmtracePath = "C:\Windows\System32\CMTrace.exe"

# Cores para output
$colorSuccess = "Green"
$colorInfo = "Cyan"
$colorWarning = "Yellow"
$colorError = "Red"

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

function Write-StatusMessage {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Type) {
        "Success" { $colorSuccess }
        "Warning" { $colorWarning }
        "Error" { $colorError }
        default { $colorInfo }
    }

    $symbol = switch ($Type) {
        "Success" { "✅" }
        "Warning" { "⚠️" }
        "Error" { "❌" }
        default { "ℹ️" }
    }

    Write-Host "[$timestamp] $symbol $Message" -ForegroundColor $color
}

function Test-NodeInstalled {
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-StatusMessage "Node.js detectado: $nodeVersion" -Type "Success"
            return $true
        }
    }
    catch {
        Write-StatusMessage "Node.js não encontrado!" -Type "Error"
        return $false
    }
}

function Test-CMTraceAvailable {
    if (Test-Path $cmtracePath) {
        Write-StatusMessage "CMTrace.exe encontrado: $cmtracePath" -Type "Success"
        return $true
    }
    else {
        Write-StatusMessage "CMTrace.exe não encontrado em: $cmtracePath" -Type "Warning"
        Write-StatusMessage "Log viewer não será aberto automaticamente" -Type "Warning"
        return $false
    }
}

function Stop-ExistingAPIProcess {
    $nodeProcesses = Get-Process -Name "node" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "*node.exe*" }

    if ($nodeProcesses) {
        Write-StatusMessage "Encerrando processos Node.js existentes..." -Type "Warning"
        $nodeProcesses | ForEach-Object {
            Write-StatusMessage "Encerrando processo: $($_.Id)" -Type "Info"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        Write-StatusMessage "Processos encerrados" -Type "Success"
    }
}

function Test-PortAvailable {
    param([int]$PortNumber)

    try {
        $tcpConnection = Test-NetConnection -ComputerName "localhost" -Port $PortNumber -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($tcpConnection) {
            Write-StatusMessage "Porta $PortNumber está em uso" -Type "Warning"
            return $false
        }
        Write-StatusMessage "Porta $PortNumber está disponível" -Type "Success"
        return $true
    }
    catch {
        # Se o comando falhar, assumimos que a porta está disponível
        return $true
    }
}

function Start-APIServer {
    param([int]$PortNumber)

    Write-StatusMessage "Iniciando servidor Node.js na porta $PortNumber..." -Type "Info"

    # Definir variável de ambiente para a porta
    $env:PORT = $PortNumber

    # Iniciar servidor em background
    $processInfo = Start-Process -FilePath "npm" -ArgumentList "start" -WorkingDirectory $apiDir -PassThru -WindowStyle Minimized

    if ($processInfo) {
        Write-StatusMessage "Servidor iniciado (PID: $($processInfo.Id))" -Type "Success"

        # Aguardar alguns segundos para o servidor inicializar
        Write-StatusMessage "Aguardando inicialização do servidor..." -Type "Info"
        Start-Sleep -Seconds 5

        # Verificar se o processo ainda está rodando
        $stillRunning = Get-Process -Id $processInfo.Id -ErrorAction SilentlyContinue
        if ($stillRunning) {
            Write-StatusMessage "Servidor está rodando!" -Type "Success"
            return $processInfo.Id
        }
        else {
            Write-StatusMessage "Servidor falhou ao iniciar!" -Type "Error"
            return $null
        }
    }
    else {
        Write-StatusMessage "Falha ao iniciar servidor!" -Type "Error"
        return $null
    }
}

function Open-WebBrowser {
    param([int]$PortNumber)

    $url = "http://localhost:$PortNumber/web/index.html"

    Write-StatusMessage "Abrindo navegador: $url" -Type "Info"

    try {
        Start-Process $url
        Write-StatusMessage "Navegador aberto com sucesso!" -Type "Success"
    }
    catch {
        Write-StatusMessage "Erro ao abrir navegador: $_" -Type "Error"
        Write-StatusMessage "Acesse manualmente: $url" -Type "Info"
    }
}

function Open-LogViewer {
    param([string]$LogPath)

    # Criar pasta de logs se não existir
    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Write-StatusMessage "Pasta de logs criada: $logDir" -Type "Info"
    }

    # Criar arquivo de log vazio se não existir
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType File -Path $LogPath -Force | Out-Null
        Write-StatusMessage "Arquivo de log criado: $LogPath" -Type "Info"
    }

    Write-StatusMessage "Abrindo CMTrace para monitoramento de log..." -Type "Info"

    try {
        Start-Process -FilePath $cmtracePath -ArgumentList "`"$LogPath`"" -WindowStyle Normal
        Write-StatusMessage "CMTrace aberto com sucesso!" -Type "Success"
    }
    catch {
        Write-StatusMessage "Erro ao abrir CMTrace: $_" -Type "Error"
        Write-StatusMessage "Log disponível em: $LogPath" -Type "Info"
    }
}

function Show-APIInfo {
    param([int]$PortNumber, [int]$ProcessId)

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         CVE MANAGEMENT API - INICIALIZAÇÃO COMPLETA            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  🚀 Servidor:        http://localhost:$PortNumber" -ForegroundColor Green
    Write-Host "  🌐 Interface Web:   http://localhost:$PortNumber/web/index.html" -ForegroundColor Green
    Write-Host "  📊 PID do Processo: $ProcessId" -ForegroundColor Green
    Write-Host "  📄 Log:             $logFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "  📚 Endpoints principais:" -ForegroundColor Cyan
    Write-Host "     • GET  /health                          - Health check" -ForegroundColor Gray
    Write-Host "     • GET  /api/v1/cve/applications        - Listar aplicações" -ForegroundColor Gray
    Write-Host "     • POST /api/v1/tenable/import          - Importar Tenable" -ForegroundColor Gray
    Write-Host "     • GET  /api/v1/sccm/queries            - Queries SCCM" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  💡 Dicas:" -ForegroundColor Yellow
    Write-Host "     • Pressione Ctrl+C para encerrar o servidor" -ForegroundColor Gray
    Write-Host "     • Use 'npm stop' ou feche o terminal para parar" -ForegroundColor Gray
    Write-Host "     • Consulte docs/INDEX.md para documentação completa" -ForegroundColor Gray
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# EXECUÇÃO PRINCIPAL
# ============================================================================

try {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         CVE MANAGEMENT API - WRAPPER DE INICIALIZAÇÃO          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # 1. Validar pré-requisitos
    Write-StatusMessage "Validando pré-requisitos..." -Type "Info"

    if (-not (Test-NodeInstalled)) {
        Write-StatusMessage "Node.js é necessário para executar a API!" -Type "Error"
        Write-StatusMessage "Instale Node.js em: https://nodejs.org/" -Type "Info"
        exit 1
    }

    if (-not (Test-Path $apiDir)) {
        Write-StatusMessage "Diretório da API não encontrado: $apiDir" -Type "Error"
        exit 1
    }

    $cmtraceAvailable = Test-CMTraceAvailable

    # 2. Verificar e encerrar processos existentes
    Stop-ExistingAPIProcess

    # 3. Verificar disponibilidade da porta
    if (-not (Test-PortAvailable -PortNumber $Port)) {
        Write-StatusMessage "Tentando liberar porta $Port..." -Type "Warning"
        Stop-ExistingAPIProcess
        Start-Sleep -Seconds 2

        if (-not (Test-PortAvailable -PortNumber $Port)) {
            Write-StatusMessage "Não foi possível liberar porta $Port!" -Type "Error"
            exit 1
        }
    }

    # 4. Iniciar servidor Node.js
    $processId = Start-APIServer -PortNumber $Port

    if (-not $processId) {
        Write-StatusMessage "Falha ao iniciar servidor!" -Type "Error"
        exit 1
    }

    # 5. Abrir navegador (se não desabilitado)
    if (-not $NoBrowser) {
        Start-Sleep -Seconds 2
        Open-WebBrowser -PortNumber $Port
    }
    else {
        Write-StatusMessage "Navegador não será aberto (parâmetro -NoBrowser)" -Type "Info"
    }

    # 6. Abrir log viewer (se disponível e não desabilitado)
    if (-not $NoLog -and $cmtraceAvailable) {
        Start-Sleep -Seconds 1
        Open-LogViewer -LogPath $logFile
    }
    elseif ($NoLog) {
        Write-StatusMessage "Log viewer não será aberto (parâmetro -NoLog)" -Type "Info"
    }

    # 7. Exibir informações finais
    Show-APIInfo -PortNumber $Port -ProcessId $processId

    Write-StatusMessage "Inicialização concluída com sucesso!" -Type "Success"
    Write-StatusMessage "Pressione Ctrl+C para encerrar o servidor..." -Type "Info"

    # Manter o script rodando para capturar Ctrl+C
    try {
        while ($true) {
            Start-Sleep -Seconds 5

            # Verificar se o processo ainda está rodando
            $stillRunning = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if (-not $stillRunning) {
                Write-StatusMessage "Servidor parou inesperadamente!" -Type "Error"
                break
            }
        }
    }
    catch {
        Write-StatusMessage "Encerrando servidor..." -Type "Info"
    }
}
catch {
    Write-StatusMessage "Erro durante inicialização: $_" -Type "Error"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
finally {
    Write-StatusMessage "Script finalizado" -Type "Info"
}
