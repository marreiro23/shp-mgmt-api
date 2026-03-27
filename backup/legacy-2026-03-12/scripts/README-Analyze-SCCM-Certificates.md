# Analyze-SCCM-Certificates.ps1 - Documentação

## Visão Geral

Script PowerShell para análise completa de certificados SCCM/Configuration Manager, incluindo validação de PKI, cadeia de certificados, expiração e análise específica para servidores e estações de trabalho.

**Desenvolvido por:** Okta7 Technologies
**Consultor:** Daniel Marreiro
**Cliente:** Sinqia
**Projeto:** Endpoint Management Automation Suite

---

## Recursos Principais

### ✅ Novos Recursos Implementados (Janeiro 2026)

1. **Thumbprint do Certificado**
   - Exibido em todas as saídas de console
   - Incluído em relatórios HTML e JSON
   - Formatado como código monospace nos relatórios HTML

2. **Detecção Automática de Tipo de Computador**
   - Detecta automaticamente se é Workstation ou Server
   - Análise específica para servidores SCCM
   - Verificação de componentes: Site Server, Management Point, Distribution Point

3. **Parâmetros de Execução Flexíveis**
   - `-ComputerType`: Especifica ou detecta tipo (Workstation/Server/Auto)
   - `-IncludeDetailedChain`: Ativa verificação detalhada de revogação
   - `-ExportReport`: Exporta relatórios automaticamente
   - `-OutputPath`: Define pasta de saída personalizada

4. **Comentários Detalhados em Todas as Funções**
   - Documentação completa em formato Comment-Based Help
   - Exemplos de uso para cada função
   - Descrição de parâmetros e valores de retorno

5. **Análise Específica para Servidores SCCM**
   - Verificação de certificados Server Authentication
   - Detecção de componentes SCCM instalados
   - Alertas específicos para Management Point e Distribution Point

---

## Sintaxe

```powershell
.\Analyze-SCCM-Certificates.ps1
    [-ExportReport]
    [-OutputPath <String>]
    [-ComputerType {Workstation | Server | Auto}]
    [-IncludeDetailedChain]
```

---

## Parâmetros

### `-ExportReport`
Switch para exportar relatórios HTML e JSON automaticamente ao final da análise.

```powershell
# Exemplo
.\Analyze-SCCM-Certificates.ps1 -ExportReport
```

### `-OutputPath <String>`
Caminho onde os relatórios serão salvos.

**Default:** `$PSScriptRoot\..\..\Reports`

```powershell
# Exemplo
.\Analyze-SCCM-Certificates.ps1 -OutputPath "C:\Reports"
```

### `-ComputerType {Workstation | Server | Auto}`
Tipo de computador para análise especializada.

**Valores:**
- `Workstation`: Análise focada em estações de trabalho (cliente SCCM)
- `Server`: Análise focada em servidores (Site Server, MP, DP)
- `Auto`: Detecta automaticamente baseado no sistema operacional (padrão)

```powershell
# Detecção automática (padrão)
.\Analyze-SCCM-Certificates.ps1

# Forçar análise como servidor
.\Analyze-SCCM-Certificates.ps1 -ComputerType Server

# Forçar análise como estação
.\Analyze-SCCM-Certificates.ps1 -ComputerType Workstation
```

### `-IncludeDetailedChain`
Ativa verificação detalhada da cadeia de certificados incluindo revogação online (pode ser lento).

**Sem este parâmetro:** Análise rápida, sem verificação de revogação
**Com este parâmetro:** Análise completa com verificação de CRL

```powershell
# Análise rápida (padrão)
.\Analyze-SCCM-Certificates.ps1

# Análise completa com revogação
.\Analyze-SCCM-Certificates.ps1 -IncludeDetailedChain
```

---

## Exemplos de Uso

### Exemplo 1: Análise Básica com Detecção Automática
```powershell
.\Analyze-SCCM-Certificates.ps1
```
Executa análise básica detectando automaticamente o tipo de computador.

### Exemplo 2: Análise com Exportação de Relatórios
```powershell
.\Analyze-SCCM-Certificates.ps1 -ExportReport
```
Executa análise e exporta relatórios HTML/JSON automaticamente.

### Exemplo 3: Análise de Servidor SCCM
```powershell
.\Analyze-SCCM-Certificates.ps1 -ComputerType Server -ExportReport
```
Executa análise focada em servidor com verificação de componentes SCCM.

### Exemplo 4: Análise Completa de Estação com Verificação Detalhada
```powershell
.\Analyze-SCCM-Certificates.ps1 -ComputerType Workstation -IncludeDetailedChain -ExportReport
```
Executa análise completa incluindo verificação de revogação de certificados.

### Exemplo 5: Análise com Caminho Personalizado
```powershell
.\Analyze-SCCM-Certificates.ps1 -OutputPath "D:\Auditoria\Certificados" -ExportReport
```
Salva relatórios em pasta personalizada.

---

## Funções Principais

