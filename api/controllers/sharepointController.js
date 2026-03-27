import XLSX from 'xlsx';
import sharePointGraphService from '../services/sharepointGraphService.js';
import inventoryDbService from '../services/inventoryDbService.js';

function createCorrelationId(req) {
  return req.headers['x-correlation-id'] || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function sendError(res, req, error, fallbackMessage) {
  const correlationId = createCorrelationId(req);
  res.setHeader('x-correlation-id', correlationId);

  return res.status(error.status || 500).json({
    success: false,
    correlationId,
    error: {
      code: error.code || `SP_${error.status || 500}`,
      message: fallbackMessage
    }
  });
}

function sendValidationError(res, req, message) {
  const correlationId = createCorrelationId(req);
  res.setHeader('x-correlation-id', correlationId);
  return res.status(400).json({
    success: false,
    correlationId,
    error: {
      code: 'SP_400',
      message
    }
  });
}

function escapeCsvValue(value) {
  const asText = value === null || value === undefined ? '' : String(value);
  if (asText.includes(',') || asText.includes('"') || asText.includes('\n') || asText.includes('\r')) {
    return `"${asText.replace(/"/g, '""')}"`;
  }
  return asText;
}

function normalizeForCsv(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'object') return JSON.stringify(value);
  return value;
}

function toCsv(rows) {
  const safeRows = Array.isArray(rows) ? rows : [];
  if (safeRows.length === 0) {
    return 'result\n';
  }

  const headers = Array.from(
    safeRows.reduce((set, row) => {
      Object.keys(row || {}).forEach((key) => set.add(key));
      return set;
    }, new Set())
  );

  const headerLine = headers.map(escapeCsvValue).join(',');
  const dataLines = safeRows.map((row) => headers
    .map((header) => escapeCsvValue(normalizeForCsv(row?.[header])))
    .join(','));

  return [headerLine, ...dataLines].join('\n');
}

function flattenChannelContentForCsv(teamId, channelId, content) {
  const messages = (content?.messages || []).map((item) => ({
    section: 'message',
    teamId,
    channelId,
    id: item.id,
    from: item?.from?.user?.displayName || item?.from?.application?.displayName || '',
    createdDateTime: item.createdDateTime,
    lastModifiedDateTime: item.lastModifiedDateTime,
    summary: item.summary || '',
    webUrl: item.webUrl || '',
    contentType: item?.body?.contentType || '',
    content: item?.body?.content || ''
  }));

  const files = (content?.files || []).map((item) => ({
    section: 'file',
    teamId,
    channelId,
    id: item.id,
    name: item.name,
    webUrl: item.webUrl,
    size: item.size,
    createdDateTime: item.createdDateTime,
    lastModifiedDateTime: item.lastModifiedDateTime,
    isFolder: Boolean(item.folder),
    mimeType: item?.file?.mimeType || ''
  }));

  return [...messages, ...files];
}

function normalizeRowsForSpreadsheet(rows) {
  return (Array.isArray(rows) ? rows : []).map((row) => {
    const normalized = {};
    Object.entries(row || {}).forEach(([key, value]) => {
      normalized[key] = normalizeForCsv(value);
    });
    return normalized;
  });
}

function toXlsxBuffer(rows, sheetName = 'Resultados') {
  const workbook = XLSX.utils.book_new();
  const normalizedRows = normalizeRowsForSpreadsheet(rows);
  const worksheet = XLSX.utils.json_to_sheet(normalizedRows.length > 0 ? normalizedRows : [{ result: '' }]);
  XLSX.utils.book_append_sheet(workbook, worksheet, sheetName.slice(0, 31));
  return XLSX.write(workbook, { bookType: 'xlsx', type: 'buffer' });
}

function flattenLicensesForExport(userId, licenses) {
  return (licenses || []).map((item) => ({
    userId,
    skuId: item.skuId,
    skuPartNumber: item.skuPartNumber,
    servicePlans: item.servicePlans || []
  }));
}

function flattenPermissionsForExport(driveId, itemId, permissions) {
  return (permissions || []).map((item) => ({
    driveId,
    itemId,
    id: item.id,
    roles: item.roles || [],
    grantedTo: item.grantedToV2 || item.grantedTo || null,
    grantedToIdentities: item.grantedToIdentitiesV2 || item.grantedToIdentities || [],
    link: item.link || null,
    invitation: item.invitation || null,
    inheritedFrom: item.inheritedFrom || null
  }));
}

