import { expect } from 'chai';
import app from '../server.js';
import sharePointGraphService from '../services/sharepointGraphService.js';

const originalMethods = {
  listSites: sharePointGraphService.listSites,
  listDrives: sharePointGraphService.listDrives,
  listLibraries: sharePointGraphService.listLibraries,
  createLibrary: sharePointGraphService.createLibrary,
  updateLibrary: sharePointGraphService.updateLibrary,
  createDrive: sharePointGraphService.createDrive,
  updateDrive: sharePointGraphService.updateDrive,
  listGroups: sharePointGraphService.listGroups,
  createGroup: sharePointGraphService.createGroup,
  updateGroup: sharePointGraphService.updateGroup,
  listUsers: sharePointGraphService.listUsers,
  updateUser: sharePointGraphService.updateUser,
  listUserLicenses: sharePointGraphService.listUserLicenses,
  assignUserLicenses: sharePointGraphService.assignUserLicenses,
  listChildren: sharePointGraphService.listChildren,
  createFolder: sharePointGraphService.createFolder,
  uploadTextFile: sharePointGraphService.uploadTextFile,
  renameItem: sharePointGraphService.renameItem,
  deleteItem: sharePointGraphService.deleteItem,
  listDriveFilesWithMetadata: sharePointGraphService.listDriveFilesWithMetadata,
  listItemPermissions: sharePointGraphService.listItemPermissions,
  inviteItemPermissions: sharePointGraphService.inviteItemPermissions,
  deleteItemPermission: sharePointGraphService.deleteItemPermission,
  listTeamChannels: sharePointGraphService.listTeamChannels,
  createTeamChannel: sharePointGraphService.createTeamChannel,
  updateTeamChannel: sharePointGraphService.updateTeamChannel,
  listChannelMembers: sharePointGraphService.listChannelMembers,
  listChannelContent: sharePointGraphService.listChannelContent,
  addChannelMember: sharePointGraphService.addChannelMember,
  removeChannelMember: sharePointGraphService.removeChannelMember,
  addGroupMember: sharePointGraphService.addGroupMember,
  removeGroupMember: sharePointGraphService.removeGroupMember
};

