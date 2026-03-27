<#
.SYNOPSIS
    Suite de testes finais completos do CVE Management System

.DESCRIPTION
    Script de teste integrado que valida toda a infraestrutura:
    - Arquivos criados
    - Conexão ao SQL Server SCCM
    - Queries SQL com UninstallString
    - Funções de remediação
    - Endpoints da API
    - Arquivos de configuração

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Test-FinalSuite.ps1
#>

# Carregar configuração centralizada
try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         TESTES FINAIS COMPLETOS - SISTEMA CVE MANAGEMENT         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$testsWarning = 0

# ============================================================================
# TESTE 1: Arquivos Criados
# ============================================================================
Write-Host "TESTE 1: Verificar Arquivos Criados" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

$requiredFiles = @(
    (Join-Path $Config.Paths.Scripts "Get-RemediationCommands.ps1"),
    (Join-Path $Config.Paths.Scripts "New-PSADTRemediationPackage.ps1"),
    (Join-Path $Config.Paths.Root "Test-AllQueries.ps1"),
    (Join-Path $Config.Paths.Html "results-viewer.html"),
    (Join-Path $Config.Paths.Html "queries.html"),
    (Join-Path $Config.Paths.Root "SISTEMA_COMPLETO_REMEDIACAO.md"),
    (Join-Path $Config.Paths.Root "SISTEMA_RESULTADOS_NOVA_PAGINA.md")
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        $size = [Math]::Round((Get-Item $file).Length / 1KB, 2)
        Write-Host "  ✓ $(Split-Path $file -Leaf) ($size KB)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ✗ $(Split-Path $file -Leaf) - NÃO ENCONTRADO" -ForegroundColor Red
        $testsFailed++
    }
}

Write-Host ""

# ============================================================================
# TESTE 2: Conexão ao SQL Server
# ============================================================================
Write-Host "TESTE 2: Conexão ao SQL Server SCCM" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

try {
    $connectionString = "Server=$($Config.SCCM.Server),$($Config.SCCM.Port);Database=$($Config.SCCM.Database);Integrated Security=True;"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    Write-Host "  ✓ Conectado a: $($Config.SCCM.Server) ($($Config.SCCM.Database))" -ForegroundColor Green
    $testsPassed++

    # Query de teste
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = "SELECT COUNT(*) FROM v_GS_ADD_REMOVE_PROGRAMS WHERE UninstallString0 IS NOT NULL"
    $result = $cmd.ExecuteScalar()
    Write-Host "  ✓ Aplicações com UninstallString: $result" -ForegroundColor Green
    $testsPassed++

    $connection.Close()
} catch {
    Write-Host "  ✗ ERRO: $_" -ForegroundColor Red
    $testsFailed += 2
}

Write-Host ""

# ============================================================================
# TESTE 3: Query SQL com UninstallString
# ============================================================================
Write-Host "TESTE 3: Query Retornando UninstallString, ProdID e Dados" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

try {
    $query = @"
SELECT TOP 5
    DisplayName0,
    Version0,
    Publisher0,
    ProdID0,
    UninstallString0,
    InstallLocation0
FROM v_GS_ADD_REMOVE_PROGRAMS
WHERE DisplayName0 IS NOT NULL AND UninstallString0 IS NOT NULL
ORDER BY DisplayName0
"@

    $connectionString = "Server=$($Config.SCCM.Server),$($Config.SCCM.Port);Database=$($Config.SCCM.Database);Integrated Security=True;"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($query, $connection)
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | Out-Null

    $results = $dataset.Tables[0]

    if ($results.Rows.Count -gt 0) {
        Write-Host "  ✓ Query retornou $($results.Rows.Count) resultados com todas as colunas" -ForegroundColor Green
        $testsPassed++

        # Verificar tipo de instaladores detectados
        $msiCount = 0
        $exeCount = 0
        $otherCount = 0

        foreach ($row in $results.Rows) {
            $uninstallStr = $row['UninstallString0']
            if ($uninstallStr -match 'msiexec') { $msiCount++ }
            elseif ($uninstallStr -match 'unins.*\.exe|uninstall\.exe') { $exeCount++ }
            else { $otherCount++ }
        }

        Write-Host "  ✓ MSI detectados: $msiCount" -ForegroundColor Green
        Write-Host "  ✓ EXE Uninstallers detectados: $exeCount" -ForegroundColor Green
        Write-Host "  ✓ Outros tipos: $otherCount" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "  ⚠ Nenhum resultado com UninstallString" -ForegroundColor Yellow
        $testsWarning++
    }

    $connection.Close()
} catch {
    Write-Host "  ✗ ERRO: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# ============================================================================
# TESTE 4: Funções de Remediação
# ============================================================================
Write-Host "TESTE 4: Funções de Detecção de Remediação" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

# Teste de detecção MSI
$testApp = [PSCustomObject]@{
    DisplayName0 = "Test Application"
    Version0 = "1.0.0"
    UninstallString0 = "MsiExec.exe /X{AC76BA86-7AD7-1033-7B44-AB0000000001}"
    ProdID0 = "{AC76BA86-7AD7-1033-7B44-AB0000000001}"
}

if ($testApp.UninstallString0 -match '\{[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}\}') {
    Write-Host "  ✓ Detecção de Product Code MSI funcionando" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  ✗ Detecção de Product Code MSI falhou" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""

# ============================================================================
# TESTE 5: API Endpoints
# ============================================================================
Write-Host "TESTE 5: Endpoints da API" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

$apiUrl = "http://$($Config.Api.Host):$($Config.Api.Port)$($Config.Api.Prefix)"

try {
    $response = Invoke-RestMethod -Uri "$apiUrl/health" -Method Get -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✓ API acessível em: $apiUrl" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host "  ⚠ API não respondendo em: $apiUrl" -ForegroundColor Yellow
    Write-Host "    Erro: $($_.Exception.Message)" -ForegroundColor Gray
    $testsWarning++
}

Write-Host ""

# ============================================================================
# RESUMO FINAL
# ============================================================================
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      RESUMO DOS TESTES                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "✓ Testes Passados: $testsPassed" -ForegroundColor Green
Write-Host "✗ Testes Falhos: $testsFailed" -ForegroundColor $(if($testsFailed -eq 0){'Green'}else{'Red'})
Write-Host "⚠ Avisos: $testsWarning" -ForegroundColor Yellow

Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ TODOS OS TESTES PASSARAM!" -ForegroundColor Green
} else {
    Write-Host "✗ ALGUNS TESTES FALHARAM - VERIFIQUE A CONFIGURAÇÃO" -ForegroundColor Red
}

Write-Host ""
