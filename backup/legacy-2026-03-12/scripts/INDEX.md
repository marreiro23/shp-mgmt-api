# 📋 Índice de Documentação - Analyze-SCCM-Certificates.ps1

## 📁 Arquivos Disponíveis

### 🔧 Script Principal
- **[Analyze-SCCM-Certificates.ps1](Analyze-SCCM-Certificates.ps1)**
  - Script PowerShell para análise de certificados SCCM
  - ~1127 linhas de código
  - Requer privilégios de administrador
  - ✅ Validado sintaticamente

---

## 📚 Documentação

### 1. 📖 README Completo
**Arquivo:** [README-Analyze-SCCM-Certificates.md](README-Analyze-SCCM-Certificates.md)

**Conteúdo:**
- ✅ Visão geral do script
- ✅ Sintaxe completa
- ✅ Descrição detalhada de todos os parâmetros
- ✅ Documentação de todas as funções (5 funções)
- ✅ Fases de análise (10 fases)
- ✅ Descrição de saídas (HTML, JSON, Log)
- ✅ Requisitos do sistema
- ✅ Solução de problemas
- ✅ Notas de segurança
- ✅ Changelog

**Indicado para:**
- Primeiros contatos com o script
- Referência completa de funções
- Entendimento aprofundado

**Tamanho:** ~400 linhas

---

### 2. 🚀 Guia Rápido
**Arquivo:** [QUICKSTART-Analyze-SCCM-Certificates.md](QUICKSTART-Analyze-SCCM-Certificates.md)

**Conteúdo:**
- ✅ Início rápido (comando básico)
- ✅ 4 cenários comuns de uso
- ✅ Interpretação de resultados
- ✅ Problemas comuns e soluções
- ✅ Fluxogramas de troubleshooting
- ✅ Dicas profissionais
- ✅ Exemplo de agendamento automático

**Indicado para:**
- Uso diário do script
- Troubleshooting rápido
- Consulta rápida de comandos

**Tamanho:** ~350 linhas

---

### 3. 📝 Resumo de Alterações
**Arquivo:** [RESUMO_ALTERACOES.md](RESUMO_ALTERACOES.md)

**Conteúdo:**
- ✅ Alterações implementadas (6 categorias)
- ✅ Comparações antes/depois
- ✅ Novos recursos detalhados
- ✅ Documentação criada
- ✅ Fluxo de execução atualizado
- ✅ Testes recomendados
- ✅ Checklist de implementação

**Indicado para:**
- Desenvolvedores/Administradores
- Auditoria de mudanças
- Revisão técnica

**Tamanho:** ~350 linhas

---

## 🎯 Qual Documentação Usar?

### Primeira vez usando o script?
👉 Comece com: **[README-Analyze-SCCM-Certificates.md](README-Analyze-SCCM-Certificates.md)**

### Precisa executar o script agora?
👉 Use: **[QUICKSTART-Analyze-SCCM-Certificates.md](QUICKSTART-Analyze-SCCM-Certificates.md)**

### Quer saber o que mudou?
👉 Consulte: **[RESUMO_ALTERACOES.md](RESUMO_ALTERACOES.md)**

### Precisa de help integrado?
👉 Execute: `Get-Help .\Analyze-SCCM-Certificates.ps1 -Full`

---

## 🔍 Comandos Rápidos

### Ver Help do Script
```powershell
Get-Help .\Analyze-SCCM-Certificates.ps1 -Full
Get-Help .\Analyze-SCCM-Certificates.ps1 -Examples
Get-Help .\Analyze-SCCM-Certificates.ps1 -Parameter ComputerType
```

### Execução Básica
```powershell
# Análise básica
.\Analyze-SCCM-Certificates.ps1

# Com exportação de relatórios
.\Analyze-SCCM-Certificates.ps1 -ExportReport

# Servidor SCCM
.\Analyze-SCCM-Certificates.ps1 -ComputerType Server -ExportReport

# Análise completa com revogação
.\Analyze-SCCM-Certificates.ps1 -IncludeDetailedChain -ExportReport
```

### Validação do Script
```powershell
# Testar sintaxe
$scriptPath = ".\Analyze-SCCM-Certificates.ps1"
$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize(
    (Get-Content $scriptPath -Raw), [ref]$errors)
if ($errors) { $errors } else { "✅ Script válido" }
```

---

## 📊 Recursos Principais do Script

### ✅ Novidades (Janeiro 2026)