function parsePermissionPrincipals(permission) {
  const entries = [];

  const identities = Array.isArray(permission?.grantedToIdentitiesV2)
    ? permission.grantedToIdentitiesV2
    : Array.isArray(permission?.grantedToIdentities)
      ? permission.grantedToIdentities
      : [];

  identities.forEach((identity) => {
    const user = identity?.user || {};
    entries.push({
      principalType: 'user',
      principalId: user.id || '',
      principalEmail: user.email || user.userPrincipalName || '',
      principalDisplayName: user.displayName || ''
    });
  });

  const single = permission?.grantedToV2 || permission?.grantedTo;
  if (single?.user) {
    entries.push({
      principalType: 'user',
      principalId: single.user.id || '',
      principalEmail: single.user.email || single.user.userPrincipalName || '',
      principalDisplayName: single.user.displayName || ''
    });
  }

  if (entries.length === 0) {
    entries.push({
      principalType: permission?.link ? 'link' : 'unknown',
      principalId: '',
      principalEmail: '',
      principalDisplayName: ''
    });
  }

  return entries;
}

function normalizePermissionRows({ resourceType, siteId = '', driveId = '', itemId = '', teamId = '', channelId = '', resourceName = '', permissions = [] }) {
  const rows = [];

  (permissions || []).forEach((permission) => {
    const principals = parsePermissionPrincipals(permission);
    principals.forEach((principal) => {
      rows.push({
        schema: 'sharepoint-permission-v1',
        resourceType,
        resourceName,
        siteId,
        driveId,
        itemId,
        teamId,
        channelId,
        permissionId: permission.id || '',
        roles: permission.roles || [],
        inheritedFrom: permission.inheritedFrom || null,
        principalType: principal.principalType,
        principalId: principal.principalId,
        principalEmail: principal.principalEmail,
        principalDisplayName: principal.principalDisplayName,
        link: permission.link || null,
        invitation: permission.invitation || null
      });
    });
  });

  return rows;
}

