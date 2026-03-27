import { expect } from 'chai';
import app from '../server.js';
import sharePointGraphService from '../services/sharepointGraphService.js';

const originalMethods = {
  listLibraries: sharePointGraphService.listLibraries,
  createLibrary: sharePointGraphService.createLibrary,
  updateLibrary: sharePointGraphService.updateLibrary,
  listChildren: sharePointGraphService.listChildren,
  createFolder: sharePointGraphService.createFolder,
  renameItem: sharePointGraphService.renameItem,
  listItemPermissions: sharePointGraphService.listItemPermissions,
  inviteItemPermissions: sharePointGraphService.inviteItemPermissions,
  deleteItemPermission: sharePointGraphService.deleteItemPermission
};

describe('SharePoint governance routes integration', () => {
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
      sharePointGraphService[name] = method;
    });
  });

  async function fetchJson(path, options = {}) {
    const response = await fetch(`${baseUrl}${path}`, options);
    const data = await response.json();
    return { response, data };
  }

  it('returns import preview for governance package', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/admin-governance/import/preview', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'update',
        sourceTenant: 'source-tenant',
        targetTenant: 'target-tenant',
        objects: [{ type: 'library', id: 'lib-01', name: 'Contratos' }],
        dryRun: true
      })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.preview.mode).to.equal('update');
    expect(data.data.preview.objectCount).to.equal(1);
  });

  it('returns compare preview for governance package', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'lib-01', displayName: 'Contratos', description: 'Atual' }];
    sharePointGraphService.listChildren = async () => [{ id: 'folder-01', name: 'PadraoPastas', folder: {} }];
    sharePointGraphService.listItemPermissions = async () => [{
      id: 'perm-01',
      roles: ['read'],
      grantedToIdentitiesV2: [{ user: { email: 'user@contoso.com' } }]
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/admin-governance/compare/preview', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        includeUnchanged: true,
        objects: [
          { type: 'library', siteId: 'site-01', name: 'Contratos', description: 'Atual' },
          { type: 'folder', driveId: 'drive-01', parentPath: 'Documentos', name: 'PadraoPastas' },
          { type: 'permission', driveId: 'drive-01', itemId: 'item-01', recipients: [{ email: 'user@contoso.com' }], roles: ['read'] }
        ]
      })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.preview.summary.total).to.equal(3);
  });

  it('starts compare execution and allows polling operation status', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'lib-01', displayName: 'Contratos', description: 'Atual' }];
    sharePointGraphService.listChildren = async () => [{ id: 'folder-01', name: 'PadraoPastas', folder: {} }];
    sharePointGraphService.listItemPermissions = async () => [{
      id: 'perm-01',
      roles: ['read'],
      grantedToIdentitiesV2: [{ user: { email: 'user@contoso.com' } }]
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/admin-governance/compare/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-actor': 'test-suite' },
      body: JSON.stringify({
        includeUnchanged: false,
        objects: [
          { type: 'library', siteId: 'site-01', name: 'Contratos', description: 'Esperado' },
          { type: 'folder', driveId: 'drive-01', parentPath: 'Documentos', name: 'PadraoPastas' }
        ]
      })
    });

    expect(response.status).to.equal(202);
    expect(data.success).to.equal(true);

    await new Promise((resolve) => setTimeout(resolve, 60));

    const statusResult = await fetchJson(`/api/v1/sharepoint/operations/${data.data.operationId}`);
    expect(statusResult.response.status).to.equal(200);
    expect(statusResult.data.success).to.equal(true);
    expect(statusResult.data.data.status).to.be.oneOf(['running', 'succeeded', 'partial']);

    const exportResponse = await fetch(`${baseUrl}/api/v1/sharepoint/admin-governance/compare/export?operationId=${data.data.operationId}&format=csv`);
    const exportCsv = await exportResponse.text();

    expect(exportResponse.status).to.equal(200);
    expect(exportResponse.headers.get('content-type')).to.contain('text/csv');
    expect(exportResponse.headers.get('content-disposition')).to.contain('.csv');
    expect(exportCsv).to.contain('operationId');

    const exportXlsxResponse = await fetch(`${baseUrl}/api/v1/sharepoint/admin-governance/compare/export?operationId=${data.data.operationId}&format=xlsx`);
    const exportXlsxBuffer = Buffer.from(await exportXlsxResponse.arrayBuffer());

    expect(exportXlsxResponse.status).to.equal(200);
    expect(exportXlsxResponse.headers.get('content-type')).to.contain('spreadsheetml.sheet');
    expect(exportXlsxResponse.headers.get('content-disposition')).to.contain('.xlsx');
    expect(exportXlsxBuffer.length).to.be.greaterThan(0);
  });

  it('returns 409 when exporting compare before result is available', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'lib-01', displayName: 'Contratos', description: 'Atual' }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/admin-governance/compare/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-actor': 'test-suite' },
      body: JSON.stringify({
        includeUnchanged: false,
        objects: [{ type: 'library', siteId: 'site-01', name: 'Contratos', description: 'Esperado' }]
      })
    });

    expect(response.status).to.equal(202);
    expect(data.success).to.equal(true);

    const exportResult = await fetchJson(`/api/v1/sharepoint/admin-governance/compare/export?operationId=${data.data.operationId}&format=json`);
    if (exportResult.response.status === 409) {
      expect(exportResult.data.success).to.equal(false);
      expect(exportResult.data.error.code).to.equal('SP_409');
    } else {
      expect(exportResult.response.status).to.equal(200);
      expect(exportResult.data.success).to.equal(true);
    }
  });

  it('starts import execution and allows polling operation status', async () => {
    sharePointGraphService.listChildren = async () => [];
    sharePointGraphService.createFolder = async () => ({ id: 'folder-created-01', name: 'PadraoPastas' });

    const { response, data } = await fetchJson('/api/v1/sharepoint/admin-governance/import/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-actor': 'test-suite' },
      body: JSON.stringify({
        mode: 'always',
        objects: [{ type: 'folder', driveId: 'drive-01', parentPath: 'Documentos', name: 'PadraoPastas' }],
        dryRun: false
      })
    });

    expect(response.status).to.equal(202);
    expect(data.success).to.equal(true);
    expect(data.data.operationId).to.be.a('string').and.not.empty;

    await new Promise((resolve) => setTimeout(resolve, 60));

    const statusResult = await fetchJson(`/api/v1/sharepoint/operations/${data.data.operationId}`);
    expect(statusResult.response.status).to.equal(200);
    expect(statusResult.data.success).to.equal(true);
    expect(statusResult.data.data.status).to.be.oneOf(['running', 'succeeded', 'partial']);
  });

  it('lists audit trail events with pagination metadata', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/audit/events?limit=5&offset=0');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data).to.have.property('items');
    expect(data.data).to.have.property('total');
    expect(data.data.limit).to.equal(5);
  });

  it('returns export package contract', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/admin-governance/export/package?source=site-libraries&format=json&page=2&pageSize=25');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.source).to.equal('site-libraries');
    expect(data.data.pagination.page).to.equal(2);
    expect(data.data.pagination.pageSize).to.equal(25);
  });

  it('returns error envelope for unknown operation id', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/operations/op-nao-existe');

    expect(response.status).to.equal(404);
    expect(data.success).to.equal(false);
    expect(data.error.code).to.equal('SP_404');
    expect(data).to.have.property('correlationId');
  });
});
