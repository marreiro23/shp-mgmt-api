# CVE Domain Analysis & Growth Tracking

## Visão Geral

Sistema completo de análise de CVEs com foco em:

- ✅ **Extração de Domínios**: Extrai sufixo DNS do FQDN de ativos (campo CO)
- ✅ **Contagem por Domínio**: Distribui dispositivos por domínio
- ✅ **Análise de Crescimento**: Calcula volume de crescimento entre períodos
- ✅ **Detecção de Mudanças**: Identifica máquinas/aplicações sem alterações
- ✅ **Backup Automático**: Mantém histórico de dados antigos
- ✅ **API REST**: Endpoints para integração com dashboards
- ✅ **Relatórios HTML**: Visualizações interativas com gráficos

## 📋 Arquivos Criados/Modificados

### Scripts PowerShell (`/scripts/`)

#### 1. **Import-NewTenableData.ps1** ⭐ Principal
```powershell
.\Import-NewTenableData.ps1 `
  -ExcelPath "..\raw\Tenable150126.xlsx" `
  -KeepBackup $true
```

**Funções:**
- Carrega arquivo Excel do Tenable
- Extrai domínios de `asset.display_fqdn` (coluna CO)
- Calcula estatísticas por domínio
- Gera análise de crescimento
- Identifica máquinas sem mudanças
- Mantém apenas versão nova (descarta dados antigos)
- Faz backup automático

**Saída:**
- `../json/tenable_YYYYMMDD_HHMMSS.json` - Dados processados
- `../reports/domain_analysis_*.json` - Análise de domínios
- `../reports/growth_analysis_*.json` - Análise de crescimento
- `../reports/unchanged_analysis_*.json` - Máquinas sem mudanças
- `../backup/` - Histórico de dados antigos (opcional)

#### 2. **Generate-DomainAnalysisReports.ps1**
```powershell
.\Generate-DomainAnalysisReports.ps1
```

**Funções:**
- Carrega dados de análise JSON
- Gera dashboard HTML interativo
- Cria gráficos de distribuição e crescimento
- Permite busca e filtro de dados

**Saída:**
- `../reports/html/domain_analysis_dashboard.html` - Dashboard principal
- `../reports/html/domain_detailed_report.html` - Relatório detalhado

#### 3. **Invoke-FullCVEAnalysis.ps1** ⭐ Orquestração
```powershell
.\Invoke-FullCVEAnalysis.ps1 [opções]
```

**Opções:**
- `-ExcelPath` - Path do arquivo (default: ../raw/Tenable150126.xlsx)
- `-SkipGeneration` - Pula geração HTML
- `-NoBackup` - Não faz backup

**Executa:**
1. Import-NewTenableData.ps1
2. Generate-DomainAnalysisReports.ps1
3. Verifica integração com API

## 🔌 API REST

### Endpoints Novos

Todos sob `/api/v1/analysis/`

#### `GET /api/v1/analysis/domains`
Retorna distribuição de dispositivos por domínio

```bash
curl http://localhost:3000/api/v1/analysis/domains
```

**Resposta:**
```json
{
  "success": true,
  "timestamp": "2026-01-16T14:30:00Z",
  "total": 5,
  "data": [
    {
      "domain": "EXAMPLE.COM",
      "deviceCount": 45,
      "devices": ["PC001", "PC002", ...],
      "percentage": 35.5
    }
  ]
}
```

#### `GET /api/v1/analysis/domains/:domain`
Detalhes de um domínio específico

```bash
curl http://localhost:3000/api/v1/analysis/domains/EXAMPLE.COM
```

#### `GET /api/v1/analysis/growth`
Análise de crescimento de volume

```bash
curl http://localhost:3000/api/v1/analysis/growth
```

**Resposta:**
```json
{
  "success": true,
  "timestamp": "2026-01-16T14:30:00Z",
  "summary": {
    "newTotal": 250,
    "previousTotal": 180,
    "uniqueDevices": 45,
    "uniqueDomains": 5
  },
  "growth": {
    "volumeIncrease": 70,
    "percentageIncrease": 38.89
  }
}
```

#### `GET /api/v1/analysis/unchanged`
Máquinas/aplicações sem mudanças

```bash
curl http://localhost:3000/api/v1/analysis/unchanged
```

#### `GET /api/v1/analysis/summary`
Resumo consolidado de todas as análises

```bash
curl http://localhost:3000/api/v1/analysis/summary
```

#### `POST /api/v1/analysis/export/:format`
Exportar análise em formato

```bash
curl -X POST http://localhost:3000/api/v1/analysis/export/json
```

## 🚀 Como Usar

### Passo 1: Preparar Arquivo Excel

1. Coloque o novo arquivo Tenable em: `cves/raw/Tenable150126.xlsx`
2. Certifique-se de que a coluna CO contém `asset.display_fqdn`

### Passo 2: Executar Análise

**Opção A - Orquestração Completa (Recomendado)**
```powershell
cd c:\REPOSITORIO\PSAppDeployToolkit\cves\scripts
.\Invoke-FullCVEAnalysis.ps1
```

**Opção B - Apenas Importação**
```powershell
cd c:\REPOSITORIO\PSAppDeployToolkit\cves\scripts
.\Import-NewTenableData.ps1
```

**Opção C - Apenas Relatórios HTML**
```powershell
cd c:\REPOSITORIO\PSAppDeployToolkit\cves\scripts
.\Generate-DomainAnalysisReports.ps1
```

