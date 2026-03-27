# 📋 Scripts de Coleta de Dados - README

## 📊 Visão Geral

Esta pasta contém scripts para **coleta de dados de produção** sem impacto no ambiente (somente leitura).

## 🎯 Objetivo

Implementar o **PLANO_COLETA_DADOS_REMEDIACAO.md** com scripts automatizados para:
1. Coletar inventário de dispositivos (SCCM + Intune)
2. Coletar inventário de software instalado
3. Fazer cross-reference com vulnerabilidades
4. Gerar relatórios e análises

## 📁 Scripts Disponíveis

### Fase 1: Inventário de Dispositivos

| Script | Descrição | Impacto |
|--------|-----------|---------|
| **Collect-SCCM-Inventory.ps1** | Coleta dispositivos do SCCM via API | ⚪ ZERO |
| **Collect-Intune-Inventory.ps1** | Coleta dispositivos do Intune/Autopilot | ⚪ ZERO |
| **Consolidate-DeviceInventory.ps1** | Cruza dados SCCM + Intune | ⚪ ZERO |
| **Run-Complete-Data-Collection.ps1** | **Script mestre** - Executa tudo | ⚪ ZERO |

### Fase 2: Inventário de Software (Futuro)

| Script | Descrição | Status |
|--------|-----------|--------|
| **Collect-Software-Inventory-Sample.ps1** | Amostragem de software | 🔴 Pendente |
| **Analyze-Common-Applications.ps1** | Análise de apps mais comuns | 🔴 Pendente |

### Fase 3: Matching com CVEs (Futuro)

| Script | Descrição | Status |
|--------|-----------|--------|
| **Import-Tenable-Production.ps1** | Importa dados Tenable | 🔴 Pendente |
| **Match-Software-Vulnerabilities.ps1** | Cross-reference CVEs | 🔴 Pendente |

### Fase 4: Relatórios (Futuro)

| Script | Descrição | Status |
|--------|-----------|--------|
| **Generate-Production-Dashboard.ps1** | Dashboard executivo | 🔴 Pendente |

## 🚀 Como Usar

### Execução Rápida (Recomendado)

```powershell
# Executar tudo automaticamente
.\Run-Complete-Data-Collection.ps1 -Phase All -Verbose

# Executar apenas Fase 1 (Inventário)
.\Run-Complete-Data-Collection.ps1 -Phase 1
```

### Execução Manual (Passo a Passo)

```powershell
# 1. Coletar SCCM
.\Collect-SCCM-Inventory.ps1

# 2. Coletar Intune
.\Collect-Intune-Inventory.ps1

# 3. Consolidar
.\Consolidate-DeviceInventory.ps1
```

## 📂 Arquivos Gerados

Todos os CSVs são salvos em: `c:\REPOSITORIO\API-Hybrid-Autopilot\exports\data-collection\`

### Exemplos

```
SCCM-Inventory-Full-20260120-143022.csv
Intune-Inventory-Full-20260120-143130.csv
Consolidated-Inventory-20260120-143245.csv
```

## ⚠️ Pré-requisitos

### APIs Rodando

```powershell
# Iniciar todas as APIs
cd c:\REPOSITORIO\API-Hybrid-Autopilot
.\Start-AllServices.ps1
```

Ou manualmente:

```powershell
# Terminal 1 - CVE API (porta 3001)
cd cves\api
npm start

# Terminal 2 - Autopilot API (porta 3002)
cd autopilot\api
npm start

# Terminal 3 - Gateway API (porta 3000) - Opcional
cd gateway
npm start
```

### Verificar Health

```powershell
# CVE API
curl http://localhost:3001/health

# Autopilot API
curl http://localhost:3002/health
```

### Credenciais Azure AD

Arquivo `.env` em `autopilot\api\` com:

```env
TENANT_ID=your-tenant-id
CLIENT_ID=your-client-id
CLIENT_SECRET=your-client-secret
```

## 📊 Saída Esperada

### Collect-SCCM-Inventory.ps1

```
================================================================================
📊 COLETA DE INVENTÁRIO SCCM
================================================================================

🔍 Executando query no SCCM...
✅ Query executada com sucesso!
   Dispositivos encontrados: 1234

📁 Exportando para CSV...
✅ Arquivo exportado: SCCM-Inventory-Full-20260120-143022.csv

📊 ESTATÍSTICAS:

   Top 5 Fabricantes:
      - Dell Inc.: 567 dispositivos
      - Lenovo: 432 dispositivos
      - HP: 235 dispositivos
      ...
```

### Consolidate-DeviceInventory.ps1

```
🔗 CONSOLIDAÇÃO DE INVENTÁRIOS
...
📊 ESTATÍSTICAS CONSOLIDADAS:

   Total de Dispositivos: 1500

   📊 Distribuição por Gerenciamento:
      - Somente SCCM: 800 (53.3%)
      - Somente Intune: 200 (13.3%)
      - Híbrido (Ambos): 500 (33.3%)
```

## 🔧 Troubleshooting

### Erro: "API não acessível"

```powershell
# Verificar se APIs estão rodando
Get-Process node

# Reiniciar APIs
.\Start-AllServices.ps1
```

### Erro: "Nenhum arquivo encontrado"

```powershell
# Verificar diretório de exports
Get-ChildItem "c:\REPOSITORIO\API-Hybrid-Autopilot\exports\data-collection"

# Executar coleta novamente
.\Collect-SCCM-Inventory.ps1
.\Collect-Intune-Inventory.ps1
```

### Erro: "Azure AD authentication failed"

```powershell
# Verificar credenciais no .env
cat ..\..\..\autopilot\api\.env

# Testar autenticação
curl http://localhost:3002/api/v1/autopilot/devices
```

## 📚 Documentação Relacionada

- **[PLANO_COLETA_DADOS_REMEDIACAO.md](../../docs/PLANO_COLETA_DADOS_REMEDIACAO.md)** - Plano completo
- **[GUIA_INTEGRACAO_COMPLETA.md](../../docs/GUIA_INTEGRACAO_COMPLETA.md)** - Integração APIs
- **[CVE API README](../../cves/api/README.md)** - Documentação CVE API
- **[Autopilot API README](../../autopilot/README.md)** - Documentação Autopilot API

## ✅ Checklist de Execução

- [ ] APIs CVE e Autopilot rodando
- [ ] Credenciais Azure AD configuradas
- [ ] Health checks passando
- [ ] Diretório de exports criado
- [ ] Executar `Run-Complete-Data-Collection.ps1 -Phase 1`
- [ ] Revisar CSVs gerados
- [ ] Apresentar resultados para stakeholders

## 📞 Suporte

- **Documentação Completa**: `docs\PLANO_COLETA_DADOS_REMEDIACAO.md`
- **Troubleshooting**: `docs\TROUBLESHOOTING.md`
- **GitHub Issues**: Para reportar bugs

---

**Data de Criação:** 20 de Janeiro de 2026
**Versão:** 1.0.0
**Status:** ✅ Pronto para Uso
