# Exemplos de Saída - Analyze-SCCM-Certificates.ps1

## 📋 Índice de Exemplos

1. [Execução Básica (Workstation)](#exemplo-1-execução-básica-workstation)
2. [Execução em Servidor SCCM](#exemplo-2-execução-em-servidor-sccm)
3. [Análise Detalhada com Revogação](#exemplo-3-análise-detalhada-com-revogação)
4. [Certificado com Problema](#exemplo-4-certificado-com-problema)
5. [Sem Certificados SCCM](#exemplo-5-sem-certificados-sccm)

---

## Exemplo 1: Execução Básica (Workstation)

### Comando:
```powershell
.\Analyze-SCCM-Certificates.ps1 -ExportReport
```

### Saída Console:

```
========================================================
  SINQIA - ANALISE DE CERTIFICADOS SCCM (Workstation)
  PKI Configuration for Co-Management
  Okta7 Technologies - Daniel Marreiro
========================================================

[2026-01-09 10:30:15] [INFO] Tipo de computador detectado automaticamente: Workstation

====== FASE 1: CONFIGURACAO SCCM CLIENT ======
[2026-01-09 10:30:15] [SUCCESS] SCCM Client instalado: C:\Windows\CCM\CcmExec.exe
[2026-01-09 10:30:15] [SUCCESS] Servico CcmExec: Running
[2026-01-09 10:30:15] [INFO] Versao SCCM Client: 5.00.9068.1000

====== FASE 2: CERTIFICADOS PESSOAIS (CURRENT USER) ======
[2026-01-09 10:30:16] [INFO] Encontrados 2 certificados no store Current User\My

====== FASE 3: CERTIFICADOS DO COMPUTADOR (LOCAL MACHINE) ======
[2026-01-09 10:30:16] [INFO] Encontrados 5 certificados no store LocalMachine\My
[2026-01-09 10:30:16] [SUCCESS]   [COMPUTER] CN=WORKSTATION01.contoso.com
[2026-01-09 10:30:16] [INFO]     Thumbprint: 1A2B3C4D5E6F7890ABCDEF1234567890ABCDEF12
[2026-01-09 10:30:16] [INFO]     Issuer: CN=Contoso-CA
[2026-01-09 10:30:16] [INFO]     Expira: 2026-12-31 (357 dias)
[2026-01-09 10:30:16] [SUCCESS]     Private Key: True
[2026-01-09 10:30:16] [INFO]     EKU: Client Authentication
[2026-01-09 10:30:16] [SUCCESS]     Status: Valid
[2026-01-09 10:30:16] [SUCCESS]     SCCM Client Authentication: YES

====== FASE 4: CERTIFICADOS ROOT CA ======
[2026-01-09 10:30:17] [INFO] Encontrados 82 certificados Root CA
[2026-01-09 10:30:17] [INFO]
Certificados Root CA corporativos encontrados:
[2026-01-09 10:30:17] [INFO]   CN=Contoso Root CA
[2026-01-09 10:30:17] [INFO]     Thumbprint: FEDCBA0987654321FEDCBA0987654321FEDCBA09
[2026-01-09 10:30:17] [INFO]     Expira: 2035-12-31

====== FASE 6: VERIFICACAO DE REQUISITOS SCCM ======
[2026-01-09 10:30:18] [SUCCESS] Client Authentication Certificate: FOUND
[2026-01-09 10:30:18] [SUCCESS] Valid certificates with private key: 1
[2026-01-09 10:30:18] [SUCCESS] Certificates with valid chain: 1
[2026-01-09 10:30:18] [SUCCESS] Root CA Trusted: YES

Resumo de Requisitos:
[2026-01-09 10:30:18] [SUCCESS]   [OK] Client Authentication Certificate
[2026-01-09 10:30:18] [SUCCESS]   [OK] Certificate Has Private Key
[2026-01-09 10:30:18] [SUCCESS]   [OK] Certificate Not Expired
[2026-01-09 10:30:18] [SUCCESS]   [OK] Certificate Chain Valid
[2026-01-09 10:30:18] [SUCCESS]   [OK] Root CA Trusted

====== FASE 9: RECOMENDACOES ======
[2026-01-09 10:30:19] [SUCCESS] Todos os requisitos de certificado SCCM foram atendidos!

====== FASE 10: EXPORTANDO RESULTADOS ======
[2026-01-09 10:30:19] [SUCCESS] Dados exportados: C:\Reports\SCCM-Certificates-Data-20260109-103019.json
[2026-01-09 10:30:20] [SUCCESS] Relatorio HTML gerado: C:\Reports\SCCM-Certificates-Report-20260109-103019.html

========================================================
  ANALISE CONCLUIDA
========================================================

Arquivos gerados:
  - HTML Report: C:\Reports\SCCM-Certificates-Report-20260109-103019.html
  - JSON Data: C:\Reports\SCCM-Certificates-Data-20260109-103019.json
  - Log File: C:\Reports\SCCM-Certificates-Analysis-20260109-103019.log

Configuração:
  Tipo de Computador: Workstation
  Análise Detalhada: Não (rápida)

Resumo:
  Certificados SCCM Client Auth: 1
  Problemas detectados: 0
  Certificados expirados: 0
```

---

## Exemplo 2: Execução em Servidor SCCM

### Comando:
```powershell
.\Analyze-SCCM-Certificates.ps1 -ComputerType Server -ExportReport
```

### Saída Console (Específico de Servidor):

```
========================================================
  SINQIA - ANALISE DE CERTIFICADOS SCCM (Server)
  PKI Configuration for Co-Management
  Okta7 Technologies - Daniel Marreiro
========================================================

[2026-01-09 11:00:00] [INFO] Tipo de computador especificado manualmente: Server
[2026-01-09 11:00:00] [SUCCESS] SCCM Site Server detectado

====== FASE 1: CONFIGURACAO SCCM CLIENT ======
[2026-01-09 11:00:00] [SUCCESS] SCCM Client instalado: C:\Windows\CCM\CcmExec.exe
[2026-01-09 11:00:00] [SUCCESS] Servico CcmExec: Running
[2026-01-09 11:00:00] [INFO] Versao SCCM Client: 5.00.9068.1000

====== FASE 3: CERTIFICADOS DO COMPUTADOR (LOCAL MACHINE) ======
[2026-01-09 11:00:01] [INFO] Encontrados 8 certificados no store LocalMachine\My

[2026-01-09 11:00:01] [SUCCESS]   [COMPUTER] CN=SCCMSERVER01.contoso.com
[2026-01-09 11:00:01] [INFO]     Thumbprint: 9876543210FEDCBA9876543210FEDCBA98765432
[2026-01-09 11:00:01] [INFO]     Issuer: CN=Contoso-CA
[2026-01-09 11:00:01] [INFO]     Expira: 2026-11-30 (325 dias)
[2026-01-09 11:00:01] [SUCCESS]     Private Key: True
[2026-01-09 11:00:01] [INFO]     EKU: Server Authentication, Client Authentication
[2026-01-09 11:00:01] [SUCCESS]     Status: Valid
[2026-01-09 11:00:01] [SUCCESS]     SCCM Client Authentication: YES

====== FASE 8.1: ANALISE ESPECIFICA DE SERVIDOR SCCM ======
[2026-01-09 11:00:02] [SUCCESS] Certificados de Server Authentication encontrados: 2

[2026-01-09 11:00:02] [SUCCESS]   [SERVER AUTH] CN=SCCMSERVER01.contoso.com
[2026-01-09 11:00:02] [INFO]     Thumbprint: 9876543210FEDCBA9876543210FEDCBA98765432
[2026-01-09 11:00:02] [INFO]     Expira: 2026-11-30 (325 dias)
[2026-01-09 11:00:02] [SUCCESS]     Status: Valid

[2026-01-09 11:00:02] [INFO]
Verificando componentes SCCM Server...
[2026-01-09 11:00:02] [INFO]   Site Code: PS1
[2026-01-09 11:00:02] [INFO]   Install Dir: C:\Program Files\Microsoft Configuration Manager
[2026-01-09 11:00:02] [SUCCESS]   Management Point: INSTALADO
[2026-01-09 11:00:02] [SUCCESS]   Distribution Point: INSTALADO

========================================================
  ANALISE CONCLUIDA
========================================================

Configuração:
  Tipo de Computador: Server
  SCCM Site Server: Sim
  Análise Detalhada: Não (rápida)

Resumo:
  Certificados SCCM Client Auth: 1
  Certificados Server Auth: 2
  Problemas detectados: 0
  Certificados expirados: 0
```

---

## Exemplo 3: Análise Detalhada com Revogação

### Comando:
```powershell
.\Analyze-SCCM-Certificates.ps1 -IncludeDetailedChain -ExportReport
```

### Saída Console:

```
========================================================
  SINQIA - ANALISE DE CERTIFICADOS SCCM (Workstation)
  PKI Configuration for Co-Management
  Okta7 Technologies - Daniel Marreiro
========================================================

[2026-01-09 12:00:00] [INFO] Tipo de computador detectado automaticamente: Workstation

====== FASE 3: CERTIFICADOS DO COMPUTADOR (LOCAL MACHINE) ======
[2026-01-09 12:00:01] [INFO] Encontrados 5 certificados no store LocalMachine\My
[2026-01-09 12:00:01] [SUCCESS]   [COMPUTER] CN=WORKSTATION01.contoso.com
[2026-01-09 12:00:01] [INFO]     Thumbprint: 1A2B3C4D5E6F7890ABCDEF1234567890ABCDEF12
[2026-01-09 12:00:01] [INFO]     Issuer: CN=Contoso-CA
[2026-01-09 12:00:05] [INFO]     Expira: 2026-12-31 (357 dias)  ⏱️ +4s (verificação de revogação)
[2026-01-09 12:00:05] [SUCCESS]     Private Key: True
[2026-01-09 12:00:05] [INFO]     EKU: Client Authentication
[2026-01-09 12:00:05] [SUCCESS]     Status: Valid
[2026-01-09 12:00:05] [SUCCESS]     SCCM Client Authentication: YES

...

========================================================
  ANALISE CONCLUIDA
========================================================

Configuração:
  Tipo de Computador: Workstation
  Análise Detalhada: Sim (com verificacao de revogacao)  ✅

Resumo:
  Certificados SCCM Client Auth: 1
  Problemas detectados: 0
  Certificados expirados: 0
```

---

## Exemplo 4: Certificado com Problema

### Comando:
```powershell
.\Analyze-SCCM-Certificates.ps1 -ExportReport
```

### Saída Console (Certificado Expirando):

```
====== FASE 3: CERTIFICADOS DO COMPUTADOR (LOCAL MACHINE) ======
[2026-01-09 13:00:01] [INFO] Encontrados 5 certificados no store LocalMachine\My
[2026-01-09 13:00:01] [SUCCESS]   [COMPUTER] CN=WORKSTATION02.contoso.com
[2026-01-09 13:00:01] [INFO]     Thumbprint: ABCD1234EFGH5678ABCD1234EFGH5678ABCD1234
[2026-01-09 13:00:01] [INFO]     Issuer: CN=Contoso-CA
[2026-01-09 13:00:01] [WARN]     Expira: 2026-02-05 (15 dias)  ⚠️
[2026-01-09 13:00:01] [SUCCESS]     Private Key: True
[2026-01-09 13:00:01] [INFO]     EKU: Client Authentication
[2026-01-09 13:00:01] [ERROR]     Status: Warning  ⚠️
[2026-01-09 13:00:01] [ERROR]     PROBLEMA: EXPIRING SOON on 2026-02-05  ⚠️

====== FASE 9: RECOMENDACOES ======
[2026-01-09 13:00:02] [WARN] Problemas detectados que requerem atencao:
[2026-01-09 13:00:02] [WARN] ATENCAO: 1 certificado(s) expirado(s) detectado(s)
[2026-01-09 13:00:02] [WARN]   - CN=WORKSTATION02.contoso.com (expira em 2026-02-05)

SOLUCAO: Renovar certificados expirados via Group Policy ou MMC

========================================================
  ANALISE CONCLUIDA
========================================================

Resumo:
  Certificados SCCM Client Auth: 1
  Problemas detectados: 1  ⚠️
  Certificados expirados: 1  ⚠️

PROXIMOS PASSOS:
1. Revisar relatorio HTML (aberto automaticamente)
2. Corrigir problemas de certificado identificados
3. Reiniciar servico SCCM: Restart-Service CcmExec
4. Tentar enrollment Azure AD novamente
```

### Saída Console (Cadeia Inválida):

```
====== FASE 3: CERTIFICADOS DO COMPUTADOR (LOCAL MACHINE) ======
[2026-01-09 13:30:01] [SUCCESS]   [COMPUTER] CN=WORKSTATION03.contoso.com
[2026-01-09 13:30:01] [INFO]     Thumbprint: 5678ABCD1234EFGH5678ABCD1234EFGH5678ABCD
[2026-01-09 13:30:01] [INFO]     Issuer: CN=Contoso-SubCA
[2026-01-09 13:30:01] [INFO]     Expira: 2026-12-31 (357 dias)
[2026-01-09 13:30:01] [SUCCESS]     Private Key: True
[2026-01-09 13:30:01] [INFO]     EKU: Client Authentication
[2026-01-09 13:30:01] [ERROR]     Status: ChainError  ❌
[2026-01-09 13:30:01] [ERROR]     PROBLEMA: CHAIN INVALID: A certificate chain processed, but terminated in a root certificate which is not trusted  ❌

====== FASE 9: RECOMENDACOES ======
[2026-01-09 13:30:02] [WARN] Problemas detectados que requerem atencao:

PROBLEMA: Cadeia de certificados invalida

SOLUCAO:
1. Verificar se Root CA esta no store LocalMachine\Root
2. Verificar se Intermediate CAs estao no store LocalMachine\CA
3. Executar: certutil -verify -urlfetch <certificado>
4. Verificar conectividade com CRL (Certificate Revocation List)
5. Verificar se AIA (Authority Information Access) esta acessivel

========================================================
  ANALISE CONCLUIDA
========================================================

Resumo:
  Certificados SCCM Client Auth: 1
  Problemas detectados: 2  ❌
  Certificados expirados: 0

PROXIMOS PASSOS:
1. Revisar relatorio HTML (aberto automaticamente)
2. Corrigir problemas de certificado identificados
3. Reiniciar servico SCCM: Restart-Service CcmExec
4. Tentar enrollment Azure AD novamente
```

---

## Exemplo 5: Sem Certificados SCCM

### Comando:
```powershell
.\Analyze-SCCM-Certificates.ps1 -ExportReport
```

### Saída Console:

```
========================================================
  SINQIA - ANALISE DE CERTIFICADOS SCCM (Workstation)
  PKI Configuration for Co-Management
  Okta7 Technologies - Daniel Marreiro
========================================================

[2026-01-09 14:00:00] [INFO] Tipo de computador detectado automaticamente: Workstation

====== FASE 1: CONFIGURACAO SCCM CLIENT ======
[2026-01-09 14:00:00] [SUCCESS] SCCM Client instalado: C:\Windows\CCM\CcmExec.exe
[2026-01-09 14:00:00] [SUCCESS] Servico CcmExec: Running
[2026-01-09 14:00:00] [INFO] Versao SCCM Client: 5.00.9068.1000

====== FASE 3: CERTIFICADOS DO COMPUTADOR (LOCAL MACHINE) ======
[2026-01-09 14:00:01] [INFO] Encontrados 3 certificados no store LocalMachine\My
[2026-01-09 14:00:01] [INFO] Nenhum certificado com Client Authentication EKU encontrado  ❌

====== FASE 6: VERIFICACAO DE REQUISITOS SCCM ======
[2026-01-09 14:00:02] [ERROR] Client Authentication Certificate: NOT FOUND  ❌
[2026-01-09 14:00:02] [ERROR] Nenhum certificado valido com chave privada encontrado

Resumo de Requisitos:
[2026-01-09 14:00:02] [ERROR]   [FALHA] Client Authentication Certificate  ❌
[2026-01-09 14:00:02] [ERROR]   [FALHA] Certificate Has Private Key  ❌
[2026-01-09 14:00:02] [ERROR]   [FALHA] Certificate Not Expired  ❌
[2026-01-09 14:00:02] [ERROR]   [FALHA] Certificate Chain Valid  ❌
[2026-01-09 14:00:02] [SUCCESS]   [OK] Root CA Trusted

====== FASE 9: RECOMENDACOES ======
[2026-01-09 14:00:03] [WARN] Problemas detectados que requerem atencao:

PROBLEMA CRITICO: Nenhum certificado Client Authentication encontrado

SOLUCAO:
1. Verificar se PKI esta configurada no dominio
2. Verificar se Group Policy esta distribuindo certificados
3. Executar: gpupdate /force
4. Verificar se template de certificado existe:
   - Abrir MMC > Certificates > Computer > Personal
   - Request New Certificate
   - Procurar por 'ConfigMgr Client Certificate' ou similar
5. Verificar logs: certreq.log, certutil.log

RELACAO COM PROBLEMA DE ENROLLMENT:
- Certificados SCCM sao necessarios para co-management
- Co-management e pre-requisito para Hybrid Azure AD Join em alguns cenarios
- Certificados invalidos impedem comunicacao SCCM <-> Intune
- Isto pode estar contribuindo para falhas de enrollment Azure AD

PROXIMOS PASSOS:
1. Corrigir problemas de certificado listados acima
2. Reiniciar servico CcmExec: Restart-Service CcmExec
3. Executar machine policy update: Invoke-WmiMethod -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000021}'
4. Verificar logs SCCM apos correcoes
5. Tentar enrollment Azure AD novamente

========================================================
  ANALISE CONCLUIDA
========================================================

Resumo:
  Certificados SCCM Client Auth: 0  ❌
  Problemas detectados: 4  ❌
  Certificados expirados: 0

PROXIMOS PASSOS:
1. Revisar relatorio HTML (aberto automaticamente)
2. Corrigir problemas de certificado identificados
3. Reiniciar servico SCCM: Restart-Service CcmExec
4. Tentar enrollment Azure AD novamente
```

---

## 📊 Exemplo de Relatório HTML

### Estrutura do Relatório

```html
<!DOCTYPE html>
<html>
<head>
    <title>SCCM Certificates Analysis - Sinqia</title>
    <style>
        /* CSS com badges, tabelas, cores, etc. */
    </style>
</head>
<body>
    <!-- Cabeçalho com badges -->
    <h1>Analise de Certificados SCCM - Sinqia
        <span class="badge badge-workstation">Workstation</span>
    </h1>

    <!-- Informações do sistema -->
    <p><strong>Data:</strong> 09/01/2026 10:30:19</p>
    <p><strong>Dispositivo:</strong> WORKSTATION01</p>
    <p><strong>Tipo:</strong> Workstation</p>

    <!-- Resumo Executivo -->
    <h2>Resumo Executivo</h2>
    <table>
        <tr><th>Categoria</th><th>Quantidade</th><th>Status</th></tr>
        <tr>
            <td>Certificados SCCM Client Auth</td>
            <td>1</td>
            <td><span style="color:green">OK</span></td>
        </tr>
        ...
    </table>

    <!-- Tabela de Certificados SCCM Client Authentication -->
    <h3>Certificados SCCM Client Authentication</h3>
    <table>
        <tr>
            <th>Subject</th>
            <th>Thumbprint</th>  ✅
            <th>Expiracao</th>
            <th>Dias</th>
            <th>Status</th>
        </tr>
        <tr>
            <td>CN=WORKSTATION01.contoso.com</td>
            <td><code>1A2B3C4D5E6F7890ABCDEF1234567890ABCDEF12</code></td>  ✅
            <td>2026-12-31</td>
            <td>357</td>
            <td style='color:green'>Valid</td>
        </tr>
    </table>

    <!-- Tabela de Todos os Certificados do Computador -->
    <h3>Todos os Certificados do Computador</h3>
    <table>
        <tr>
            <th>Subject</th>
            <th>Thumbprint</th>  ✅
            <th>Issuer</th>
            <th>EKU</th>
            <th>Private Key</th>
            <th>Expiracao</th>
            <th>Status</th>
        </tr>
        <tr>
            <td>CN=WORKSTATION01.contoso.com</td>
            <td><code>1A2B3C4D5E6F7890ABCDEF1234567890ABCDEF12</code></td>  ✅
            <td>CN=Contoso-CA</td>
            <td>Client Authentication</td>
            <td>Sim</td>
            <td>2026-12-31</td>
            <td style='color:green'>Valid</td>
        </tr>
    </table>

    <!-- Problemas (se houver) -->
    <div class='success'>
        <h3>Nenhum problema detectado</h3>
    </div>

    <!-- Rodapé -->
    <footer>
        <p><strong>Okta7 Technologies</strong> | Consultor: Daniel Marreiro | Cliente: Sinqia</p>
        <p>Projeto: Endpoint Management Automation Suite</p>
    </footer>
</body>
</html>
```

---

## 📄 Exemplo de Dados JSON

### Estrutura do JSON Exportado

```json
{
  "SCCMClientCertificates": [
    {
      "Subject": "CN=WORKSTATION01.contoso.com",
      "Issuer": "CN=Contoso-CA",
      "Thumbprint": "1A2B3C4D5E6F7890ABCDEF1234567890ABCDEF12",
      "NotBefore": "2024-01-01T00:00:00",
      "NotAfter": "2026-12-31T23:59:59",
      "EnhancedKeyUsage": "Client Authentication",
      "HasPrivateKey": true,
      "SerialNumber": "1234567890ABCDEF",
      "Status": "Valid",
      "Issues": [],
      "DaysUntilExpiry": 357
    }
  ],
  "PersonalCertificates": [...],
  "ComputerCertificates": [
    {
      "Subject": "CN=WORKSTATION01.contoso.com",
      "Issuer": "CN=Contoso-CA",
      "Thumbprint": "1A2B3C4D5E6F7890ABCDEF1234567890ABCDEF12",
      "NotBefore": "2024-01-01T00:00:00",
      "NotAfter": "2026-12-31T23:59:59",
      "EnhancedKeyUsage": "Client Authentication",
      "HasPrivateKey": true,
      "SerialNumber": "1234567890ABCDEF",
      "Status": "Valid",
      "Issues": [],
      "DaysUntilExpiry": 357
    }
  ],
  "RootCACertificates": [
    {
      "Subject": "CN=Contoso Root CA",
      "Thumbprint": "FEDCBA0987654321FEDCBA0987654321FEDCBA09",
      "NotAfter": "2035-12-31T23:59:59",
      "Status": "Valid"
    }
  ],
  "IntermediateCACertificates": [...],
  "ExpiredCertificates": [],
  "SCCMConfiguration": {
    "CcmExecStatus": "Running",
    "ClientVersion": "5.00.9068.1000",
    "CertificateStore": "LocalMachine\\My",
    "SiteCode": "PS1"
  },
  "Issues": [],
  "Recommendations": [
    "Certificate configuration appears healthy"
  ]
}
```

---

## 📝 Notas sobre as Saídas

### Códigos de Cor no Console

- **Verde (Green):** ✅ Sucesso, tudo OK
- **Branco (White):** ℹ️ Informação
- **Amarelo (Yellow):** ⚠️ Aviso, atenção necessária
- **Vermelho (Red):** ❌ Erro, ação imediata necessária
- **Ciano (Cyan):** 🔹 Títulos e seções

### Emojis de Referência

- ✅ - Operação bem-sucedida
- ❌ - Falha ou erro
- ⚠️ - Aviso ou atenção
- ℹ️ - Informação
- 🔹 - Seção ou título
- ⏱️ - Operação demorada
- 🖥️ - Servidor
- 💻 - Estação de trabalho

---

## 🔍 Como Usar Estes Exemplos

1. **Compare sua saída** com os exemplos acima
2. **Identifique problemas** pelos códigos de cor
3. **Anote Thumbprints** de certificados problemáticos
4. **Siga recomendações** específicas exibidas
5. **Consulte documentação** para detalhes

---

**Okta7 Technologies | Daniel Marreiro | Sinqia Project**
**Última atualização:** 09 de Janeiro de 2026
