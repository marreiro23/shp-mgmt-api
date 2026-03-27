import { expect } from 'chai';
import app from '../server.js';
import appRegistrationAdminService from '../services/appRegistrationAdminService.js';

const originalMethods = {
  getAdministrationMetadata: appRegistrationAdminService.getAdministrationMetadata,
  normalizeRequest: appRegistrationAdminService.normalizeRequest,
  validateRequest: appRegistrationAdminService.validateRequest,
  buildCommandPreview: appRegistrationAdminService.buildCommandPreview,
  executeUpdateScopes: appRegistrationAdminService.executeUpdateScopes
};

describe('Admin app registration routes', () => {
  let server;
  let baseUrl;

  before((done) => {
    server = app.listen(0, '127.0.0.1', () => {
      const address = server.address();
      baseUrl = `http://127.0.0.1:${address.port}`;
      done();
    });
  });

  after((done) => {
    server.close(done);
  });

  afterEach(() => {
    Object.entries(originalMethods).forEach(([name, method]) => {
      appRegistrationAdminService[name] = method;
    });
  });

  async function fetchJson(path, options = {}) {
    const response = await fetch(`${baseUrl}${path}`, options);
    const data = await response.json();
    return { response, data };
  }

  it('returns app registration metadata', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/admin/app-registration');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data).to.have.property('recommendedApplicationPermissions');
    expect(data.data).to.have.property('commandTemplate');
  });

  it('builds a preview command without executing the script', async () => {
    appRegistrationAdminService.normalizeRequest = (body) => ({
      tenantId: body.tenantId,
      clientId: body.clientId,
      applicationObjectId: '',
      graphApplicationPermissions: ['Sites.ReadWrite.All'],
      grantAdminConsentAssignments: false,
      whatIf: true,
      execute: false
    });
    appRegistrationAdminService.validateRequest = () => {};
    appRegistrationAdminService.getAdministrationMetadata = () => ({ executionEnabled: false });
    appRegistrationAdminService.buildCommandPreview = () => 'pwsh -File Update-GraphAppScopes.ps1 -WhatIf';

    const { response, data } = await fetchJson('/api/v1/sharepoint/admin/update-scopes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tenantId: 'tenant-01', clientId: 'client-01' })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.executionPerformed).to.equal(false);
    expect(data.data.commandPreview).to.contain('Update-GraphAppScopes.ps1');
  });

  it('executes the script path when enabled', async () => {
    appRegistrationAdminService.normalizeRequest = (body) => ({
      tenantId: body.tenantId,
      clientId: body.clientId,
      applicationObjectId: '',
      graphApplicationPermissions: ['Sites.ReadWrite.All'],
      grantAdminConsentAssignments: true,
      whatIf: false,
      execute: true
    });
    appRegistrationAdminService.validateRequest = () => {};
    appRegistrationAdminService.getAdministrationMetadata = () => ({ executionEnabled: true });
    appRegistrationAdminService.buildCommandPreview = () => 'pwsh -File Update-GraphAppScopes.ps1';
    appRegistrationAdminService.executeUpdateScopes = async () => ({
      exitCode: 0,
      parsed: { ClientId: 'client-01', UpdatedGraphAppPermissions: ['Sites.ReadWrite.All'] }
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/admin/update-scopes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tenantId: 'tenant-01', clientId: 'client-01', execute: true })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.executionPerformed).to.equal(true);
    expect(data.data.execution.parsed.ClientId).to.equal('client-01');
  });
});
