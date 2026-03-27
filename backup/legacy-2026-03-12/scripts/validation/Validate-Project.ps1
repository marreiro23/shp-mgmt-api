<#
.SYNOPSIS
    Valida configurações e dependências do projeto CVE Management

.DESCRIPTION
    Verifica todas as configurações, pastas, arquivos e dependências necessárias
    para o correto funcionamento do sistema.

    Usa configurações centralizadas de cves/config/config.json

.EXAMPLE
    .\Validate-Project.ps1

.NOTES
    Versão: 2.0
    Data: Janeiro 2026
    Configuração: cves/config/config.json
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# ============================================================================
# CARREGAR CONFIGURAÇÃO
# ============================================================================

try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         VALIDAÇÃO DO PROJETO CVE MANAGEMENT v2.0              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Usando configuração: $(Join-Path $Config.ProjectRoot 'config' 'config.json')" -ForegroundColor Gray
Write-Host ""

$issues = @()

# Verificar pastas do projeto (baseadas em config)
Write-Host "📁 Verificando estrutura de pastas..." -ForegroundColor Yellow
Write-Host ""

$foldersToCheck = @(
    @{ Path = $Config.Paths.Api; Name = "api" }
    @{ Path = $Config.Paths.Web; Name = "web" }
    @{ Path = $Config.Paths.Scripts; Name = "scripts" }
    @{ Path = (Join-Path $Config.ProjectRoot "config"); Name = "config" }
    @{ Path = $Config.Paths.Json; Name = "json" }
    @{ Path = $Config.Paths.Exports; Name = "exports" }
    @{ Path = $Config.Paths.Reports; Name = "reports" }
    @{ Path = $Config.Paths.Logs; Name = "logs" }
    @{ Path = $Config.Paths.Docs; Name = "docs" }
)

foreach ($folder in $foldersToCheck) {
    if (Test-Path $folder.Path) {
        Write-Host "  ✅ $($folder.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($folder.Name) (ausente)" -ForegroundColor Red
        $issues += "Pasta ausente: $($folder.Name) - $($folder.Path)"
    }
}

Write-Host ""

# Verificar arquivo de configuração central
Write-Host "⚙️  Verificando configuração central..." -ForegroundColor Yellow
Write-Host ""

$configFile = Join-Path $Config.ProjectRoot "config" "config.json"
if (Test-Path $configFile) {
    Write-Host "  ✅ config.json (encontrado)" -ForegroundColor Green

    # Validar que está em JSON válido
    try {
        $jsonContent = Get-Content $configFile | ConvertFrom-Json
        Write-Host "  ✅ config.json (JSON válido)" -ForegroundColor Green

        # Verificar seções obrigatórias
        $requiredSections = @('application', 'paths', 'api', 'logging', 'sccm', 'intune')
        foreach ($section in $requiredSections) {
            if ($jsonContent.PSObject.Properties.Name -contains $section) {
                Write-Host "     ✅ Seção [$section]" -ForegroundColor Gray
            } else {
                Write-Host "     ❌ Seção [$section] (ausente)" -ForegroundColor Red
                $issues += "config.json: Seção [$section] não encontrada"
            }
        }
    }
    catch {
        Write-Host "  ❌ config.json (JSON inválido)" -ForegroundColor Red
        $issues += "config.json contém JSON inválido: $_"
    }
} else {
    Write-Host "  ❌ config.json (ausente)" -ForegroundColor Red
    $issues += "Arquivo ausente: config.json em $configFile"
}

Write-Host ""

# Verificar arquivos da API
Write-Host "🌐 Verificando arquivos da API..." -ForegroundColor Yellow
Write-Host ""

$apiFiles = @(
    @{ Path = (Join-Path $Config.Paths.Api "package.json"); Name = "package.json" }
    @{ Path = (Join-Path $Config.Paths.Api "server.js"); Name = "server.js" }
    @{ Path = (Join-Path $Config.Paths.Api "config" "config.js"); Name = "config.js" }
)

foreach ($file in $apiFiles) {
    if (Test-Path $file.Path) {
        Write-Host "  ✅ $($file.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($file.Name) (ausente)" -ForegroundColor Red
        $issues += "Arquivo ausente: $($file.Name)"
    }
}

Write-Host ""

# Verificar controladores
Write-Host "🎮 Verificando controladores..." -ForegroundColor Yellow
Write-Host ""

$controllers = @(
    'cveController.js',
    'exportController.js',
    'psadtController.js',
    'sccmController.js',
    'tenableController.js',
    'reportsController.js'
)

foreach ($controller in $controllers) {
    $path = Join-Path $Config.Paths.Api "controllers" $controller
    if (Test-Path $path) {
        Write-Host "  ✅ $controller" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $controller (ausente)" -ForegroundColor Red
        $issues += "Controller ausente: $controller"
    }
}

