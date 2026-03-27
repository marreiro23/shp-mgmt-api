## Contribuindo para shp-mgmt-api

Este repositório mantém apenas o fluxo SharePoint Online via Microsoft Graph.

## Princípios

- Preserve o escopo ativo em `/api/v1/sharepoint/*`.
- Use autenticação por certificado; não reintroduza `CLIENT_SECRET` no fluxo principal.
- Não restaure referências SCCM, GPO, Autopilot, Intune ou Tenable fora de `backup/`.
- Mantenha o envelope de erro estável: `success`, `correlationId`, `error.code`, `error.message`.

## Estrutura ativa

```text
api/
config/
scripts/
web/
certs/
backup/legacy-2026-03-12/
```

## Fluxo recomendado

```powershell
cd .\api
npm install
npm run test:lts

cd ..
.\scripts\Validate-SharePointSetup.ps1
.\scripts\Test-SharePointGraphEndpoints.ps1
```

## Scripts ativos

- `scripts/Start-API-Background.ps1`
- `scripts/Validate-SharePointSetup.ps1`
- `scripts/Test-SharePointGraphEndpoints.ps1`
- `scripts/Invoke-SharePointFileOps.ps1`
- `scripts/common/Get-ProjectConfig.ps1`

## Convenções de mudança

- Alterações em JavaScript devem permanecer pequenas e focadas.
- Prefira ajustes no serviço `sharepointGraphService.js` para integração Graph.
- Atualize a documentação quando mudar contrato, auth ou estrutura ativa.
- Se precisar tocar no legado, faça isso somente dentro de `backup/legacy-2026-03-12/`.