### 1. `Write-ColoredOutput`
Escreve mensagem colorida no console PowerShell.

**Parâmetros:**
- `Message` (String): Mensagem a ser exibida
- `Color` (String): Cor da mensagem (Green, Yellow, Red, Cyan, White, Magenta)

**Exemplo:**
```powershell
Write-ColoredOutput "Operação bem-sucedida" 'Green'
Write-ColoredOutput "Atenção: Verifique configuração" 'Yellow'
```

---

### 2. `Write-Log`
Registra mensagens em log e console com timestamp e nível de severidade.

**Parâmetros:**
- `Message` (String): Mensagem a ser registrada
- `Level` (String): Nível de severidade (INFO, SUCCESS, WARN, ERROR)

**Exemplos:**
```powershell
Write-Log "Iniciando análise de certificados" 'INFO'
Write-Log "Certificado encontrado com sucesso" 'SUCCESS'
Write-Log "Certificado expira em 5 dias" 'WARN'
Write-Log "Falha ao acessar certificado" 'ERROR'
```

**Saída:**
- Console com cor apropriada
- Arquivo de log: `SCCM-Certificates-Analysis-yyyyMMdd-HHmmss.log`

---

### 3. `Test-CertificateValidity`
Valida certificado X.509 verificando expiração, cadeia e revogação.

**Parâmetros:**
- `Certificate` (X509Certificate2): Objeto de certificado a ser validado

**Retorna:** Hashtable contendo:
- `Status`: Valid, Warning, Expired, Invalid, ChainError
- `Issues`: Array de problemas encontrados
- `DaysUntilExpiry`: Dias até expiração
- `Thumbprint`: Thumbprint do certificado
- `ChainDetails`: Detalhes da cadeia (se `-IncludeDetailedChain`)

**Exemplos:**
```powershell
# Validar certificado específico
$cert = Get-Item Cert:\LocalMachine\My\THUMBPRINT
$validation = Test-CertificateValidity -Certificate $cert
if ($validation.Status -eq 'Valid') {
    Write-Host "Certificado válido"
    Write-Host "Thumbprint: $($validation.Thumbprint)"
}

# Validar primeiro certificado do usuário
$cert = Get-ChildItem Cert:\CurrentUser\My | Select-Object -First 1
$result = Test-CertificateValidity -Certificate $cert
Write-Host "Status: $($result.Status), Dias até expirar: $($result.DaysUntilExpiry)"
```

**Notas:**
- A verificação de revogação online pode ser lenta se CRL não estiver acessível
- Use `-IncludeDetailedChain=$false` para análise rápida

---

### 4. `Get-ComputerType`
Detecta se o computador é um servidor ou estação de trabalho.

**Retorna:** String: 'Server' ou 'Workstation'

**Exemplo:**
```powershell
$type = Get-ComputerType
if ($type -eq 'Server') {
    Write-Host "Executando em servidor"
}
```

---

### 5. `Test-IsSCCMServer`
Verifica se o computador atual é um SCCM Site Server.

**Retorna:** Boolean: `$true` se for Site Server, `$false` caso contrário

**Exemplo:**
```powershell
if (Test-IsSCCMServer) {
    Write-Host "Este é um SCCM Site Server"
    # Executar verificações adicionais de servidor
}
```

---

## Fases de Análise

O script executa análise em múltiplas fases:

### Fase 1: Configuração SCCM Client
- Verifica instalação do cliente SCCM
- Lê configurações de certificado do registro
- Verifica status do serviço CcmExec

### Fase 2: Certificados Pessoais (Current User)
- Analisa certificados no store `Cert:\CurrentUser\My`
- Identifica certificados Client Authentication
- **Exibe Thumbprint de cada certificado**

### Fase 3: Certificados do Computador (Local Machine)
- Analisa certificados no store `Cert:\LocalMachine\My`
- Identifica certificados SCCM específicos
- **Exibe Thumbprint de cada certificado**
- Verifica Enhanced Key Usage (EKU)

### Fase 4: Certificados Root CA
- Lista Root CAs instalados
- Identifica CAs corporativos
- **Exibe Thumbprint de cada CA**

### Fase 5: Certificados Intermediate CA
- Lista Intermediate CAs
- Valida cadeia de certificação

### Fase 6: Verificação de Requisitos SCCM
- Valida se todos os requisitos de certificado estão atendidos
- Verifica chave privada e validade da cadeia

### Fase 7: Análise de Logs SCCM
- Examina logs SCCM para erros relacionados a certificados
- Analisa `ClientIDManagerStartup.log` e `CcmMessaging.log`

### Fase 8: Status Co-Management
- Verifica enrollment no Intune
- Analisa configuração de co-management

### **NOVA - Fase 8.1: Análise Específica de Servidor SCCM**
- **Identifica certificados Server Authentication**
- **Verifica componentes SCCM instalados:**
  - Site Server
  - Management Point
  - Distribution Point
- **Valida requisitos de certificado para cada componente**
- **Exibe Thumbprints de certificados de servidor**

