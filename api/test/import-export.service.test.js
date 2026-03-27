import { expect } from 'chai';
import importExportService from '../services/importExportService.js';
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

describe('ImportExportService engine', () => {
  afterEach(() => {
    Object.entries(originalMethods).forEach(([name, method]) => {
      sharePointGraphService[name] = method;
    });
  });

  it('orders dependencies in preview as library -> folder -> permission', () => {
    const normalized = importExportService.normalizeImportRequest({
      mode: 'always',
      dryRun: true,
      objects: [
        { type: 'permission', driveId: 'd1', itemId: 'i1', recipients: [{ email: 'user@contoso.com' }] },
        { type: 'folder', driveId: 'd1', name: 'PastaA' },
        { type: 'library', siteId: 's1', name: 'BibliotecaA' }
      ]
    });

    importExportService.validateImportRequest(normalized);
    const preview = importExportService.previewImport(normalized);

    expect(preview.executionOrder.map((item) => item.type)).to.deep.equal(['library', 'folder', 'permission']);
  });

  it('executes skip-if-exists mode and skips existing objects', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'lib-01', displayName: 'BibliotecaA' }];
    sharePointGraphService.listChildren = async () => [{ id: 'folder-01', name: 'PastaA', folder: {} }];
    sharePointGraphService.listItemPermissions = async () => [{
      id: 'perm-01',
      roles: ['read'],
      grantedToIdentitiesV2: [{ user: { email: 'user@contoso.com' } }]
    }];

    const normalized = importExportService.normalizeImportRequest({
      mode: 'skip-if-exists',
      dryRun: false,
      objects: [
        { type: 'library', siteId: 's1', name: 'BibliotecaA' },
        { type: 'folder', driveId: 'd1', parentPath: 'Documentos', name: 'PastaA' },
        {
          type: 'permission',
          driveId: 'd1',
          itemId: 'i1',
          recipients: [{ email: 'user@contoso.com' }],
          roles: ['read']
        }
      ]
    });

    importExportService.validateImportRequest(normalized);
    const result = await importExportService.executeImport(normalized);

    expect(result.status).to.equal('succeeded');
    expect(result.skipped).to.equal(3);
    expect(result.created).to.equal(0);
    expect(result.updated).to.equal(0);
  });

  it('executes update mode for existing objects', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'lib-01', displayName: 'BibliotecaA' }];
    sharePointGraphService.updateLibrary = async () => ({ id: 'lib-01', displayName: 'BibliotecaA' });

    sharePointGraphService.listChildren = async () => [{ id: 'folder-01', name: 'PastaA', folder: {} }];
    sharePointGraphService.renameItem = async () => ({ id: 'folder-01', name: 'PastaA' });

    sharePointGraphService.listItemPermissions = async () => [{
      id: 'perm-01',
      roles: ['read'],
      grantedToIdentitiesV2: [{ user: { email: 'user@contoso.com' } }]
    }];
    sharePointGraphService.deleteItemPermission = async () => true;
    sharePointGraphService.inviteItemPermissions = async () => ({ id: 'perm-02' });

    const normalized = importExportService.normalizeImportRequest({
      mode: 'update',
      dryRun: false,
      objects: [
        { type: 'library', siteId: 's1', name: 'BibliotecaA' },
        { type: 'folder', driveId: 'd1', parentPath: 'Documentos', name: 'PastaA' },
        {
          type: 'permission',
          driveId: 'd1',
          itemId: 'i1',
          recipients: [{ email: 'user@contoso.com' }],
          roles: ['read']
        }
      ]
    });

    importExportService.validateImportRequest(normalized);
    const result = await importExportService.executeImport(normalized);

    expect(result.status).to.equal('succeeded');
    expect(result.updated).to.equal(3);
    expect(result.errors).to.have.lengthOf(0);
  });
});