describe('SharePoint routes integration', () => {
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
    const data = response.status === 204 ? null : await response.json();
    return { response, data };
  }

  it('lists sharepoint sites', async () => {
    sharePointGraphService.listSites = async (search, top) => [{
      id: 'site-01',
      displayName: `Site ${search}`,
      top
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/sites?search=Financeiro&top=10');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.count).to.equal(1);
    expect(data.data[0].displayName).to.equal('Site Financeiro');
  });

  it('returns local inventory database', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/inventory/database');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.summary).to.be.an('object');
    expect(data.data.data).to.be.an('object');
  });

  it('lists sharepoint drives for a site', async () => {
    sharePointGraphService.listDrives = async (siteId) => [{
      id: 'drive-01',
      name: `Documentos ${siteId}`
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/sites/site-01/drives');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data[0].name).to.equal('Documentos site-01');
  });

  it('lists sharepoint libraries for a site', async () => {
    sharePointGraphService.listLibraries = async (siteId) => [{
      id: 'list-01',
      displayName: `Biblioteca ${siteId}`,
      drive: { id: 'drive-01', name: 'Biblioteca drive' }
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/sites/site-01/libraries');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data[0].displayName).to.equal('Biblioteca site-01');
  });

  it('creates a sharepoint library', async () => {
    sharePointGraphService.createLibrary = async (siteId, input) => ({
      id: 'list-02',
      displayName: input.displayName,
      siteId,
      drive: { id: 'drive-02', name: input.displayName }
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/sites/site-01/libraries', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: 'Contratos 2026', description: 'Docs do ano' })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.drive.id).to.equal('drive-02');
  });

  it('updates a sharepoint library', async () => {
    sharePointGraphService.updateLibrary = async (siteId, listId, input) => ({
      id: listId,
      siteId,
      displayName: input.displayName,
      description: input.description,
      drive: { id: 'drive-02', name: input.displayName }
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/sites/site-01/libraries/list-01', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: 'Contratos Atualizados', description: 'Nova descricao' })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.displayName).to.equal('Contratos Atualizados');
  });

  it('creates a sharepoint drive by provisioning a document library', async () => {
    sharePointGraphService.createDrive = async (siteId, input) => ({
      id: 'list-03',
      siteId,
      displayName: input.displayName,
      drive: { id: 'drive-03', name: input.displayName }
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/sites/site-01/drives', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: 'Drive Operacional' })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.drive.id).to.equal('drive-03');
  });

  it('updates a sharepoint drive', async () => {
    sharePointGraphService.updateDrive = async (driveId, input) => ({
      id: driveId,
      name: input.name,
      description: input.description
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Drive Renomeado', description: 'Descricao atualizada' })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.name).to.equal('Drive Renomeado');
  });

  it('lists groups', async () => {
    sharePointGraphService.listGroups = async (search) => [{ id: 'group-01', displayName: `Grupo ${search}` }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/groups?search=Financeiro');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data[0].displayName).to.equal('Grupo Financeiro');
  });

  it('creates a group', async () => {
    sharePointGraphService.createGroup = async (input) => ({ id: 'group-02', ...input });

    const { response, data } = await fetchJson('/api/v1/sharepoint/groups', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: 'Time Financeiro', mailNickname: 'financeiro' })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.mailNickname).to.equal('financeiro');
  });

  it('updates a group', async () => {
    sharePointGraphService.updateGroup = async (groupId, input) => ({ id: groupId, ...input });

    const { response, data } = await fetchJson('/api/v1/sharepoint/groups/group-01', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ description: 'Atualizado' })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.description).to.equal('Atualizado');
  });

  it('lists users', async () => {
    sharePointGraphService.listUsers = async (search) => [{ id: 'user-01', displayName: `Usuario ${search}` }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/users?search=Maria');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data[0].displayName).to.equal('Usuario Maria');
  });

  it('updates a user', async () => {
    sharePointGraphService.updateUser = async (userId, input) => ({ id: userId, ...input });

    const { response, data } = await fetchJson('/api/v1/sharepoint/users/user-01', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jobTitle: 'Gerente' })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.jobTitle).to.equal('Gerente');
  });

  it('lists user licenses', async () => {
    sharePointGraphService.listUserLicenses = async () => [{ skuId: 'sku-01', skuPartNumber: 'E5' }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/users/user-01/licenses');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.count).to.equal(1);
    expect(data.data[0].skuPartNumber).to.equal('E5');
  });

  it('assigns user licenses', async () => {
    sharePointGraphService.assignUserLicenses = async (userId, addLicenses, removeLicenses) => ({
      userId,
      addLicenses,
      removeLicenses
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/users/user-01/licenses', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ addLicenses: [{ skuId: 'sku-01' }], removeLicenses: [] })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.addLicenses).to.have.lengthOf(1);
  });

  it('lists drive children for a folder path', async () => {
    sharePointGraphService.listChildren = async (driveId, path) => [{
      id: `${driveId}-item-01`,
      name: path || 'root'
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/children?path=Documentos/Projetos');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.count).to.equal(1);
    expect(data.data[0].name).to.equal('Documentos/Projetos');
  });

  it('creates a sharepoint folder', async () => {
    sharePointGraphService.createFolder = async (driveId, name, parentPath) => ({
      id: 'folder-01',
      driveId,
      name,
      parentPath
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/folders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'NovaPasta', parentPath: 'Documentos' })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.name).to.equal('NovaPasta');
  });

  it('uploads a text file to sharepoint', async () => {
    sharePointGraphService.uploadTextFile = async (driveId, fileName, content, parentPath) => ({
      id: 'file-01',
      driveId,
      fileName,
      content,
      parentPath
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/files', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fileName: 'nota.txt', content: 'conteudo', parentPath: 'Documentos' })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.fileName).to.equal('nota.txt');
  });

  it('renames a sharepoint item', async () => {
    sharePointGraphService.renameItem = async (driveId, itemId, newName) => ({
      id: itemId,
      driveId,
      name: newName
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/items/item-01', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ newName: 'nota-v2.txt' })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.name).to.equal('nota-v2.txt');
  });

  it('deletes a sharepoint item', async () => {
    sharePointGraphService.deleteItem = async () => true;

    const { response } = await fetchJson('/api/v1/sharepoint/drives/drive-01/items/item-01', {
      method: 'DELETE'
    });

    expect(response.status).to.equal(204);
  });

  it('lists drive files metadata', async () => {
    sharePointGraphService.listDriveFilesWithMetadata = async (driveId, path, top) => [{
      id: `${driveId}-${top}`,
      name: path || 'root',
      size: 128
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/files-metadata?path=Documentos&top=50');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.count).to.equal(1);
    expect(data.data[0].id).to.equal('drive-01-50');
  });

  it('lists item permissions', async () => {
    sharePointGraphService.listItemPermissions = async () => [{ id: 'perm-01', roles: ['read'] }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/items/item-01/permissions');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.count).to.equal(1);
    expect(data.data[0].id).to.equal('perm-01');
  });

  it('creates item permissions', async () => {
    sharePointGraphService.inviteItemPermissions = async (driveId, itemId, recipients, roles) => ({
      id: 'perm-02',
      driveId,
      itemId,
      recipients,
      roles
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/items/item-01/permissions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ recipients: [{ email: 'user@example.com' }], roles: ['write'] })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.roles).to.deep.equal(['write']);
  });

  it('deletes item permissions', async () => {
    sharePointGraphService.deleteItemPermission = async () => true;

    const { response } = await fetchJson('/api/v1/sharepoint/drives/drive-01/items/item-01/permissions/perm-01', {
      method: 'DELETE'
    });

    expect(response.status).to.equal(204);
  });

  it('lists team channels', async () => {
    sharePointGraphService.listTeamChannels = async (teamId) => [{
      id: 'channel-01',
      displayName: `Canal ${teamId}`
    }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/teams/team-01/channels');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data[0].displayName).to.equal('Canal team-01');
  });

  it('creates a team channel', async () => {
    sharePointGraphService.createTeamChannel = async (teamId, input) => ({ id: 'channel-02', teamId, ...input });

    const { response, data } = await fetchJson('/api/v1/sharepoint/teams/team-01/channels', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: 'Projetos', description: 'Canal novo' })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.displayName).to.equal('Projetos');
  });

  it('updates a team channel', async () => {
    sharePointGraphService.updateTeamChannel = async (teamId, channelId, input) => ({ id: channelId, teamId, ...input });

    const { response, data } = await fetchJson('/api/v1/sharepoint/teams/team-01/channels/channel-01', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ description: 'Canal atualizado' })
    });

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.description).to.equal('Canal atualizado');
  });

  it('lists channel members', async () => {
    sharePointGraphService.listChannelMembers = async () => [{ id: 'member-01', displayName: 'Maria' }];

    const { response, data } = await fetchJson('/api/v1/sharepoint/teams/team-01/channels/channel-01/members');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.count).to.equal(1);
    expect(data.data[0].displayName).to.equal('Maria');
  });

  it('lists channel content', async () => {
    sharePointGraphService.listChannelContent = async () => ({
      filesFolder: { id: 'folder-01', name: 'General' },
      messages: [{ id: 'msg-01', body: { content: 'Olá' } }],
      files: [{ id: 'file-01', name: 'ata.docx' }]
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/teams/team-01/channels/channel-99/content?topMessages=10');

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.messagesCount).to.equal(1);
    expect(data.data.filesCount).to.equal(1);
  });

  it('adds a channel member', async () => {
    sharePointGraphService.addChannelMember = async (teamId, channelId, userId, roles) => ({
      id: 'member-01',
      teamId,
      channelId,
      userId,
      roles
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/teams/team-01/channels/channel-01/members', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId: 'user-01', roles: ['owner'] })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.roles).to.deep.equal(['owner']);
  });

  it('removes a channel member', async () => {
    sharePointGraphService.removeChannelMember = async () => true;

    const { response } = await fetchJson('/api/v1/sharepoint/teams/team-01/channels/channel-01/members/member-01', {
      method: 'DELETE'
    });

    expect(response.status).to.equal(204);
  });

  it('adds a group member', async () => {
    sharePointGraphService.addGroupMember = async (groupId, memberObjectId) => ({
      groupId,
      memberObjectId,
      action: 'added'
    });

    const { response, data } = await fetchJson('/api/v1/sharepoint/groups/group-01/members', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ memberObjectId: 'member-09' })
    });

    expect(response.status).to.equal(201);
    expect(data.success).to.equal(true);
    expect(data.data.groupId).to.equal('group-01');
  });

  it('removes a group member', async () => {
    sharePointGraphService.removeGroupMember = async () => true;

    const { response } = await fetchJson('/api/v1/sharepoint/groups/group-01/members/member-09', {
      method: 'DELETE'
    });

    expect(response.status).to.equal(204);
  });

  it('exports drive data as json', async () => {
    sharePointGraphService.listDriveFilesWithMetadata = async () => [{ id: 'file-01', name: 'relatorio.csv' }];

    const response = await fetch(`${baseUrl}/api/v1/sharepoint/export?source=drive-files&format=json&driveId=drive-01`);
    const data = await response.json();

    expect(response.status).to.equal(200);
    expect(response.headers.get('content-type')).to.contain('application/json');
    expect(response.headers.get('content-disposition')).to.contain('.json');
    expect(data.success).to.equal(true);
    expect(data.data.count).to.equal(1);
  });

  it('exports site drives as json', async () => {
    sharePointGraphService.listDrives = async () => [{ id: 'drive-01', name: 'Documentos' }];

    const response = await fetch(`${baseUrl}/api/v1/sharepoint/export?source=site-drives&format=json&siteId=site-01`);
    const data = await response.json();

    expect(response.status).to.equal(200);
    expect(data.success).to.equal(true);
    expect(data.data.count).to.equal(1);
    expect(data.data.source).to.equal('site-drives');
  });

  it('exports site libraries as csv', async () => {
    sharePointGraphService.listLibraries = async () => [{ id: 'list-01', displayName: 'Biblioteca A' }];

    const response = await fetch(`${baseUrl}/api/v1/sharepoint/export?source=site-libraries&format=csv&siteId=site-01`);
    const csv = await response.text();

    expect(response.status).to.equal(200);
    expect(response.headers.get('content-type')).to.contain('text/csv');
    expect(csv).to.contain('displayName');
    expect(csv).to.contain('Biblioteca A');
  });

  it('exports users as xlsx', async () => {
    sharePointGraphService.listUsers = async () => [{ id: 'user-01', displayName: 'Maria' }];

    const response = await fetch(`${baseUrl}/api/v1/sharepoint/export?source=users&format=xlsx`);
    const buffer = Buffer.from(await response.arrayBuffer());

    expect(response.status).to.equal(200);
    expect(response.headers.get('content-type')).to.contain('spreadsheetml.sheet');
    expect(response.headers.get('content-disposition')).to.contain('.xlsx');
    expect(buffer.length).to.be.greaterThan(0);
  });

  it('exports team channels as csv', async () => {
    sharePointGraphService.listTeamChannels = async () => [{ id: 'channel-01', displayName: 'General' }];

    const response = await fetch(`${baseUrl}/api/v1/sharepoint/export?source=team-channels&format=csv&teamId=team-01`);
    const csv = await response.text();

    expect(response.status).to.equal(200);
    expect(response.headers.get('content-type')).to.contain('text/csv');
    expect(response.headers.get('content-disposition')).to.contain('.csv');
    expect(csv).to.contain('displayName');
    expect(csv).to.contain('General');
  });

  it('exports team channel content as csv', async () => {
    sharePointGraphService.listChannelContent = async () => ({
      filesFolder: { id: 'folder-01' },
      messages: [{ id: 'msg-01', body: { content: 'Mensagem' }, createdDateTime: '2026-03-16T00:00:00Z' }],
      files: [{ id: 'file-01', name: 'ata.docx', size: 10, createdDateTime: '2026-03-16T00:00:00Z' }]
    });

    const response = await fetch(`${baseUrl}/api/v1/sharepoint/export?source=team-channel-content&format=csv&teamId=team-01&channelId=channel-01`);
    const csv = await response.text();

    expect(response.status).to.equal(200);
    expect(response.headers.get('content-type')).to.contain('text/csv');
    expect(csv).to.contain('section');
    expect(csv).to.contain('message');
    expect(csv).to.contain('file');
  });

  it('rejects unsupported export source', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/export?source=unknown&format=xlsx&driveId=drive-01');

    expect(response.status).to.equal(400);
    expect(data.success).to.equal(false);
    expect(data.error.message).to.contain('source inválido');
  });

  it('validates required fields for folder creation', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01/folders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ parentPath: 'Documentos' })
    });

    expect(response.status).to.equal(400);
    expect(data.success).to.equal(false);
    expect(data.error.message).to.contain('driveId e name são obrigatórios');
  });

  it('validates required fields for library creation', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/sites/site-01/libraries', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });

    expect(response.status).to.equal(400);
    expect(data.success).to.equal(false);
    expect(data.error.message).to.contain('siteId e displayName são obrigatórios');
  });

  it('validates required fields for drive update', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/drives/drive-01', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });

    expect(response.status).to.equal(400);
    expect(data.success).to.equal(false);
    expect(data.error.message).to.contain('Informe ao menos name ou description para atualizar o drive');
  });

  it('validates required fields for group membership creation', async () => {
    const { response, data } = await fetchJson('/api/v1/sharepoint/groups/group-01/members', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });

    expect(response.status).to.equal(400);
    expect(data.success).to.equal(false);
    expect(data.error.message).to.contain('groupId e memberObjectId são obrigatórios');
  });
});
