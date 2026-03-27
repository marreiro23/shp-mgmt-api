import { expect } from 'chai';
import compareService from '../services/compareService.js';
import sharePointGraphService from '../services/sharepointGraphService.js';

const originalMethods = {
  listLibraries: sharePointGraphService.listLibraries,
  listChildren: sharePointGraphService.listChildren,
  listItemPermissions: sharePointGraphService.listItemPermissions
};

describe('CompareService engine', () => {
  afterEach(() => {
    Object.entries(originalMethods).forEach(([name, method]) => {
      sharePointGraphService[name] = method;
    });
  });

  it('validates supported types and reports order by dependency', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'lib-01', displayName: 'BibliotecaA', description: 'Atual' }];
    sharePointGraphService.listChildren = async () => [{ id: 'folder-01', name: 'PastaA', folder: {} }];
    sharePointGraphService.listItemPermissions = async () => [{
      id: 'perm-01',
      roles: ['read'],
      grantedToIdentitiesV2: [{ user: { email: 'user@contoso.com' } }]
    }];

    const normalized = compareService.normalizeCompareRequest({
      includeUnchanged: true,
      objects: [
        { type: 'permission', driveId: 'd1', itemId: 'i1', recipients: [{ email: 'user@contoso.com' }], roles: ['read'] },
        { type: 'folder', driveId: 'd1', parentPath: 'Documentos', name: 'PastaA' },
        { type: 'library', siteId: 's1', name: 'BibliotecaA', description: 'Atual' }
      ]
    });

    compareService.validateCompareRequest(normalized);
    const preview = await compareService.previewCompare(normalized);

    expect(preview.executionOrder).to.deep.equal(['library', 'folder', 'permission']);
    expect(preview.summary.different).to.equal(0);
    expect(preview.summary.missing).to.equal(0);
  });

  it('detects missing and different objects', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'lib-01', displayName: 'BibliotecaA', description: 'Descricao atual' }];
    sharePointGraphService.listChildren = async () => [];
    sharePointGraphService.listItemPermissions = async () => [{
      id: 'perm-01',
      roles: ['read'],
      grantedToIdentitiesV2: [{ user: { email: 'user@contoso.com' } }]
    }];

    const normalized = compareService.normalizeCompareRequest({
      includeUnchanged: false,
      objects: [
        { type: 'library', siteId: 's1', name: 'BibliotecaA', description: 'Descricao esperada' },
        { type: 'folder', driveId: 'd1', parentPath: 'Documentos', name: 'PastaNaoExiste' },
        { type: 'permission', driveId: 'd1', itemId: 'i1', recipients: [{ email: 'user@contoso.com' }], roles: ['write'] }
      ]
    });

    compareService.validateCompareRequest(normalized);
    const preview = await compareService.previewCompare(normalized);

    expect(preview.summary.different).to.equal(2);
    expect(preview.summary.missing).to.equal(1);
    expect(preview.details.every((item) => item.status !== 'equal')).to.equal(true);
  });
});
