<#
.SYNOPSIS
    Valida os nomes dos arquivos em pastas específicas

.DESCRIPTION
    Script de validação que verifica se os arquivos em pastas especificadas
    possuem nomes apenas em inglês (en-US), sem caracteres especiais,
    acentuação ou palavras em outros idiomas.

.PARAMETER FolderPath
    Caminho da pasta a ser validada. Padrão: pasta atual.

.PARAMETER RestrictedFolders
    Array de pastas onde a regra deve ser aplicada.

.PARAMETER AutoFix
    Se especificado, sugere nomes corrigidos para arquivos inválidos.

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Validate-FileNames.ps1 -FolderPath ".\scripts"

.EXAMPLE
    .\Validate-FileNames.ps1 -RestrictedFolders @("scripts", "web", "api") -AutoFix
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$FolderPath = ".",

    [Parameter(Mandatory=$false)]
    [string[]]$RestrictedFolders = @("scripts", "web", "api", "controllers", "services"),

    [Parameter(Mandatory=$false)]
    [switch]$AutoFix
)

# Carregar configuração centralizada
try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

# Palavras comuns em português que devem ser evitadas
$PortugueseWords = @(
    'arquivo', 'documento', 'relatorio', 'sistema', 'teste', 'dados',
    'configuracao', 'integracao', 'inicio', 'exemplo', 'modelo',
    'resultado', 'analise', 'correcao', 'validacao', 'remediacao'
)

# Caracteres não permitidos (acentuação e caracteres especiais pt-BR)
$InvalidCharsPattern = '[àáâãäåèéêëìíîïòóôõöùúûüýÿçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÇÑ]'

function Test-EnglishFileName {
    [CmdletBinding()]
    param(
        [string]$FileName
    )

    # Remover extensão
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    # Verificar caracteres inválidos
    if ($nameWithoutExt -match $InvalidCharsPattern) {
        return $false
    }

    # Verificar palavras em português
    foreach ($word in $PortugueseWords) {
        if ($nameWithoutExt -match "\b$word\b") {
            return $false
        }
    }

    return $true
}

function Get-SuggestedFileName {
    [CmdletBinding()]
    param(
        [string]$FileName
    )

    $extension = [System.IO.Path]::GetExtension($FileName)
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    # Remover acentuação
    $removedAccents = $nameWithoutExt -replace '[àáâãäå]', 'a' -replace '[èéêë]', 'e' -replace '[ìíîï]', 'i' `
                                      -replace '[òóôõö]', 'o' -replace '[ùúûü]', 'u' -replace '[ýÿ]', 'y' `
                                      -replace 'ç', 'c' -replace 'ñ', 'n' `
                                      -replace '[ÀÁÂÃÄÅ]', 'A' -replace '[ÈÉÊË]', 'E' -replace '[ÌÍÎÏ]', 'I' `
                                      -replace '[ÒÓÔÕÖ]', 'O' -replace '[ÙÚÛÜ]', 'U' -replace 'Ç', 'C' -replace 'Ñ', 'N'

    return "$removedAccents$extension"
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         VALIDAÇÃO DE NOMES DE ARQUIVOS - ENGLISH ONLY             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$invalidFiles = @()
$validFiles = @()

# Verificar arquivos nas pastas restritas
foreach ($folder in $RestrictedFolders) {
    $folderPath = Join-Path $FolderPath $folder

    if (Test-Path $folderPath -PathType Container) {
        Write-Host "Validando pasta: $folderPath" -ForegroundColor Yellow

        $files = Get-ChildItem -Path $folderPath -Recurse -File

        foreach ($file in $files) {
            if (Test-EnglishFileName -FileName $file.Name) {
                $validFiles += $file.FullName
            } else {
                $invalidFiles += @{
                    Path = $file.FullName
                    CurrentName = $file.Name
                    SuggestedName = Get-SuggestedFileName -FileName $file.Name
                }
            }
        }
    }
}

# Relatório
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "RELATÓRIO DE VALIDAÇÃO" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "✓ Arquivos válidos: $($validFiles.Count)" -ForegroundColor Green
Write-Host "✗ Arquivos inválidos: $($invalidFiles.Count)" -ForegroundColor $(if($invalidFiles.Count -eq 0){'Green'}else{'Red'})

if ($invalidFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "ARQUIVOS COM NOMES INVÁLIDOS:" -ForegroundColor Red
    Write-Host "────────────────────────────────────────────────────────────────────" -ForegroundColor Gray

    foreach ($invalidFile in $invalidFiles) {
        Write-Host ""
        Write-Host "  ✗ Atual: $($invalidFile.CurrentName)" -ForegroundColor Red
        Write-Host "    Sugerido: $($invalidFile.SuggestedName)" -ForegroundColor Yellow
        Write-Host "    Caminho: $($invalidFile.Path)" -ForegroundColor Gray

        if ($AutoFix) {
            $newPath = Join-Path (Split-Path $invalidFile.Path) $invalidFile.SuggestedName
            Write-Host "    Novo caminho: $newPath" -ForegroundColor Green
        }
    }

    if (-not $AutoFix) {
        Write-Host ""
        Write-Host "Use -AutoFix para sugerir correções automáticas" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "✓ Todos os arquivos possuem nomes válidos em inglês!" -ForegroundColor Green
}

Write-Host ""
