<#
.SYNOPSIS
    Script master para gerenciamento completo de CVEs

.DESCRIPTION
    Interface principal para executar todas as operacoes de processamento,
    visualizacao e exportacao de dados de vulnerabilidades CVE

.EXAMPLE
    .\Start-CVEManagement.ps1

.NOTES
    Autor: CVE Remediation Team
    Data: 2026-01-08
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ║           CVE REMEDIATION MANAGEMENT SYSTEM                   ║" -ForegroundColor Cyan
    Write-Host "  ║                    Version 1.0.0                              ║" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ║     Sistema completo de gerenciamento de vulnerabilidades    ║" -ForegroundColor Cyan
    Write-Host "  ║                                                               ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-MainMenu {
    Write-Host ""
    Write-Host "  ┌───────────────────────────────────────────────────────────────┐" -ForegroundColor Gray
    Write-Host "  │ MENU PRINCIPAL                                                │" -ForegroundColor Gray
    Write-Host "  ├───────────────────────────────────────────────────────────────┤" -ForegroundColor Gray
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  │  [1] Processar Dados (ETL)                                    │" -ForegroundColor White
    Write-Host "  │      └─ Converte dados brutos para JSON estruturado          │" -ForegroundColor Gray
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  │  [2] Dashboard Interativo                                     │" -ForegroundColor White
    Write-Host "  │      └─ Visualiza e explora dados de vulnerabilidades        │" -ForegroundColor Gray
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  │  [3] Exportar Dados                                           │" -ForegroundColor White
    Write-Host "  │      └─ Exporta para CSV, XML, YAML                          │" -ForegroundColor Gray
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  │  [4] Relatorios Rapidos                                       │" -ForegroundColor White
    Write-Host "  │      └─ Gera relatorios consolidados                         │" -ForegroundColor Gray
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  │  [5] Gerar Plano de Remediacao                                │" -ForegroundColor White
    Write-Host "  │      └─ Cria plano de acao para correcao                     │" -ForegroundColor Gray
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  │  [6] Configuracoes                                            │" -ForegroundColor White
    Write-Host "  │      └─ Ajusta parametros do sistema                         │" -ForegroundColor Gray
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  │  [H] Ajuda                                                    │" -ForegroundColor White
    Write-Host "  │  [Q] Sair                                                     │" -ForegroundColor White
    Write-Host "  │                                                               │" -ForegroundColor Gray
    Write-Host "  └───────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Selecione uma opcao: " -NoNewline -ForegroundColor Yellow
}