1. **Thumbprint do Certificado**
   - Exibido em todas as saídas
   - Incluído em relatórios HTML/JSON
   - Retornado por funções de validação

2. **Parâmetros Flexíveis**
   - `-ComputerType`: Workstation/Server/Auto
   - `-IncludeDetailedChain`: Análise detalhada opcional
   - `-ExportReport`: Exportação automática
   - `-OutputPath`: Pasta customizada

3. **Análise por Tipo**
   - Detecção automática de Workstation/Server
   - Análise específica para servidores SCCM
   - Verificação de componentes (Site Server, MP, DP)
   - Sumário diferenciado por tipo

4. **Documentação Completa**
   - Comment-Based Help em todas as funções
   - 5 funções documentadas
   - Exemplos práticos
   - 3 documentos de referência

---

## 🔗 Links Úteis

### Documentação Microsoft
- [PKI Certificate Requirements for Configuration Manager](https://learn.microsoft.com/en-us/mem/configmgr/core/plan-design/network/pki-certificate-requirements)
- [Configure Client Certificate for SCCM](https://learn.microsoft.com/en-us/mem/configmgr/core/plan-design/security/configure-security)

### TechNet
- Certificate Templates for SCCM
- Troubleshooting SCCM Client Communication

---

## 📞 Suporte

**Desenvolvido por:** Okta7 Technologies
**Consultor:** Daniel Marreiro
**Cliente:** Sinqia
**Projeto:** Endpoint Management Automation Suite

**Para suporte:**
1. Consultar documentação apropriada acima
2. Executar script com `-ExportReport` e enviar relatórios
3. Incluir arquivo de log detalhado
4. Especificar Thumbprints de certificados problemáticos

---

## 📝 Estrutura de Pastas

```
cves/scripts/
│
├── Analyze-SCCM-Certificates.ps1           # ⭐ Script principal
│
├── INDEX.md                                 # 📋 Este arquivo (índice)
├── README-Analyze-SCCM-Certificates.md     # 📖 Documentação completa
├── QUICKSTART-Analyze-SCCM-Certificates.md # 🚀 Guia rápido
└── RESUMO_ALTERACOES.md                    # 📝 Log de alterações
```

---

## ✅ Checklist de Uso

### Antes de Executar
- [ ] PowerShell aberto como Administrador
- [ ] SCCM Client instalado (se análise de cliente)
- [ ] Rede conectada (se usar `-IncludeDetailedChain`)
- [ ] Pasta de saída existe (ou será criada)

### Durante Execução
- [ ] Observar mensagens coloridas no console
- [ ] Anotar Thumbprints de certificados importantes
- [ ] Verificar se há erros (texto vermelho)

### Após Execução
- [ ] Revisar relatório HTML gerado
- [ ] Verificar JSON exportado (se necessário)
- [ ] Consultar arquivo de log para detalhes
- [ ] Implementar recomendações sugeridas

---

## 🎓 Recursos de Aprendizado

### Conceitos Importantes

1. **Thumbprint (SHA-1 Hash)**
   - Identificador único de 40 caracteres hexadecimais
   - Usado para referenciar certificados específicos
   - Exemplo: `ABC123DEF456789012345678901234567890ABCD`

2. **Enhanced Key Usage (EKU)**
   - Client Authentication: `1.3.6.1.5.5.7.3.2`
   - Server Authentication: `1.3.6.1.5.5.7.3.1`
   - Code Signing: `1.3.6.1.5.5.7.3.3`

3. **Certificate Stores**
   - `Cert:\CurrentUser\My` - Certificados pessoais
   - `Cert:\LocalMachine\My` - Certificados do computador
   - `Cert:\LocalMachine\Root` - Root CAs
   - `Cert:\LocalMachine\CA` - Intermediate CAs

4. **SCCM Roles**
   - **Site Server:** Servidor central do SCCM
   - **Management Point (MP):** Interface de comunicação com clientes
   - **Distribution Point (DP):** Servidor de distribuição de conteúdo

---

## 🔄 Histórico de Versões

### v2.0 - Janeiro 2026 ✅
- Thumbprint em todos os lugares
- Parâmetros para tipo de computador
- Análise específica para servidores
- Documentação completa
- Comment-Based Help

### v1.0 - Versão Inicial
- Análise básica de certificados
- Validação de cadeia
- Geração de relatórios

---

**Última atualização:** 09 de Janeiro de 2026
**Versão do script:** 2.0
**Status:** ✅ Produção
