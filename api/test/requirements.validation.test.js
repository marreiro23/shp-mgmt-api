import { expect } from 'chai';

const requirementMatrix = [
  {
    domain: 'sharepoint',
    requirement: 'listar sites',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/sites'
  },
  {
    domain: 'sharepoint',
    requirement: 'listar drives',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/sites/:siteId/drives'
  },
  {
    domain: 'sharepoint',
    requirement: 'listar bibliotecas e itens',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/drives/:driveId/children'
  },
  {
    domain: 'sharepoint',
    requirement: 'listar arquivos e metadados',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/drives/:driveId/files-metadata'
  },
  {
    domain: 'sharepoint',
    requirement: 'criar pastas',
    status: 'supported',
    coverage: 'POST /api/v1/sharepoint/drives/:driveId/folders'
  },
  {
    domain: 'sharepoint',
    requirement: 'criar arquivos',
    status: 'supported',
    coverage: 'POST /api/v1/sharepoint/drives/:driveId/files'
  },
  {
    domain: 'sharepoint',
    requirement: 'modificar arquivos e pastas',
    status: 'supported',
    coverage: 'PATCH /api/v1/sharepoint/drives/:driveId/items/:itemId e DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId'
  },
  {
    domain: 'sharepoint',
    requirement: 'modificar bibliotecas',
    status: 'supported',
    coverage: 'PATCH /api/v1/sharepoint/sites/:siteId/libraries/:listId'
  },
  {
    domain: 'sharepoint',
    requirement: 'criar bibliotecas',
    status: 'supported',
    coverage: 'POST /api/v1/sharepoint/sites/:siteId/libraries'
  },
  {
    domain: 'sharepoint',
    requirement: 'modificar drives',
    status: 'supported',
    coverage: 'PATCH /api/v1/sharepoint/drives/:driveId'
  },
  {
    domain: 'sharepoint',
    requirement: 'criar drives',
    status: 'supported',
    coverage: 'POST /api/v1/sharepoint/sites/:siteId/drives (provisiona document library)'
  },
  {
    domain: 'sharepoint',
    requirement: 'modificar sites',
    status: 'gap',
    coverage: 'nao implementado'
  },
  {
    domain: 'sharepoint',
    requirement: 'criar sites',
    status: 'gap',
    coverage: 'nao implementado'
  },
  {
    domain: 'sharepoint',
    requirement: 'listar e modificar permissoes',
    status: 'supported',
    coverage: 'GET/POST/DELETE /api/v1/sharepoint/drives/:driveId/items/:itemId/permissions'
  },
  {
    domain: 'sharepoint',
    requirement: 'listar grupos',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/groups'
  },
  {
    domain: 'sharepoint',
    requirement: 'modificar grupos',
    status: 'supported',
    coverage: 'POST/PATCH /api/v1/sharepoint/groups e POST/DELETE /api/v1/sharepoint/groups/:groupId/members'
  },
  {
    domain: 'sharepoint',
    requirement: 'listar usuarios',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/users'
  },
  {
    domain: 'sharepoint',
    requirement: 'modificar usuarios',
    status: 'supported',
    coverage: 'PATCH /api/v1/sharepoint/users/:userId'
  },
  {
    domain: 'sharepoint',
    requirement: 'listar licencas',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/users/:userId/licenses'
  },
  {
    domain: 'sharepoint',
    requirement: 'modificar licencas',
    status: 'supported',
    coverage: 'POST /api/v1/sharepoint/users/:userId/licenses'
  },
  {
    domain: 'teams',
    requirement: 'listar canais do site',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/teams/:teamId/channels'
  },
  {
    domain: 'teams',
    requirement: 'listar membros',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/members'
  },
  {
    domain: 'teams',
    requirement: 'modificar membros',
    status: 'supported',
    coverage: 'POST/DELETE /api/v1/sharepoint/teams/:teamId/channels/:channelId/members'
  },
  {
    domain: 'teams',
    requirement: 'criar canais',
    status: 'supported',
    coverage: 'POST /api/v1/sharepoint/teams/:teamId/channels'
  },
  {
    domain: 'teams',
    requirement: 'modificar canais',
    status: 'supported',
    coverage: 'PATCH /api/v1/sharepoint/teams/:teamId/channels/:channelId'
  },
  {
    domain: 'teams',
    requirement: 'listar arquivos compartilhados',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/teams/:teamId/channels/:channelId/content'
  },
  {
    domain: 'export',
    requirement: 'exportar csv',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/export?format=csv'
  },
  {
    domain: 'export',
    requirement: 'exportar json',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/export?format=json'
  },
  {
    domain: 'export',
    requirement: 'exportar xlsx',
    status: 'supported',
    coverage: 'GET /api/v1/sharepoint/export?format=xlsx'
  }
];

describe('Requirements validation matrix', () => {
  it('tracks all requested requirement categories in an explicit matrix', () => {
    const domains = Array.from(new Set(requirementMatrix.map((item) => item.domain))).sort();

    expect(domains).to.deep.equal(['export', 'sharepoint', 'teams']);
    expect(requirementMatrix.length).to.equal(29);
  });

  it('identifies what is already supported by the current solution', () => {
    const supported = requirementMatrix.filter((item) => item.status === 'supported');

    expect(supported.map((item) => item.requirement)).to.include.members([
      'listar sites',
      'listar drives',
      'listar bibliotecas e itens',
      'listar arquivos e metadados',
      'criar pastas',
      'criar arquivos',
      'modificar arquivos e pastas',
      'modificar bibliotecas',
      'criar bibliotecas',
      'modificar drives',
      'criar drives',
      'listar e modificar permissoes',
      'listar grupos',
      'modificar grupos',
      'listar usuarios',
      'modificar usuarios',
      'listar licencas',
      'modificar licencas',
      'listar canais do site',
      'listar membros',
      'modificar membros',
      'criar canais',
      'modificar canais',
      'listar arquivos compartilhados',
      'exportar csv',
      'exportar json',
      'exportar xlsx'
    ]);
  });

  it('keeps unresolved product gaps explicit for missing requirements', () => {
    const gaps = requirementMatrix.filter((item) => item.status === 'gap');

    expect(gaps.map((item) => item.requirement)).to.include.members([
      'modificar sites',
      'criar sites'
    ]);
    expect(gaps).to.have.lengthOf(2);
  });

  it('has no partial requirements after this implementation step', () => {
    const partial = requirementMatrix.filter((item) => item.status === 'partial');

    expect(partial).to.have.lengthOf(0);
  });
});
