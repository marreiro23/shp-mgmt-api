# Validação 1: Verificar carregamento de config
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       VALIDAÇÃO 1: CARREGAMENTO DE CONFIG EM TODOS OS SCRIPTS      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$categories = @('tests', 'validation', 'discovery')
$results = @()

foreach ($cat in $categories) {
    $path = "scripts/$cat"
    $files = Get-ChildItem -Path $path -Filter "*.ps1" -ErrorAction SilentlyContinue

    if ($files) {
        Write-Host "📁 Categoria: $cat" -ForegroundColor Yellow
        Write-Host ("─" * 70)

        foreach ($file in $files) {
            try {
                $content = Get-Content $file.FullName -Raw

                if ($content -match '\$Config = & \(Join-Path') {
                    Write-Host "  ✅ $($file.Name)" -ForegroundColor Green
                    $results += @{ File = $file.Name; Category = $cat; Status = 'OK' }
                } else {
                    Write-Host "  ⚠️  $($file.Name) - Sem carregamento de config" -ForegroundColor Yellow
                    $results += @{ File = $file.Name; Category = $cat; Status = 'WARN' }
                }
            }
            catch {
                Write-Host "  ❌ $($file.Name) - ERRO: $_" -ForegroundColor Red
                $results += @{ File = $file.Name; Category = $cat; Status = 'ERROR' }
            }
        }
    }

    Write-Host ""
}

# Resumo
$okCount = @($results | Where-Object { $_.Status -eq 'OK' }).Count
$warnCount = @($results | Where-Object { $_.Status -eq 'WARN' }).Count
$errorCount = @($results | Where-Object { $_.Status -eq 'ERROR' }).Count

Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "RESUMO VALIDAÇÃO DE CONFIG:" -ForegroundColor Green
Write-Host "✅ OK: $okCount" -ForegroundColor Green
Write-Host "⚠️  WARN: $warnCount" -ForegroundColor $(if ($warnCount -eq 0) { "Green" } else { "Yellow" })
Write-Host "❌ ERROR: $errorCount" -ForegroundColor $(if ($errorCount -eq 0) { "Green" } else { "Red" })
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if ($errorCount -eq 0 -and $warnCount -eq 0) {
    Write-Host "✅ TODOS OS SCRIPTS CARREGAM CONFIG CORRETAMENTE!" -ForegroundColor Green
}