Write-Host ""

# Verificar rotas
Write-Host "🛣️  Verificando rotas..." -ForegroundColor Yellow
Write-Host ""

$routes = @(
    'cve.routes.js',
    'export.routes.js',
    'psadt.routes.js',
    'sccm.routes.js',
    'tenable.routes.js',
    'reports.routes.js',
    'intune.routes.js'
)

foreach ($route in $routes) {
    $path = Join-Path $Config.Paths.Api "routes" $route
    if (Test-Path $path) {
        Write-Host "  ✅ $route" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $route (ausente)" -ForegroundColor Red
        $issues += "Rota ausente: $route"
    }
}

Write-Host ""

# Verificar dependências Node
Write-Host "📦 Verificando dependências Node.js..." -ForegroundColor Yellow
Write-Host ""

$nodeModulesPath = Join-Path $Config.Paths.Api "node_modules"
if (Test-Path $nodeModulesPath) {
    Write-Host "  ✅ node_modules instalado" -ForegroundColor Green

    $requiredModules = @('express', 'cors', 'helmet', 'morgan', 'express-rate-limit')
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $nodeModulesPath $module
        if (Test-Path $modulePath) {
            Write-Host "     ✅ $module" -ForegroundColor Gray
        } else {
            Write-Host "     ❌ $module (ausente)" -ForegroundColor Red
            $issues += "Módulo Node ausente: $module"
        }
    }
} else {
    Write-Host "  ❌ node_modules não instalado" -ForegroundColor Red
    $issues += "Execute 'npm install' em $($Config.Paths.Api)"
}

Write-Host ""

# Verificar scripts PowerShell
Write-Host "📜 Verificando scripts PowerShell..." -ForegroundColor Yellow
Write-Host ""

# Scripts em cada categoria
$scriptCategories = @{
    'runtime' = @('Start-API.ps1', 'Start-IntegratedSystem.ps1')
    'tests' = @('Test-System.ps1')
    'validation' = @('Validate-Project.ps1')
    'discovery' = @()
    'common' = @('Get-ProjectConfig.ps1')
}

foreach ($category in $scriptCategories.Keys) {
    $categoryPath = Join-Path $Config.Paths.Scripts $category

    if (Test-Path $categoryPath) {
        Write-Host "  ✅ scripts/$category/" -ForegroundColor Green

        foreach ($script in $scriptCategories[$category]) {
            $scriptPath = Join-Path $categoryPath $script
            if (Test-Path $scriptPath) {
                Write-Host "     ✅ $script" -ForegroundColor Gray
            } else {
                Write-Host "     ⚠️  $script (esperado, não encontrado)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  ⚠️  scripts/$category/ (não existe ainda)" -ForegroundColor Yellow
    }
}

Write-Host ""

# Verificar configurações SCCM
Write-Host "🗄️  Verificando configuração SCCM..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  • Servidor: $($Config.SCCM.Server)" -ForegroundColor Gray
Write-Host "  • Banco de dados: $($Config.SCCM.Database)" -ForegroundColor Gray
Write-Host "  • Porta: $($Config.SCCM.Port)" -ForegroundColor Gray
Write-Host "  • Timeout: $($Config.SCCM.ConnectionTimeout) segundos" -ForegroundColor Gray

Write-Host ""

# Verificar configurações API
Write-Host "🌐 Verificando configuração API..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  • Host: $($Config.Api.Host)" -ForegroundColor Gray
Write-Host "  • Porta: $($Config.Api.Port)" -ForegroundColor Gray
Write-Host "  • Versão: $($Config.Api.Version)" -ForegroundColor Gray
Write-Host "  • Prefixo: $($Config.Api.Prefix)" -ForegroundColor Gray

Write-Host ""

# Resumo
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                      RESUMO DA VALIDAÇÃO                       ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

if ($issues.Count -eq 0) {
    Write-Host "✅ NENHUM PROBLEMA ENCONTRADO!" -ForegroundColor Green
    Write-Host ""
    Write-Host "O projeto está corretamente configurado e pronto para uso." -ForegroundColor Green
    Write-Host ""
    Write-Host "Para iniciar:" -ForegroundColor Cyan
    Write-Host "  .\cves\scripts\runtime\Start-IntegratedSystem.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Dashboard:" -ForegroundColor Cyan
    Write-Host "  http://$($Config.Api.Host):$($Config.Api.Port)/web/index.html" -ForegroundColor Yellow
} else {
    Write-Host "❌ ENCONTRADOS $($issues.Count) PROBLEMA(S):" -ForegroundColor Red
    Write-Host ""

    foreach ($issue in $issues) {
        Write-Host "  • $issue" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Corrija os problemas acima antes de iniciar o sistema." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