function parseCsvList(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

async function collectTenantSharePointInventory({ search, topSites, topItemsPerDrive, includePermissions, includeChannelPermissions, teamIds }) {
  const sites = await sharePointGraphService.listSites(search || '*', topSites);
  const drives = [];
  const files = [];
  const folders = [];
  const permissions = [];
  const channels = [];

  for (const site of sites) {
    let sitePermissions = [];
    if (includePermissions) {
      try {
        sitePermissions = await sharePointGraphService.listSitePermissions(site.id);
      } catch {
        sitePermissions = [];
      }
      permissions.push(...normalizePermissionRows({
        resourceType: 'site',
        siteId: site.id,
        resourceName: site.displayName || site.name || '',
        permissions: sitePermissions
      }));
    }

    const siteDrives = await sharePointGraphService.listDrives(site.id);
    siteDrives.forEach((drive) => drives.push({ ...drive, siteId: site.id, siteName: site.displayName || site.name || '' }));

    for (const drive of siteDrives) {
      if (includePermissions) {
        let drivePermissions = [];
        try {
          drivePermissions = await sharePointGraphService.listDriveRootPermissions(drive.id);
        } catch {
          drivePermissions = [];
        }
        permissions.push(...normalizePermissionRows({
          resourceType: 'drive',
          siteId: site.id,
          driveId: drive.id,
          itemId: 'root',
          resourceName: drive.name || '',
          permissions: drivePermissions
        }));
      }

      const items = await sharePointGraphService.listChildren(drive.id, '');
      const limitedItems = items.slice(0, Math.max(1, topItemsPerDrive));

      limitedItems.forEach((item) => {
        const row = {
          ...item,
          siteId: site.id,
          siteName: site.displayName || site.name || '',
          driveId: drive.id,
          driveName: drive.name || ''
        };

        if (item.folder) {
          folders.push(row);
        } else {
          files.push(row);
        }
      });

      if (includePermissions) {
        for (const item of limitedItems) {
          let itemPermissions = [];
          try {
            itemPermissions = await sharePointGraphService.listItemPermissions(drive.id, item.id);
          } catch {
            itemPermissions = [];
          }

          permissions.push(...normalizePermissionRows({
            resourceType: item.folder ? 'folder' : 'file',
            siteId: site.id,
            driveId: drive.id,
            itemId: item.id,
            resourceName: item.name || '',
            permissions: itemPermissions
          }));
        }
      }
    }
  }

  if (includeChannelPermissions && Array.isArray(teamIds) && teamIds.length > 0) {
    for (const teamId of teamIds) {
      const teamChannels = await sharePointGraphService.listTeamChannels(teamId);
      for (const channel of teamChannels) {
        channels.push({ teamId, ...channel });
        const members = await sharePointGraphService.listChannelMembers(teamId, channel.id);
        members.forEach((member) => {
          permissions.push({
            schema: 'sharepoint-permission-v1',
            resourceType: 'channel',
            resourceName: channel.displayName || '',
            siteId: '',
            driveId: '',
            itemId: '',
            teamId,
            channelId: channel.id,
            permissionId: member.id || '',
            roles: Array.isArray(member.roles) ? member.roles : [],
            inheritedFrom: null,
            principalType: 'user',
            principalId: member.userId || member.id || '',
            principalEmail: member.email || member.userPrincipalName || '',
            principalDisplayName: member.displayName || member.name || '',
            link: null,
            invitation: null
          });
        });
      }
    }
  }

  return {
    sites,
    drives,
    files,
    folders,
    channels,
    permissions
  };
}

function persistInventorySafely(persistFn) {
  try {
    persistFn();
  } catch {
    // Persistencia local nao deve bloquear resposta da API principal.
  }
}

export async function getInventoryDatabase(req, res) {
  try {
    const database = inventoryDbService.getDatabase();
    return res.json({ success: true, data: database });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao obter base de dados de inventário local.');
  }
}

export async function getConfig(req, res) {
  try {
    return res.json({
      success: true,
      data: sharePointGraphService.getConfig()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao obter configuração do SharePoint Graph.');
  }
}

export async function authenticate(req, res) {
  try {
    await sharePointGraphService.authenticate();
    return res.json({
      success: true,
      message: 'Autenticação SharePoint Graph realizada com sucesso.',
      data: sharePointGraphService.getConfig()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao autenticar no Microsoft Graph.');
  }
}

export async function listSites(req, res) {
  try {
    const search = req.query.search || '*';
    const top = req.query.top ? parseInt(req.query.top, 10) : 25;

    const sites = await sharePointGraphService.listSites(search, top);
    persistInventorySafely(() => inventoryDbService.recordSites(sites, { search, top }));
    return res.json({ success: true, count: sites.length, data: sites });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar sites SharePoint.');
  }
}

export async function listDrives(req, res) {
  try {
    const { siteId } = req.params;
    if (!siteId) {
      return res.status(400).json({
        success: false,
        error: { code: 'SP_400', message: 'siteId é obrigatório.' }
      });
    }

    const drives = await sharePointGraphService.listDrives(siteId);
    persistInventorySafely(() => inventoryDbService.recordDrives(siteId, drives));
    return res.json({ success: true, count: drives.length, data: drives });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar bibliotecas do site SharePoint.');
  }
}

export async function listLibraries(req, res) {
  try {
    const { siteId } = req.params;
    if (!siteId) {
      return sendValidationError(res, req, 'siteId é obrigatório.');
    }

    const libraries = await sharePointGraphService.listLibraries(siteId);
    persistInventorySafely(() => inventoryDbService.recordLibraries(siteId, libraries));
    return res.json({ success: true, count: libraries.length, data: libraries });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar bibliotecas do site SharePoint.');
  }
}

export async function createLibrary(req, res) {
  try {
    const { siteId } = req.params;
    const displayName = String(req.body.displayName || req.body.name || '').trim();

    if (!siteId || !displayName) {
      return sendValidationError(res, req, 'siteId e displayName são obrigatórios.');
    }

    const created = await sharePointGraphService.createLibrary(siteId, {
      displayName,
      description: req.body.description,
      columns: Array.isArray(req.body.columns) ? req.body.columns : []
    });

    persistInventorySafely(() => inventoryDbService.recordLibrary(created, siteId));

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao criar biblioteca SharePoint.');
  }
}

export async function updateLibrary(req, res) {
  try {
    const { siteId, listId } = req.params;
    const hasUpdatableField = req.body?.displayName || req.body?.name || req.body?.description !== undefined;

    if (!siteId || !listId) {
      return sendValidationError(res, req, 'siteId e listId são obrigatórios.');
    }

    if (!hasUpdatableField) {
      return sendValidationError(res, req, 'Informe ao menos displayName, name ou description para atualizar a biblioteca.');
    }

    const updated = await sharePointGraphService.updateLibrary(siteId, listId, req.body || {});
    persistInventorySafely(() => inventoryDbService.recordLibrary(updated, siteId));
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar biblioteca SharePoint.');
  }
}

export async function createDrive(req, res) {
  try {
    const { siteId } = req.params;
    const displayName = String(req.body.displayName || req.body.name || '').trim();

    if (!siteId || !displayName) {
      return sendValidationError(res, req, 'siteId e displayName são obrigatórios.');
    }

    const created = await sharePointGraphService.createDrive(siteId, {
      displayName,
      description: req.body.description,
      columns: Array.isArray(req.body.columns) ? req.body.columns : []
    });

    persistInventorySafely(() => {
      if (created?.drive) {
        inventoryDbService.recordDrive(created.drive, siteId);
      }
      if (created?.id) {
        inventoryDbService.recordLibrary(created, siteId);
      }
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao criar drive SharePoint.');
  }
}

export async function updateDrive(req, res) {
  try {
    const { driveId } = req.params;
    const hasUpdatableField = req.body?.name || req.body?.description !== undefined;

    if (!driveId) {
      return sendValidationError(res, req, 'driveId é obrigatório.');
    }

    if (!hasUpdatableField) {
      return sendValidationError(res, req, 'Informe ao menos name ou description para atualizar o drive.');
    }

    const updated = await sharePointGraphService.updateDrive(driveId, req.body || {});
    persistInventorySafely(() => inventoryDbService.recordDrive(updated));
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar drive SharePoint.');
  }
}

export async function listDriveChildren(req, res) {
  try {
    const { driveId } = req.params;
    const path = req.query.path || '';

    if (!driveId) {
      return res.status(400).json({
        success: false,
        error: { code: 'SP_400', message: 'driveId é obrigatório.' }
      });
    }

    const items = await sharePointGraphService.listChildren(driveId, path);
    persistInventorySafely(() => inventoryDbService.recordFiles(driveId, items, { path, source: 'children' }));
    return res.json({ success: true, count: items.length, data: items });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar itens da biblioteca SharePoint.');
  }
}

export async function createFolder(req, res) {
  try {
    const { driveId } = req.params;
    const { name, parentPath } = req.body;

    if (!driveId || !name) {
      return res.status(400).json({
        success: false,
        error: { code: 'SP_400', message: 'driveId e name são obrigatórios.' }
      });
    }

    const folder = await sharePointGraphService.createFolder(driveId, name, parentPath || '');
    persistInventorySafely(() => inventoryDbService.recordFiles(driveId, [folder], { path: parentPath || '', source: 'create-folder' }));
    return res.status(201).json({ success: true, data: folder });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao criar pasta no SharePoint.');
  }
}

export async function uploadFile(req, res) {
  try {
    const { driveId } = req.params;
    const { fileName, content, parentPath } = req.body;

    if (!driveId || !fileName) {
      return res.status(400).json({
        success: false,
        error: { code: 'SP_400', message: 'driveId e fileName são obrigatórios.' }
      });
    }

    const item = await sharePointGraphService.uploadTextFile(
      driveId,
      fileName,
      String(content || ''),
      parentPath || ''
    );

    persistInventorySafely(() => inventoryDbService.recordFiles(driveId, [item], { path: parentPath || '', source: 'upload-file' }));

    return res.status(201).json({ success: true, data: item });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao fazer upload do arquivo no SharePoint.');
  }
}

export async function renameItem(req, res) {
  try {
    const { driveId, itemId } = req.params;
    const { newName } = req.body;

    if (!driveId || !itemId || !newName) {
      return res.status(400).json({
        success: false,
        error: { code: 'SP_400', message: 'driveId, itemId e newName são obrigatórios.' }
      });
    }

    const updated = await sharePointGraphService.renameItem(driveId, itemId, newName);
    persistInventorySafely(() => inventoryDbService.recordFiles(driveId, [updated], { source: 'rename-item' }));
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao renomear item no SharePoint.');
  }
}

export async function deleteItem(req, res) {
  try {
    const { driveId, itemId } = req.params;

    if (!driveId || !itemId) {
      return res.status(400).json({
        success: false,
        error: { code: 'SP_400', message: 'driveId e itemId são obrigatórios.' }
      });
    }

    await sharePointGraphService.deleteItem(driveId, itemId);
    return res.status(204).send();
  } catch (error) {
    return sendError(res, req, error, 'Falha ao excluir item no SharePoint.');
  }
}

export async function listFilesMetadata(req, res) {
  try {
    const { driveId } = req.params;
    const path = req.query.path || '';
    const top = req.query.top ? parseInt(req.query.top, 10) : 100;

    if (!driveId) {
      return sendValidationError(res, req, 'driveId é obrigatório.');
    }

    const items = await sharePointGraphService.listDriveFilesWithMetadata(driveId, path, top);
    persistInventorySafely(() => inventoryDbService.recordFiles(driveId, items, { path, source: 'files-metadata' }));
    return res.json({
      success: true,
      count: items.length,
      data: items
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar arquivos e metadados do drive SharePoint.');
  }
}

export async function listGroups(req, res) {
  try {
    const search = req.query.search || '';
    const top = req.query.top ? parseInt(req.query.top, 10) : 25;
    const groups = await sharePointGraphService.listGroups(search, top);
    return res.json({ success: true, count: groups.length, data: groups });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar grupos Entra ID.');
  }
}

export async function createGroup(req, res) {
  try {
    const { displayName, mailNickname } = req.body;
    if (!displayName || !mailNickname) {
      return sendValidationError(res, req, 'displayName e mailNickname são obrigatórios.');
    }

    const created = await sharePointGraphService.createGroup({
      description: req.body.description || '',
      displayName,
      mailEnabled: req.body.mailEnabled === true,
      mailNickname,
      securityEnabled: req.body.securityEnabled !== false,
      groupTypes: Array.isArray(req.body.groupTypes) ? req.body.groupTypes : []
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao criar grupo Entra ID.');
  }
}

export async function updateGroup(req, res) {
  try {
    const { groupId } = req.params;
    if (!groupId) {
      return sendValidationError(res, req, 'groupId é obrigatório.');
    }

    const updated = await sharePointGraphService.updateGroup(groupId, req.body || {});
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar grupo Entra ID.');
  }
}

export async function listUsers(req, res) {
  try {
    const search = req.query.search || '';
    const top = req.query.top ? parseInt(req.query.top, 10) : 25;
    const users = await sharePointGraphService.listUsers(search, top);
    return res.json({ success: true, count: users.length, data: users });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar usuários.');
  }
}

export async function updateUser(req, res) {
  try {
    const { userId } = req.params;
    if (!userId) {
      return sendValidationError(res, req, 'userId é obrigatório.');
    }

    const updated = await sharePointGraphService.updateUser(userId, req.body || {});
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar usuário.');
  }
}

export async function listUserLicenses(req, res) {
  try {
    const { userId } = req.params;
    if (!userId) {
      return sendValidationError(res, req, 'userId é obrigatório.');
    }

    const licenses = await sharePointGraphService.listUserLicenses(userId);
    return res.json({ success: true, count: licenses.length, data: licenses });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar licenças do usuário.');
  }
}

export async function assignUserLicenses(req, res) {
  try {
    const { userId } = req.params;
    if (!userId) {
      return sendValidationError(res, req, 'userId é obrigatório.');
    }

    const addLicenses = Array.isArray(req.body.addLicenses) ? req.body.addLicenses : [];
    const removeLicenses = Array.isArray(req.body.removeLicenses) ? req.body.removeLicenses : [];
    const result = await sharePointGraphService.assignUserLicenses(userId, addLicenses, removeLicenses);
    return res.json({ success: true, data: result });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao alterar licenças do usuário.');
  }
}

export async function listItemPermissions(req, res) {
  try {
    const { driveId, itemId } = req.params;
    if (!driveId || !itemId) {
      return sendValidationError(res, req, 'driveId e itemId são obrigatórios.');
    }

    const permissions = await sharePointGraphService.listItemPermissions(driveId, itemId);
    return res.json({ success: true, count: permissions.length, data: permissions });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar permissões do item.');
  }
}

export async function createItemPermission(req, res) {
  try {
    const { driveId, itemId } = req.params;
    const recipients = Array.isArray(req.body.recipients) ? req.body.recipients : [];
    const roles = Array.isArray(req.body.roles) && req.body.roles.length > 0 ? req.body.roles : ['read'];
    if (!driveId || !itemId || recipients.length === 0) {
      return sendValidationError(res, req, 'driveId, itemId e recipients são obrigatórios.');
    }

    const created = await sharePointGraphService.inviteItemPermissions(
      driveId,
      itemId,
      recipients,
      roles,
      req.body.message || ''
    );

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao criar permissão para o item.');
  }
}

export async function deleteItemPermission(req, res) {
  try {
    const { driveId, itemId, permissionId } = req.params;
    if (!driveId || !itemId || !permissionId) {
      return sendValidationError(res, req, 'driveId, itemId e permissionId são obrigatórios.');
    }

    await sharePointGraphService.deleteItemPermission(driveId, itemId, permissionId);
    return res.status(204).send();
  } catch (error) {
    return sendError(res, req, error, 'Falha ao remover permissão do item.');
  }
}

export async function listTeamChannels(req, res) {
  try {
    const { teamId } = req.params;
    if (!teamId) {
      return sendValidationError(res, req, 'teamId é obrigatório.');
    }

    const channels = await sharePointGraphService.listTeamChannels(teamId);
    return res.json({ success: true, count: channels.length, data: channels });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar canais do Microsoft Teams.');
  }
}

export async function createTeamChannel(req, res) {
  try {
    const { teamId } = req.params;
    const { displayName } = req.body;
    if (!teamId || !displayName) {
      return sendValidationError(res, req, 'teamId e displayName são obrigatórios.');
    }

    const created = await sharePointGraphService.createTeamChannel(teamId, {
      displayName,
      description: req.body.description || '',
      membershipType: req.body.membershipType || 'standard'
    });

    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao criar canal do Teams.');
  }
}

export async function updateTeamChannel(req, res) {
  try {
    const { teamId, channelId } = req.params;
    if (!teamId || !channelId) {
      return sendValidationError(res, req, 'teamId e channelId são obrigatórios.');
    }

    const updated = await sharePointGraphService.updateTeamChannel(teamId, channelId, req.body || {});
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar canal do Teams.');
  }
}

export async function listChannelMembers(req, res) {
  try {
    const { teamId, channelId } = req.params;
    if (!teamId || !channelId) {
      return sendValidationError(res, req, 'teamId e channelId são obrigatórios.');
    }

    const members = await sharePointGraphService.listChannelMembers(teamId, channelId);
    return res.json({ success: true, count: members.length, data: members });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar membros do canal do Teams.');
  }
}

export async function listChannelContent(req, res) {
  try {
    const { teamId, channelId } = req.params;
    const topMessages = req.query.topMessages ? parseInt(req.query.topMessages, 10) : 25;

    if (!teamId || !channelId) {
      return sendValidationError(res, req, 'teamId e channelId são obrigatórios.');
    }

    const content = await sharePointGraphService.listChannelContent(teamId, channelId, topMessages);
    return res.json({
      success: true,
      data: {
        teamId,
        channelId,
        filesFolder: content.filesFolder,
        messagesCount: content.messages.length,
        filesCount: content.files.length,
        messages: content.messages,
        files: content.files
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar conteúdo do canal do Microsoft Teams.');
  }
}

export async function addTeamChannelMember(req, res) {
  try {
    const { teamId, channelId } = req.params;
    const { userId, roles } = req.body;

    if (!teamId || !channelId || !userId) {
      return sendValidationError(res, req, 'teamId, channelId e userId são obrigatórios.');
    }

    const member = await sharePointGraphService.addChannelMember(teamId, channelId, userId, roles || []);
    return res.status(201).json({ success: true, data: member });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao adicionar membro no canal do Teams.');
  }
}

export async function removeTeamChannelMember(req, res) {
  try {
    const { teamId, channelId, membershipId } = req.params;
    if (!teamId || !channelId || !membershipId) {
      return sendValidationError(res, req, 'teamId, channelId e membershipId são obrigatórios.');
    }

    await sharePointGraphService.removeChannelMember(teamId, channelId, membershipId);
    return res.status(204).send();
  } catch (error) {
    return sendError(res, req, error, 'Falha ao remover membro do canal do Teams.');
  }
}

export async function addEntraGroupMember(req, res) {
  try {
    const { groupId } = req.params;
    const { memberObjectId } = req.body;

    if (!groupId || !memberObjectId) {
      return sendValidationError(res, req, 'groupId e memberObjectId são obrigatórios.');
    }

    await sharePointGraphService.addGroupMember(groupId, memberObjectId);
    return res.status(201).json({
      success: true,
      data: {
        groupId,
        memberObjectId,
        action: 'added'
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao adicionar membro ao grupo Entra ID.');
  }
}

export async function removeEntraGroupMember(req, res) {
  try {
    const { groupId, memberObjectId } = req.params;

    if (!groupId || !memberObjectId) {
      return sendValidationError(res, req, 'groupId e memberObjectId são obrigatórios.');
    }

    await sharePointGraphService.removeGroupMember(groupId, memberObjectId);
    return res.status(204).send();
  } catch (error) {
    return sendError(res, req, error, 'Falha ao remover membro do grupo Entra ID.');
  }
}

export async function exportResults(req, res) {
  try {
    const format = String(req.query.format || 'json').toLowerCase();
    const source = String(req.query.source || '').toLowerCase();

    if (!source) {
      return sendValidationError(res, req, 'source é obrigatório.');
    }

    if (!['json', 'csv', 'xlsx'].includes(format)) {
      return sendValidationError(res, req, 'format inválido. Valores suportados: json, csv, xlsx.');
    }

    let payload;
    let rowsForCsv;
    let worksheetName = 'Resultados';

    if (source === 'drive-files') {
      const driveId = String(req.query.driveId || '');
      const path = String(req.query.path || '');
      const top = req.query.top ? parseInt(req.query.top, 10) : 100;
      if (!driveId) {
        return sendValidationError(res, req, 'driveId é obrigatório para source=drive-files.');
      }

      const files = await sharePointGraphService.listDriveFilesWithMetadata(driveId, path, top);
      payload = { source, driveId, path, count: files.length, data: files };
      rowsForCsv = files;
      worksheetName = 'DriveFiles';
    } else if (source === 'site-drives') {
      const siteId = String(req.query.siteId || '');
      if (!siteId) {
        return sendValidationError(res, req, 'siteId é obrigatório para source=site-drives.');
      }

      const drives = await sharePointGraphService.listDrives(siteId);
      payload = { source, siteId, count: drives.length, data: drives };
      rowsForCsv = drives;
      worksheetName = 'SiteDrives';
    } else if (source === 'site-libraries') {
      const siteId = String(req.query.siteId || '');
      if (!siteId) {
        return sendValidationError(res, req, 'siteId é obrigatório para source=site-libraries.');
      }

      const libraries = await sharePointGraphService.listLibraries(siteId);
      payload = { source, siteId, count: libraries.length, data: libraries };
      rowsForCsv = libraries;
      worksheetName = 'SiteLibraries';
    } else if (source === 'team-channels') {
      const teamId = String(req.query.teamId || '');
      if (!teamId) {
        return sendValidationError(res, req, 'teamId é obrigatório para source=team-channels.');
      }

      const channels = await sharePointGraphService.listTeamChannels(teamId);
      payload = { source, teamId, count: channels.length, data: channels };
      rowsForCsv = channels;
      worksheetName = 'TeamChannels';
    } else if (source === 'team-channel-content') {
      const teamId = String(req.query.teamId || '');
      const channelId = String(req.query.channelId || '');
      const topMessages = req.query.topMessages ? parseInt(req.query.topMessages, 10) : 25;
      if (!teamId || !channelId) {
        return sendValidationError(res, req, 'teamId e channelId são obrigatórios para source=team-channel-content.');
      }

      const content = await sharePointGraphService.listChannelContent(teamId, channelId, topMessages);
      payload = {
        source,
        teamId,
        channelId,
        filesFolder: content.filesFolder,
        messagesCount: content.messages.length,
        filesCount: content.files.length,
        messages: content.messages,
        files: content.files
      };
      rowsForCsv = flattenChannelContentForCsv(teamId, channelId, content);
      worksheetName = 'ChannelContent';
    } else if (source === 'groups') {
      const search = String(req.query.search || '');
      const top = req.query.top ? parseInt(req.query.top, 10) : 100;
      const groups = await sharePointGraphService.listGroups(search, top);
      payload = { source, search, count: groups.length, data: groups };
      rowsForCsv = groups;
      worksheetName = 'Groups';
    } else if (source === 'users') {
      const search = String(req.query.search || '');
      const top = req.query.top ? parseInt(req.query.top, 10) : 100;
      const users = await sharePointGraphService.listUsers(search, top);
      payload = { source, search, count: users.length, data: users };
      rowsForCsv = users;
      worksheetName = 'Users';
    } else if (source === 'user-licenses') {
      const userId = String(req.query.userId || '');
      if (!userId) {
        return sendValidationError(res, req, 'userId é obrigatório para source=user-licenses.');
      }

      const licenses = await sharePointGraphService.listUserLicenses(userId);
      payload = { source, userId, count: licenses.length, data: licenses };
      rowsForCsv = flattenLicensesForExport(userId, licenses);
      worksheetName = 'UserLicenses';
    } else if (source === 'item-permissions') {
      const driveId = String(req.query.driveId || '');
      const itemId = String(req.query.itemId || '');
      if (!driveId || !itemId) {
        return sendValidationError(res, req, 'driveId e itemId são obrigatórios para source=item-permissions.');
      }

      const permissions = await sharePointGraphService.listItemPermissions(driveId, itemId);
      payload = { source, driveId, itemId, count: permissions.length, data: permissions };
      rowsForCsv = flattenPermissionsForExport(driveId, itemId, permissions);
      worksheetName = 'Permissions';
    } else if (source === 'team-channel-members') {
      const teamId = String(req.query.teamId || '');
      const channelId = String(req.query.channelId || '');
      if (!teamId || !channelId) {
        return sendValidationError(res, req, 'teamId e channelId são obrigatórios para source=team-channel-members.');
      }

      const members = await sharePointGraphService.listChannelMembers(teamId, channelId);
      payload = { source, teamId, channelId, count: members.length, data: members };
      rowsForCsv = members;
      worksheetName = 'ChannelMembers';
    } else if (source === 'tenant-sharepoint-inventory' || source === 'tenant-permissions-standard') {
      const search = String(req.query.search || '*');
      const topSites = req.query.topSites ? parseInt(req.query.topSites, 10) : 50;
      const topItemsPerDrive = req.query.topItemsPerDrive ? parseInt(req.query.topItemsPerDrive, 10) : 200;
      const includePermissions = source === 'tenant-permissions-standard' || String(req.query.includePermissions || 'false').toLowerCase() === 'true';
      const includeChannelPermissions = source === 'tenant-permissions-standard' || String(req.query.includeChannelPermissions || 'false').toLowerCase() === 'true';
      const teamIds = parseCsvList(req.query.teamIds);

      const inventory = await collectTenantSharePointInventory({
        search,
        topSites,
        topItemsPerDrive,
        includePermissions,
        includeChannelPermissions,
        teamIds
      });

      payload = {
        source,
        generatedAt: new Date().toISOString(),
        filters: {
          search,
          topSites,
          topItemsPerDrive,
          includePermissions,
          includeChannelPermissions,
          teamIds
        },
        summary: {
          sites: inventory.sites.length,
          drives: inventory.drives.length,
          files: inventory.files.length,
          folders: inventory.folders.length,
          channels: inventory.channels.length,
          permissions: inventory.permissions.length
        },
        data: inventory
      };

      if (source === 'tenant-permissions-standard') {
        rowsForCsv = inventory.permissions;
        worksheetName = 'PermissionsStandard';
      } else {
        rowsForCsv = [
          ...inventory.sites.map((item) => ({ resourceType: 'site', ...item })),
          ...inventory.drives.map((item) => ({ resourceType: 'drive', ...item })),
          ...inventory.folders.map((item) => ({ resourceType: 'folder', ...item })),
          ...inventory.files.map((item) => ({ resourceType: 'file', ...item })),
          ...inventory.channels.map((item) => ({ resourceType: 'channel', ...item }))
        ];
        worksheetName = 'TenantInventory';
      }
    } else {
      return sendValidationError(res, req, 'source inválido. Valores suportados: drive-files, site-drives, site-libraries, team-channels, team-channel-content, groups, users, user-licenses, item-permissions, team-channel-members, tenant-sharepoint-inventory, tenant-permissions-standard.');
    }

    const now = new Date().toISOString().replace(/[:.]/g, '-');
    const fileBase = `${source}-${now}`;

    if (format === 'csv') {
      const csv = toCsv(rowsForCsv || []);
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${fileBase}.csv"`);
      return res.status(200).send(csv);
    }

    if (format === 'xlsx') {
      const workbookBuffer = toXlsxBuffer(rowsForCsv || [], worksheetName);
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${fileBase}.xlsx"`);
      return res.status(200).send(workbookBuffer);
    }

    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${fileBase}.json"`);
    return res.status(200).json({ success: true, data: payload });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao exportar resultados.');
  }
}

export async function importConfigurationAndPermissions(req, res) {
  try {
    const dryRun = req.body?.dryRun !== false;
    const mode = String(req.body?.mode || 'update').toLowerCase();
    const packageRows = Array.isArray(req.body?.permissions)
      ? req.body.permissions
      : Array.isArray(req.body?.data?.permissions)
        ? req.body.data.permissions
        : [];

    if (packageRows.length === 0) {
      return sendValidationError(res, req, 'permissions e obrigatorio e deve conter ao menos um registro.');
    }

    const result = {
      mode,
      dryRun,
      processed: 0,
      created: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      unsupported: 0,
      details: []
    };

    for (const row of packageRows) {
      const resourceType = String(row.resourceType || '').toLowerCase();

      try {
        if (resourceType === 'channel') {
          const teamId = String(row.teamId || '');
          const channelId = String(row.channelId || '');
          const userId = String(row.principalId || '').trim();

          if (!teamId || !channelId || !userId) {
            result.skipped += 1;
            result.details.push({ resourceType, action: 'skip', reason: 'teamId/channelId/principalId obrigatorios para channel.' });
            continue;
          }

          if (dryRun) {
            result.updated += 1;
            result.details.push({ resourceType, action: 'simulate-add-member', teamId, channelId, userId, roles: row.roles || [] });
            continue;
          }

          await sharePointGraphService.addChannelMember(teamId, channelId, userId, Array.isArray(row.roles) ? row.roles : []);
          result.updated += 1;
          result.details.push({ resourceType, action: 'add-member', teamId, channelId, userId });
          continue;
        }

        const driveId = String(row.driveId || '');
        const itemId = String(row.itemId || '').trim() || 'root';
        const principalEmail = String(row.principalEmail || '').trim();
        const roles = Array.isArray(row.roles) && row.roles.length > 0 ? row.roles : ['read'];

        if (!driveId || !principalEmail) {
          if (resourceType === 'site') {
            result.unsupported += 1;
            result.details.push({ resourceType, action: 'unsupported', reason: 'Importacao direta de permissao de site nao suportada por este endpoint.' });
          } else {
            result.skipped += 1;
            result.details.push({ resourceType, action: 'skip', reason: 'driveId/principalEmail obrigatorios para permissao de item/drive.' });
          }
          continue;
        }

        if (dryRun) {
          result.updated += 1;
          result.details.push({ resourceType, action: 'simulate-invite', driveId, itemId, principalEmail, roles });
          continue;
        }

        await sharePointGraphService.inviteItemPermissions(driveId, itemId, [{ email: principalEmail }], roles, 'Imported by permission package');
        result.updated += 1;
        result.details.push({ resourceType, action: 'invite', driveId, itemId, principalEmail, roles });
      } catch (error) {
        result.failed += 1;
        result.details.push({
          resourceType,
          action: 'error',
          code: error.code || `SP_${error.status || 500}`,
          message: error.publicMessage || error.message || 'Falha ao aplicar registro de permissao.'
        });
      } finally {
        result.processed += 1;
      }
    }

    return res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao importar configuracoes e permissoes para o tenant conectado.');
  }
}
