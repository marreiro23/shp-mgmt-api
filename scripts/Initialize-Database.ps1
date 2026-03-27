<#
.SYNOPSIS
    Inicializa o banco de dados PostgreSQL para a shp-mgmt-api.

.DESCRIPTION
    Cria o banco de dados, o usuário de aplicação e executa o DDL do schema
    (scripts/sql/setup-schema.sql). Pode ser executado de forma standalone ou
    chamado pelo Start-API-Background.ps1 na primeira execução.

    Suporta PostgreSQL local e Azure Flexible Server.

.PARAMETER PgHost
    Host do PostgreSQL. Default: localhost

.PARAMETER PgPort
    Porta do PostgreSQL. Default: 5432

.PARAMETER PgAdminUser
    Usuário administrador (superuser) para criar o DB e o role.
    Default: postgres

.PARAMETER PgAdminPassword
    Senha do PgAdminUser. Se omitido, será solicitado no prompt.

.PARAMETER AppDbName
    Nome do banco de dados da aplicação. Default: shp_mgmt_db

.PARAMETER AppDbUser
    Nome do usuário de aplicação (role). Default: shp_app_user

.PARAMETER AppDbPassword
    Senha do AppDbUser. Se omitido, será solicitado no prompt.

.PARAMETER WriteEnvFile
    Se true, escreve as variáveis PG_ no arquivo .env da API.

.PARAMETER EnvFilePath
    Caminho do .env a atualizar. Default: <repo-root>/api/.env

.EXAMPLE
    .\Initialize-Database.ps1

.EXAMPLE
    .\Initialize-Database.ps1 -PgHost myserver.postgres.database.azure.com `
        -PgAdminUser pgadmin -AppDbName shp_mgmt_db -WriteEnvFile

.NOTES
    Requisitos:
        - psql deve estar disponível no PATH (instale o cliente PostgreSQL)
        - No Azure Flexible Server, o PgAdminUser normalmente é 'pgadmin' e não 'postgres'
#>

[CmdletBinding()]
param(
    [string]$PgHost        = 'localhost',
    [string]$PgPort        = '5432',
    [string]$PgAdminUser   = 'postgres',
    [SecureString]$PgAdminPassword,
    [string]$AppDbName     = 'shp_mgmt_db',
    [string]$AppDbUser     = 'shp_app_user',
    [SecureString]$AppDbPassword,
    [switch]$WriteEnvFile,
    [string]$EnvFilePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Paths ────────────────────────────────────────────────────────────────────
$scriptDir  = $PSScriptRoot
$repoRoot   = Split-Path -Parent $scriptDir
$sqlFile    = Join-Path $scriptDir 'sql\setup-schema.sql'
if (-not $EnvFilePath) {
    $EnvFilePath = Join-Path $repoRoot 'api\.env'
}

# ─── Banner ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║      SHP-MGMT-API :: Inicialização do Banco de Dados     ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

# ─── Verificar psql ───────────────────────────────────────────────────────────
Write-Host '🔍 Verificando disponibilidade do psql...' -ForegroundColor Gray
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlPath) {
    Write-Host '❌ psql não encontrado no PATH.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Instale o cliente PostgreSQL e adicione ao PATH.' -ForegroundColor Yellow
    Write-Host '  Windows : https://www.postgresql.org/download/windows/' -ForegroundColor Gray
    Write-Host '  winget  : winget install PostgreSQL.PostgreSQL.16' -ForegroundColor Gray
    Write-Host ''
    exit 1
}
$psqlVersion = & psql --version 2>&1
Write-Host "✅ psql encontrado: $psqlVersion" -ForegroundColor Green
Write-Host ''

# ─── Solicitar senhas se necessário ───────────────────────────────────────────
if (-not $PgAdminPassword) {
    $PgAdminPassword = Read-Host "🔑 Senha do usuário administrador '$PgAdminUser'" -AsSecureString
}
if (-not $AppDbPassword) {
    $AppDbPassword = Read-Host "🔑 Senha do usuário de aplicação '$AppDbUser'" -AsSecureString
}

function ConvertTo-PlainText([SecureString]$secure) {
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$adminPw = ConvertTo-PlainText $PgAdminPassword
$appPw   = ConvertTo-PlainText $AppDbPassword

# ─── Helper: executar psql ────────────────────────────────────────────────────
function Invoke-Psql {
    param(
        [string]$Sql,
        [string]$Database = 'postgres',
        [string]$AdminUser = $PgAdminUser,
        [string]$AdminPw   = $adminPw,
        [string]$SqlFile
    )

    $env:PGPASSWORD = $AdminPw
    try {
        if ($SqlFile) {
            $result = & psql --host=$PgHost --port=$PgPort --username=$AdminUser `
                             --dbname=$Database --no-password `
                             --file=$SqlFile 2>&1
        } else {
            $result = & psql --host=$PgHost --port=$PgPort --username=$AdminUser `
                             --dbname=$Database --no-password `
                             --command=$Sql 2>&1
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $env:PGPASSWORD = ''
    }

    if ($exitCode -ne 0) {
        throw "psql falhou (exit $exitCode):`n$result"
    }
    return $result
}

