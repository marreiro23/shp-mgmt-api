#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Testa validação Joi no config.js

.DESCRIPTION
    Script para testar a implementação da validação de schema com Joi
#>

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           TESTE DE VALIDAÇÃO JOI - CONFIG.JS                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Teste 1: Validação do módulo config.js
Write-Host "🔍 Teste 1: Validando módulo config.js..." -ForegroundColor Yellow
try {
    Push-Location "C:\REPOSITORIO\PSAppDeployToolkit\cves"
    $output = node api/config/config.js 2>&1 | Out-String

    if ($output -match "validada com sucesso" -or $output -match "CONFIG VALIDATION.*sucesso") {
        Write-Host "   ✅ PASSOU: Configuração validada com sucesso!" -ForegroundColor Green
        $test1 = $true
    } elseif ($output -match "Erros encontrados") {
        Write-Host "   ❌ FALHOU: Erros de validação encontrados:" -ForegroundColor Red
        $output -split "`n" | Where-Object { $_ -match "^\s+\d+\." } | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Red
        }
        $test1 = $false
    } else {
        Write-Host "   ⚠️  AVISO: Output não esperado" -ForegroundColor Yellow
        Write-Host $output
        $test1 = $false
    }
} catch {
    Write-Host "   ❌ ERRO: $_" -ForegroundColor Red
    $test1 = $false
} finally {
    Pop-Location
}

# Teste 2: Verificar dependência Joi instalada
Write-Host "`n🔍 Teste 2: Verificando instalação do Joi..." -ForegroundColor Yellow
try {
    Push-Location "C:\REPOSITORIO\PSAppDeployToolkit\cves\api"
    $packageJson = Get-Content "package.json" | ConvertFrom-Json

    if ($packageJson.dependencies.joi) {
        Write-Host "   ✅ PASSOU: Joi versão $($packageJson.dependencies.joi) instalado" -ForegroundColor Green
        $test2 = $true
    } else {
        Write-Host "   ❌ FALHOU: Joi não encontrado no package.json" -ForegroundColor Red
        $test2 = $false
    }
} catch {
    Write-Host "   ❌ ERRO: $_" -ForegroundColor Red
    $test2 = $false
} finally {
    Pop-Location
}

# Teste 3: Verificar schema definido no config.js
Write-Host "`n🔍 Teste 3: Verificando schema Joi no config.js..." -ForegroundColor Yellow
try {
    $configContent = Get-Content "C:\REPOSITORIO\PSAppDeployToolkit\cves\api\config\config.js" -Raw

    if ($configContent -match "import Joi from 'joi'") {
        Write-Host "   ✅ PASSOU: Import do Joi encontrado" -ForegroundColor Green
    } else {
        Write-Host "   ❌ FALHOU: Import do Joi não encontrado" -ForegroundColor Red
    }

    if ($configContent -match "const configSchema = Joi\.object\({") {
        Write-Host "   ✅ PASSOU: Schema Joi definido" -ForegroundColor Green
    } else {
        Write-Host "   ❌ FALHOU: Schema Joi não definido" -ForegroundColor Red
    }

    if ($configContent -match "configSchema\.validate\(config") {
        Write-Host "   ✅ PASSOU: Validação implementada" -ForegroundColor Green
        $test3 = $true
    } else {
        Write-Host "   ❌ FALHOU: Validação não implementada" -ForegroundColor Red
        $test3 = $false
    }
} catch {
    Write-Host "   ❌ ERRO: $_" -ForegroundColor Red
    $test3 = $false
}

# Teste 4: Verificar níveis de log aceitos
Write-Host "`n🔍 Teste 4: Verificando níveis de log no schema..." -ForegroundColor Yellow
try {
    $configContent = Get-Content "C:\REPOSITORIO\PSAppDeployToolkit\cves\api\config\config.js" -Raw

    if ($configContent -match "LOG_LEVEL.*\.valid\('error', 'warn', 'info', 'verbose', 'debug', 'silly'\)") {
        Write-Host "   ✅ PASSOU: Todos os níveis de log aceitos (error, warn, info, verbose, debug, silly)" -ForegroundColor Green
        $test4 = $true
    } elseif ($configContent -match "LOG_LEVEL.*\.valid\(") {
        Write-Host "   ⚠️  AVISO: Níveis de log limitados" -ForegroundColor Yellow
        $test4 = $false
    } else {
        Write-Host "   ❌ FALHOU: Validação de LOG_LEVEL não encontrada" -ForegroundColor Red
        $test4 = $false
    }
} catch {
    Write-Host "   ❌ ERRO: $_" -ForegroundColor Red
    $test4 = $false
}

# Teste 5: Verificar caminho do .env
Write-Host "`n🔍 Teste 5: Verificando caminho do .env..." -ForegroundColor Yellow
try {
    $configContent = Get-Content "C:\REPOSITORIO\PSAppDeployToolkit\cves\api\config\config.js" -Raw

    if ($configContent -match "join\(__dirname, '\.\.', '\.env'\)") {
        Write-Host "   ✅ PASSOU: Caminho correto do .env (api/.env)" -ForegroundColor Green
        $test5 = $true
    } elseif ($configContent -match "join\(__dirname, '\.env'\)") {
        Write-Host "   ❌ FALHOU: Caminho incorreto do .env (config/.env)" -ForegroundColor Red
        $test5 = $false
    } else {
        Write-Host "   ⚠️  AVISO: Caminho do .env não identificado" -ForegroundColor Yellow
        $test5 = $false
    }
} catch {
    Write-Host "   ❌ ERRO: $_" -ForegroundColor Red
    $test5 = $false
}

# Resumo
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      RESUMO DOS TESTES                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$totalTests = 5
$passedTests = @($test1, $test2, $test3, $test4, $test5) | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count

Write-Host "📊 Testes executados: $totalTests" -ForegroundColor White
Write-Host "✅ Testes aprovados:  $passedTests" -ForegroundColor Green
Write-Host "❌ Testes falhados:   $($totalTests - $passedTests)" -ForegroundColor Red
Write-Host "📈 Taxa de sucesso:   $([math]::Round(($passedTests / $totalTests) * 100, 2))%" -ForegroundColor Cyan

if ($passedTests -eq $totalTests) {
    Write-Host "`n🎉 SUCESSO: Validação Joi implementada corretamente!`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  ATENÇÃO: Alguns testes falharam. Revisar implementação.`n" -ForegroundColor Yellow
    exit 1
}