### Fase 9: Recomendações
- Gera recomendações baseadas em problemas encontrados
- Sugere soluções específicas para cada tipo de problema

### Fase 10: Exportação de Resultados
- Gera relatório HTML com **Thumbprints incluídos**
- Exporta dados em JSON
- Cria arquivo de log detalhado

---

## Saídas do Script

### 1. Relatório HTML
Arquivo: `SCCM-Certificates-Report-yyyyMMdd-HHmmss.html`

**Conteúdo:**
- Resumo executivo
- **Tabela de certificados SCCM Client Authentication com Thumbprint**
- **Tabela de todos os certificados do computador com Thumbprint**
- Lista de problemas detectados
- Recomendações detalhadas
- **Badges indicando tipo de computador (Server/Workstation)**
- **Indicador se é SCCM Site Server**

### 2. Dados JSON
Arquivo: `SCCM-Certificates-Data-yyyyMMdd-HHmmss.json`

Estrutura completa de dados incluindo:
- SCCMClientCertificates (com Thumbprint)
- PersonalCertificates (com Thumbprint)
- ComputerCertificates (com Thumbprint)
- RootCACertificates (com Thumbprint)
- IntermediateCACertificates (com Thumbprint)
- ExpiredCertificates
- SCCMConfiguration
- Issues
- Recommendations

### 3. Arquivo de Log
Arquivo: `SCCM-Certificates-Analysis-yyyyMMdd-HHmmss.log`

Log cronológico de todas as operações com timestamps e níveis de severidade.

---

## Requisitos

### Sistema
- Windows PowerShell 5.1 ou superior
- PowerShell 7+ (compatível)
- Privilégios de Administrador

### Componentes Opcionais
- SCCM Client (para análise completa de cliente)
- SCCM Site Server (para análise de servidor)
- Conectividade de rede (para verificação de revogação com `-IncludeDetailedChain`)

---

## Solução de Problemas

### Problema: "Access Denied" ao acessar certificados
**Solução:** Execute o script como Administrador
```powershell
# Executar PowerShell como Administrador, depois:
.\Analyze-SCCM-Certificates.ps1
```

### Problema: Verificação de revogação muito lenta
**Solução:** Execute sem `-IncludeDetailedChain` para análise rápida
```powershell
.\Analyze-SCCM-Certificates.ps1
```

### Problema: Nenhum certificado SCCM encontrado
**Verificações:**
1. SCCM Client está instalado?
2. Group Policy está distribuindo certificados?
3. Execute: `gpupdate /force`
4. Verifique se template de certificado existe na CA

```powershell
# Forçar atualização de Group Policy
gpupdate /force

# Verificar certificados manualmente
certlm.msc  # Abre gerenciador de certificados do computador
```

### Problema: Relatório não abre automaticamente
**Solução:** Abrir manualmente o arquivo HTML da pasta de relatórios
```powershell
# Localizar relatório
Get-ChildItem "$PSScriptRoot\..\..\Reports" -Filter "SCCM-Certificates-Report*.html" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 |
    Invoke-Item
```

---

## Notas de Segurança

1. **Privilégios:** Script requer privilégios de administrador para acessar certificados do computador
2. **Logs:** Arquivos de log podem conter informações sensíveis (thumbprints, nomes de servidor)
3. **Relatórios:** Proteja relatórios HTML/JSON pois contêm informações detalhadas de PKI
4. **Revogação:** Verificação de revogação online (`-IncludeDetailedChain`) requer conectividade com CRL

---

## Changelog

### Versão 2.0 - Janeiro 2026
- ✅ **Adicionado:** Thumbprint exibido em todas as saídas de console e relatórios
- ✅ **Adicionado:** Parâmetro `-ComputerType` para especificar tipo de computador
- ✅ **Adicionado:** Parâmetro `-IncludeDetailedChain` para análise detalhada
- ✅ **Adicionado:** Detecção automática de tipo de computador
- ✅ **Adicionado:** Fase 8.1 - Análise específica para servidores SCCM
- ✅ **Adicionado:** Verificação de certificados Server Authentication
- ✅ **Adicionado:** Detecção de componentes SCCM Server (Site Server, MP, DP)
- ✅ **Adicionado:** Comentários detalhados em todas as funções (Comment-Based Help)
- ✅ **Melhorado:** Relatório HTML com badges de tipo de computador
- ✅ **Melhorado:** Sumário final diferenciado por tipo de computador
- ✅ **Melhorado:** Recomendações específicas para servidor vs estação

### Versão 1.0 - Versão Inicial
- Análise básica de certificados SCCM
- Validação de cadeia e expiração
- Geração de relatórios HTML/JSON

---

## Suporte

Para suporte técnico ou dúvidas:

**Okta7 Technologies**
Consultor: Daniel Marreiro
Cliente: Sinqia
Projeto: Endpoint Management Automation Suite

---

## Licença

Propriedade de Okta7 Technologies
Desenvolvido para Sinqia
Todos os direitos reservados