### Passo 3: Visualizar Resultados

**Dashboard HTML:**
```powershell
# Abrir no navegador
Invoke-Item "..\reports\html\domain_analysis_dashboard.html"
```

**API:**
```powershell
# Iniciar API se não estiver rodando
cd c:\REPOSITORIO\PSAppDeployToolkit\cves\api
npm start
```

Então acessar: `http://localhost:3000/api/v1/analysis/summary`

## 📊 Estrutura de Dados

### domain_analysis_*.json
```json
{
  "timestamp": "2026-01-16T14:30:00Z",
  "domains": [
    {
      "domain": "EXAMPLE.COM",
      "deviceCount": 45,
      "devices": ["PC001", "PC002", "PC003"],
      "percentage": 35.5
    }
  ]
}
```

### growth_analysis_*.json
```json
{
  "timestamp": "2026-01-16T14:30:00Z",
  "newTotal": 250,
  "previousTotal": 180,
  "uniqueDevices": 45,
  "uniqueDomains": 5,
  "growth": {
    "volumeIncrease": 70,
    "percentageIncrease": 38.89,
    "devices": {}
  }
}
```

### unchanged_analysis_*.json
```json
{
  "timestamp": "2026-01-16T14:30:00Z",
  "unchanged": [
    {
      "device": "PC001.EXAMPLE.COM",
      "applicationCount": 3,
      "applications": [
        {
          "app": "Microsoft Office",
          "cve": "CVE-2024-1234",
          "severity": "High"
        }
      ],
      "hasChanged": false
    }
  ]
}
```

## 🔍 Exemplos de Uso

### Exemplo 1: Listar Todos os Domínios com Crescimento
```powershell
$analysis = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/analysis/summary"
$analysis.data.domains.allDomains | Format-Table domain, deviceCount, percentage
```

### Exemplo 2: Encontrar Máquinas Específicas de um Domínio
```powershell
$domainData = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/analysis/domains/CORP.COM"
$domainData.data.devices | ForEach-Object { "  $_" }
```

### Exemplo 3: Calcular Crescimento Percentual
```powershell
$growth = Invoke-RestMethod -Uri "http://localhost:3000/api/v1/analysis/growth"
Write-Host "Crescimento: +$($growth.data.growth.volumeIncrease) registros ($($growth.data.growth.percentageIncrease)%)"
```

### Exemplo 4: Exportar Análise Completa
```powershell
$export = Invoke-RestMethod -Method Post -Uri "http://localhost:3000/api/v1/analysis/export/json"
$export.data | ConvertTo-Json -Depth 100 | Out-File "analise_completa.json"
```

## 🛠️ Arquivos Modificados

### `/cves/api/server.js`
- ✅ Importada rota `analysis.routes.js`
- ✅ Registrada rota em `app.use()`
- ✅ Documentação em `/` atualizada

### `/cves/api/routes/analysis.routes.js` (Novo)
- Endpoint de domínios
- Endpoint de crescimento
- Endpoint de mudanças
- Endpoint de resumo
- Endpoint de exportação

## 📈 Métricas Rastreadas

Por domínio:
- 🔹 Quantidade de dispositivos
- 🔹 Percentual do total
- 🔹 Lista de dispositivos

Globalmente:
- 📊 Total de registros
- 📊 Domínios únicos
- 📊 Dispositivos únicos
- 📊 Crescimento absoluto
- 📊 Crescimento percentual

Por máquina:
- ⚙️ Aplicações instaladas
- ⚙️ Alterações detectadas
- ⚙️ Status (com mudança / sem mudança)

## ⚙️ Configuração

### Backup Automático

Os dados antigos são movidos para `../backup/` com timestamp:
```
backup_20260116_143000_tenable_YYYYMMDD_HHMMSS.json
```

Para desabilitar:
```powershell
.\Import-NewTenableData.ps1 -KeepBackup $false
```

### Extração de Domínio

A função `Get-DomainFromFqdn` extrai o domínio de:
- `pc001.subdomain.example.com` → `EXAMPLE.COM`
- `servidor.corp.local` → `CORP.LOCAL`
- `maquina.contoso.com` → `CONTOSO.COM`

## 🐛 Troubleshooting

### Erro: "Arquivo Excel não encontrado"
✅ Coloque arquivo em: `cves/raw/Tenable150126.xlsx`

### Erro: "ImportExcel module not found"
✅ Instale com:
```powershell
Install-Module -Name ImportExcel -Force -Scope CurrentUser
```

### API não encontra dados
✅ Execute Import-NewTenableData.ps1 primeiro

### HTML não carrega gráficos
✅ Verifique conexão com cdn.jsdelivr.net para Chart.js

## 📝 Notas

- Dados antigos são substituídos (mantém apenas versão nova)
- Backup é opcional mas recomendado
- Relatórios HTML são gerados automaticamente
- API é integrada e pronta para uso
- Suporta até 150+ aplicações por dispositivo
- Otimizado para arquivos Excel grandes (100MB+)

## 📞 Suporte

Para dúvidas ou problemas:
1. Verifique logs em `../logs/`
2. Confirme estrutura de dados em `../json/`
3. Teste API manualmente em `../test-api.html`

---

**Última Atualização:** 2026-01-16
**Versão:** 2.0.0
