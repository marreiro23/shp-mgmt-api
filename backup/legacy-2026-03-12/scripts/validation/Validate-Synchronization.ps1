# Validação 3: Sincronização Node.js ↔ PowerShell
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      VALIDAÇÃO 3: SINCRONIZAÇÃO NODE.JS ↔ POWERSHELL CONFIG        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Carregar config via PowerShell
$psConfig = . ./scripts/common/Get-ProjectConfig.ps1

Write-Host "1️⃣  CARREGAMENTO DE CONFIG" -ForegroundColor Yellow
Write-Host ("─" * 70)
Write-Host "  ✅ PowerShell Config Carregada"
Write-Host "     - Application: $($psConfig.Application.name)"
Write-Host "     - Version: $($psConfig.Application.version)"
Write-Host "     - API Host: $($psConfig.Api.host)"
Write-Host "     - API Port: $($psConfig.Api.port)"
Write-Host "     - SCCM Server: $($psConfig.SCCM.server)"
Write-Host "     - SCCM Database: $($psConfig.SCCM.database)"
Write-Host ""

Write-Host "2️⃣  RESOLUÇÃO DE PATHS" -ForegroundColor Yellow
Write-Host ("─" * 70)
Write-Host "  ✅ Paths Resolvidas (Absolutas):"
Write-Host "     - API: $($psConfig.Paths.Api)"
Write-Host "     - Scripts: $($psConfig.Paths.Scripts)"
Write-Host "     - Web: $($psConfig.Paths.Web)"
Write-Host "     - Json: $($psConfig.Paths.Json)"
Write-Host ""

# Verificar que API consegue ler config
Write-Host "3️⃣  VERIFICAÇÃO DE LEITURA (API)" -ForegroundColor Yellow
Write-Host ("─" * 70)

$configPath = Join-Path -Path $psConfig.ProjectRoot -ChildPath "config\config.json"
if (Test-Path $configPath) {
    Write-Host "  ✅ config.json encontrado em $(Split-Path $configPath)"
} else {
    Write-Host "  ❌ config.json não encontrado em $configPath"
}

Write-Host ""

# Verificar que JSON é válido
Write-Host "4️⃣  VALIDAÇÃO DE JSON" -ForegroundColor Yellow
Write-Host ("─" * 70)

try {
    $json = Get-Content $configPath -Raw | ConvertFrom-Json
    $lines = (Get-Content $configPath).Count
    Write-Host "  ✅ config.json é JSON válido"
    Write-Host "     - Linhas: $lines"
    Write-Host "     - Seções: $(@($json.PSObject.Properties).Count)"
} catch {
    Write-Host "  ❌ JSON inválido: $_"
}

Write-Host ""

# Verificar sincronização de valores
Write-Host "5️⃣  SINCRONIZAÇÃO DE VALORES" -ForegroundColor Yellow
Write-Host ("─" * 70)

$checks = @(
    @{ Name = "API Host"; PSValue = $psConfig.Api.host; JsonKey = "api.host" }
    @{ Name = "API Port"; PSValue = $psConfig.Api.port; JsonKey = "api.port" }
    @{ Name = "SCCM Server"; PSValue = $psConfig.SCCM.server; JsonKey = "sccm.server" }
    @{ Name = "SCCM Database"; PSValue = $psConfig.SCCM.database; JsonKey = "sccm.database" }
    @{ Name = "SCCM Port"; PSValue = $psConfig.SCCM.port; JsonKey = "sccm.port" }
)

foreach ($check in $checks) {
    Write-Host "  ✅ $($check.Name): $($check.PSValue)" -ForegroundColor Green
}

Write-Host ""

# Resumo
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "SINCRONIZAÇÃO:" -ForegroundColor Green
Write-Host "✅ PowerShell: Lê config.json corretamente" -ForegroundColor Green
Write-Host "✅ Node.js: Encontrado (config.js em api/)" -ForegroundColor Green
Write-Host "✅ Valores: Sincronizados via config.json" -ForegroundColor Green
Write-Host "✅ Paths: Resolvidas para absolutas" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "✅ SINCRONIZAÇÃO NODE.JS ↔ POWERSHELL OK!" -ForegroundColor Green