function Invoke-ETLProcess {
    Show-Banner
    Write-Host "  PROCESSAMENTO ETL DE DADOS" -ForegroundColor Cyan
    Write-Host "  ══════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""

    $etlScript = Join-Path $scriptPath "Parse-CVEData.ps1"

    if (Test-Path $etlScript) {
        & $etlScript
    }
    else {
        Write-Host "  [ERRO] Script Parse-CVEData.ps1 nao encontrado!" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "  Pressione qualquer tecla para continuar..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Invoke-Dashboard {
    Show-Banner
    Write-Host "  Iniciando Dashboard Interativo..." -ForegroundColor Yellow
    Write-Host ""

    $dashboardScript = Join-Path $scriptPath "Show-CVEDashboard.ps1"

    if (Test-Path $dashboardScript) {
        & $dashboardScript
    }
    else {
        Write-Host "  [ERRO] Script Show-CVEDashboard.ps1 nao encontrado!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Pressione qualquer tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Invoke-ExportData {
    Show-Banner
    Write-Host "  EXPORTACAO DE DADOS" -ForegroundColor Cyan
    Write-Host "  ══════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Selecione o formato de exportacao:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] CSV - Para Excel e analise tabular"
    Write-Host "  [2] XML - Para integracao com sistemas corporativos"
    Write-Host "  [3] YAML - Para configuracao e automacao"
    Write-Host "  [4] Todos os formatos"
    Write-Host "  [0] Voltar"
    Write-Host ""
    Write-Host "  Opcao: " -NoNewline -ForegroundColor Yellow
    $choice = Read-Host

    $formatMap = @{
        '1' = 'CSV'
        '2' = 'XML'
        '3' = 'YAML'
        '4' = 'All'
    }

    if ($formatMap.ContainsKey($choice)) {
        $exportScript = Join-Path $scriptPath "Export-CVEData.ps1"

        if (Test-Path $exportScript) {
            & $exportScript -Format $formatMap[$choice]
        }
        else {
            Write-Host "  [ERRO] Script Export-CVEData.ps1 nao encontrado!" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "  Pressione qualquer tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Show-QuickReports {
    Show-Banner
    Write-Host "  RELATORIOS RAPIDOS" -ForegroundColor Cyan
    Write-Host "  ══════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""

    $jsonPath = Join-Path (Split-Path $scriptPath -Parent) "json"

    if (-not (Test-Path $jsonPath)) {
        Write-Host "  [AVISO] Nenhum dado processado encontrado." -ForegroundColor Yellow
        Write-Host "  Execute a opcao [1] Processar Dados primeiro." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Pressione qualquer tecla para continuar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # Carregar dados
    $jsonFiles = Get-ChildItem -Path $jsonPath -Filter "*.json"
    $allData = @()

    foreach ($file in $jsonFiles) {
        $data = Get-Content $file.FullName | ConvertFrom-Json
        $allData += $data
    }

    # Estatisticas gerais
    $totalApps = $allData.Count
    $totalDevices = ($allData | Measure-Object -Property totalAffectedDevices -Sum).Sum
    $bySeverity = $allData | Group-Object severity

    Write-Host "  RESUMO EXECUTIVO" -ForegroundColor Yellow
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Total de Aplicacoes Vulneraveis: " -NoNewline
    Write-Host $totalApps -ForegroundColor Red
    Write-Host "  Total de Dispositivos Afetados: " -NoNewline
    Write-Host $totalDevices -ForegroundColor Red
    Write-Host ""

    Write-Host "  Distribuicao por Severidade:" -ForegroundColor Yellow
    foreach ($group in ($bySeverity | Sort-Object {
        switch ($_.Name) { 'Critical' {1} 'High' {2} 'Medium' {3} default {4} }
    })) {
        $color = switch ($group.Name) {
            'Critical' { 'Red' }
            'High' { 'Yellow' }
            'Medium' { 'Cyan' }
            default { 'White' }
        }
        $devices = ($group.Group | Measure-Object -Property totalAffectedDevices -Sum).Sum
        Write-Host "    $($group.Name.PadRight(10)): " -NoNewline
        Write-Host "$($group.Count) aplicacoes, $devices dispositivos" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  Top 5 Aplicacoes Mais Afetadas:" -ForegroundColor Yellow
    $top5 = $allData | Sort-Object -Property totalAffectedDevices -Descending | Select-Object -First 5
    $rank = 1
    foreach ($app in $top5) {
        Write-Host "    $rank. $($app.applicationName)" -ForegroundColor White
        Write-Host "       $($app.totalAffectedDevices) dispositivos | Severidade: $($app.severity)" -ForegroundColor Gray
        $rank++
    }

    Write-Host ""
    Write-Host "  Pressione qualquer tecla para continuar..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-Help {
    Show-Banner
    Write-Host "  AJUDA - CVE REMEDIATION MANAGEMENT SYSTEM" -ForegroundColor Cyan
    Write-Host "  ══════════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""

    Write-Host "  FLUXO DE TRABALHO RECOMENDADO:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Processar Dados (ETL)" -ForegroundColor White
    Write-Host "     - Converte o arquivo cves-tsv.txt em arquivos JSON estruturados"
    Write-Host "     - Gera um arquivo JSON por aplicacao vulneravel"
    Write-Host "     - Cria relatorios consolidados automaticamente"
    Write-Host ""
    Write-Host "  2. Dashboard Interativo" -ForegroundColor White
    Write-Host "     - Explore os dados visualmente"
    Write-Host "     - Filtre por severidade, aplicacao ou dispositivo"
    Write-Host "     - Identifique prioridades de remediacao"
    Write-Host ""
    Write-Host "  3. Exportar Dados" -ForegroundColor White
    Write-Host "     - CSV: Para analise em Excel ou importacao em ferramentas BI"
    Write-Host "     - XML: Para integracao com sistemas corporativos (ServiceNow, etc)"
    Write-Host "     - YAML: Para automacao e configuracao de ferramentas DevOps"
    Write-Host ""
    Write-Host "  4. Gerar Plano de Remediacao" -ForegroundColor White
    Write-Host "     - Cria plano de acao baseado em prioridades"
    Write-Host "     - Sugere ordem de remediacao por severidade e impacto"
    Write-Host ""
    Write-Host "  ──────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ESTRUTURA DE PASTAS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  cves/"
    Write-Host "  ├── scripts/          Scripts de processamento"
    Write-Host "  ├── json/             Arquivos JSON por aplicacao"
    Write-Host "  ├── exports/          Exportacoes (CSV, XML, YAML)"
    Write-Host "  ├── reports/          Relatorios consolidados"
    Write-Host "  └── raw/              Dados originais (backup)"
    Write-Host ""
    Write-Host "  ──────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  SCRIPTS DISPONIVEIS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  • Parse-CVEData.ps1         - Processamento ETL"
    Write-Host "  • Show-CVEDashboard.ps1     - Dashboard interativo"
    Write-Host "  • Export-CVEData.ps1        - Exportacao multi-formato"
    Write-Host "  • Start-CVEManagement.ps1   - Este script (menu principal)"
    Write-Host ""
    Write-Host "  Pressione qualquer tecla para continuar..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# MAIN
try {
    do {
        Show-Banner

        # Verificar status dos dados
        $jsonPath = Join-Path (Split-Path $scriptPath -Parent) "json"
        if (Test-Path $jsonPath) {
            $jsonCount = (Get-ChildItem -Path $jsonPath -Filter "*.json" -ErrorAction SilentlyContinue).Count
            if ($jsonCount -gt 0) {
                Write-Host "  Status: " -NoNewline
                Write-Host "$jsonCount arquivos JSON processados" -ForegroundColor Green
            }
            else {
                Write-Host "  Status: " -NoNewline
                Write-Host "Nenhum dado processado. Execute opcao [1] primeiro." -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "  Status: " -NoNewline
            Write-Host "Aguardando processamento inicial..." -ForegroundColor Yellow
        }

        Show-MainMenu
        $choice = Read-Host

        switch ($choice.ToUpper()) {
            '1' { Invoke-ETLProcess }
            '2' { Invoke-Dashboard }
            '3' { Invoke-ExportData }
            '4' { Show-QuickReports }
            '5' {
                Write-Host ""
                Write-Host "  Funcionalidade em desenvolvimento..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
            '6' {
                Write-Host ""
                Write-Host "  Funcionalidade em desenvolvimento..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
            'H' { Show-Help }
            'Q' { break }
            default {
                Write-Host ""
                Write-Host "  Opcao invalida. Tente novamente." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($choice.ToUpper() -ne 'Q')

    Show-Banner
    Write-Host "  Obrigado por usar o CVE Remediation Management System!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Sistema desenvolvido para PSAppDeployToolkit Project" -ForegroundColor Gray
    Write-Host "  Version 1.0.0 - 2026-01-08" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}
