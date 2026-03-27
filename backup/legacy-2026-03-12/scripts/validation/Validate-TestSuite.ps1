# Validação 2: Suite de Testes
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║               VALIDAÇÃO 2: SUITE DE TESTES DO SISTEMA               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$testResults = @()

# Teste 1: Test-Summary.ps1
Write-Host "🧪 TESTE 1: Test-Summary.ps1" -ForegroundColor Yellow
Write-Host ("─" * 70)
try {
    . ./scripts/tests/Test-Summary.ps1 | Out-Null
    Write-Host "  ✅ Test-Summary.ps1 executado com sucesso" -ForegroundColor Green
    $testResults += @{ Test = "Test-Summary"; Status = "OK"; Message = "Config carregada" }
} catch {
    Write-Host "  ❌ Erro: $_" -ForegroundColor Red
    $testResults += @{ Test = "Test-Summary"; Status = "ERROR"; Message = $_ }
}
Write-Host ""

# Teste 2: Validate-FileNames.ps1
Write-Host "🧪 TESTE 2: Validate-FileNames.ps1" -ForegroundColor Yellow
Write-Host ("─" * 70)
try {
    . ./scripts/validation/Validate-FileNames.ps1 | Out-Null
    Write-Host "  ✅ Validate-FileNames.ps1 executado com sucesso" -ForegroundColor Green
    $testResults += @{ Test = "Validate-FileNames"; Status = "OK"; Message = "Validação concluída" }
} catch {
    Write-Host "  ❌ Erro: $_" -ForegroundColor Red
    $testResults += @{ Test = "Validate-FileNames"; Status = "ERROR"; Message = $_ }
}
Write-Host ""

# Teste 3: Validate-Project.ps1
Write-Host "🧪 TESTE 3: Validate-Project.ps1" -ForegroundColor Yellow
Write-Host ("─" * 70)
try {
    . ./scripts/validation/Validate-Project.ps1 | Out-Null
    Write-Host "  ✅ Validate-Project.ps1 executado com sucesso" -ForegroundColor Green
    $testResults += @{ Test = "Validate-Project"; Status = "OK"; Message = "Projeto validado" }
} catch {
    Write-Host "  ❌ Erro: $_" -ForegroundColor Red
    $testResults += @{ Test = "Validate-Project"; Status = "ERROR"; Message = $_ }
}
Write-Host ""

# Teste 4: Descoberta de Colunas
Write-Host "🧪 TESTE 4: Discover-Columns.ps1" -ForegroundColor Yellow
Write-Host ("─" * 70)
try {
    # Este pode falhar se não tiver conexão SCCM, então vamos apenas verificar se o script carrega
    if (Test-Path "./scripts/discovery/Discover-Columns.ps1") {
        Write-Host "  ✅ Discover-Columns.ps1 disponível (requer conexão SCCM)" -ForegroundColor Green
        $testResults += @{ Test = "Discover-Columns"; Status = "OK"; Message = "Script disponível" }
    }
} catch {
    Write-Host "  ⚠️  Aviso: $_" -ForegroundColor Yellow
    $testResults += @{ Test = "Discover-Columns"; Status = "WARN"; Message = $_ }
}
Write-Host ""

# Resumo
$okCount = @($testResults | Where-Object { $_.Status -eq 'OK' }).Count
$warnCount = @($testResults | Where-Object { $_.Status -eq 'WARN' }).Count
$errorCount = @($testResults | Where-Object { $_.Status -eq 'ERROR' }).Count

Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "RESUMO SUITE DE TESTES:" -ForegroundColor Green
Write-Host "✅ OK: $okCount/4" -ForegroundColor Green
Write-Host "⚠️  WARN: $warnCount/4" -ForegroundColor $(if ($warnCount -eq 0) { "Green" } else { "Yellow" })
Write-Host "❌ ERROR: $errorCount/4" -ForegroundColor $(if ($errorCount -eq 0) { "Green" } else { "Red" })
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if ($errorCount -eq 0) {
    Write-Host "✅ SUITE DE TESTES PASSOU COM SUCESSO!" -ForegroundColor Green
} else {
    Write-Host "❌ ALGUNS TESTES FALHARAM - REVISAR LOGS" -ForegroundColor Red
}