# ─── Passo 1: Testar conectividade com admin ──────────────────────────────────
Write-Host "📡 Testando conexão com ${PgHost}:${PgPort} como '${PgAdminUser}'..." -ForegroundColor Cyan
try {
    Invoke-Psql -Sql "SELECT version();" | Out-Null
    Write-Host '✅ Conexão administrativa OK.' -ForegroundColor Green
} catch {
    Write-Host '❌ Falha na conexão administrativa.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Verifique:' -ForegroundColor Yellow
    Write-Host "  • PostgreSQL está rodando em ${PgHost}:${PgPort}" -ForegroundColor Gray
    Write-Host "  • O usuário '${PgAdminUser}' existe e a senha está correta" -ForegroundColor Gray
    Write-Host '  • Regras de firewall permitem a conexão' -ForegroundColor Gray
    exit 1
}
Write-Host ''

# ─── Passo 2: Criar banco de dados ────────────────────────────────────────────
Write-Host "🗄️  Criando banco de dados '${AppDbName}'..." -ForegroundColor Cyan
$dbExists = Invoke-Psql -Sql "SELECT 1 FROM pg_database WHERE datname='${AppDbName}';"
if ($dbExists -match '1') {
    Write-Host "   ℹ️  Banco '${AppDbName}' já existe. Ignorando." -ForegroundColor Gray
} else {
    Invoke-Psql -Sql "CREATE DATABASE `"${AppDbName}`" WITH ENCODING='UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE=template0;" | Out-Null
    Write-Host "   ✅ Banco '${AppDbName}' criado." -ForegroundColor Green
}
Write-Host ''

# ─── Passo 3: Criar usuário de aplicação ─────────────────────────────────────
Write-Host "👤 Criando usuário de aplicação '${AppDbUser}'..." -ForegroundColor Cyan
$roleExists = Invoke-Psql -Sql "SELECT 1 FROM pg_roles WHERE rolname='${AppDbUser}';"
if ($roleExists -match '1') {
    Write-Host "   ℹ️  Role '${AppDbUser}' já existe. Atualizando senha." -ForegroundColor Gray
    # Usar arquivo temporário para evitar problemas com aspas simples na senha
    $tmpSql = Join-Path $env:TEMP "shp_update_role_$(Get-Random).sql"
    try {
        "ALTER ROLE `"${AppDbUser}`" WITH LOGIN PASSWORD '$appPw';" | Set-Content $tmpSql -Encoding UTF8
        Invoke-Psql -Sql $null -SqlFile $tmpSql | Out-Null
    } finally {
        Remove-Item $tmpSql -ErrorAction SilentlyContinue
    }
} else {
    $tmpSql = Join-Path $env:TEMP "shp_create_role_$(Get-Random).sql"
    try {
        "CREATE ROLE `"${AppDbUser}`" WITH LOGIN PASSWORD '$appPw' NOSUPERUSER NOCREATEDB NOCREATEROLE;" | Set-Content $tmpSql -Encoding UTF8
        Invoke-Psql -Sql $null -SqlFile $tmpSql | Out-Null
        Write-Host "   ✅ Role '${AppDbUser}' criado." -ForegroundColor Green
    } finally {
        Remove-Item $tmpSql -ErrorAction SilentlyContinue
    }
}
Write-Host ''

# ─── Passo 4: Executar DDL do schema ─────────────────────────────────────────
Write-Host '📜 Aplicando schema DDL (setup-schema.sql)...' -ForegroundColor Cyan
if (-not (Test-Path $sqlFile)) {
    Write-Host "❌ Arquivo não encontrado: $sqlFile" -ForegroundColor Red
    exit 1
}
try {
    $output = Invoke-Psql -Database $AppDbName -SqlFile $sqlFile
    # Mostrar a linha RAISE NOTICE do DO block sem exibir todo o output
    $output | Where-Object { $_ -match 'NOTICE|WARNING|ERROR' } | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
    Write-Host '   ✅ Schema aplicado.' -ForegroundColor Green
} catch {
    Write-Host '❌ Falha ao aplicar schema.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
    exit 1
}
Write-Host ''

# ─── Passo 5: Escrever variáveis no .env (opcional) ───────────────────────────
if ($WriteEnvFile) {
    Write-Host "📝 Atualizando ${EnvFilePath} com variáveis PostgreSQL..." -ForegroundColor Cyan

    $pgBlock = @"

# ──────────────────────────────────────────────────────────────────
# PostgreSQL (persistência de inventário e exports)
# Configurado por Initialize-Database.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm')
# ──────────────────────────────────────────────────────────────────
PG_HOST=$PgHost
PG_PORT=$PgPort
PG_DATABASE=$AppDbName
PG_USER=$AppDbUser
PG_PASSWORD=$appPw
PG_SSL=false
PG_SCHEMA=shp
"@

    if (Test-Path $EnvFilePath) {
        # Remover bloco PG anterior se existir, depois acrescentar o novo
        $existing = Get-Content $EnvFilePath -Raw -Encoding UTF8
        $existing = $existing -replace '(?ms)\n# ─+\n# PostgreSQL.*?(?=\n# ─|\Z)', ''
        # Remover linhas PG_ soltas (fallback)
        $existing = ($existing -split "`n" | Where-Object { $_ -notmatch '^PG_' }) -join "`n"
        ($existing.TrimEnd() + $pgBlock) | Set-Content $EnvFilePath -Encoding UTF8 -NoNewline
    } else {
        $pgBlock | Set-Content $EnvFilePath -Encoding UTF8
    }

    Write-Host '   ✅ Variáveis PG_ escritas no .env.' -ForegroundColor Green
    Write-Host '   ⚠️  Não comite o .env com senha em produção!' -ForegroundColor Yellow
    Write-Host ''
}

# ─── Concluído ────────────────────────────────────────────────────────────────
# Limpar senha da memória
$adminPw = $null
$appPw   = $null

Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Green
Write-Host '║         ✅  Banco de dados inicializado com sucesso!     ║' -ForegroundColor Green
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Green
Write-Host ''
Write-Host "  Host    : ${PgHost}:${PgPort}" -ForegroundColor White
Write-Host "  Database: ${AppDbName}" -ForegroundColor White
Write-Host "  App user: ${AppDbUser}" -ForegroundColor White
Write-Host "  Schema  : shp (6 tabelas)" -ForegroundColor White
Write-Host ''
Write-Host 'Próximo passo: inicie a API com .\Start-API-Background.ps1' -ForegroundColor Cyan
Write-Host ''
