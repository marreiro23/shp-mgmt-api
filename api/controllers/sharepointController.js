import XLSX from 'xlsx';
import sharePointGraphService from '../services/sharepointGraphService.js';
import inventoryDbService from '../services/inventoryDbService.js';
import pgService from '../services/pgService.js';
import frontendCommandService from '../services/frontendCommandService.js';
import resourcePersistenceService from '../services/resourcePersistenceService.js';
import resourceQueryService from '../services/resourceQueryService.js';

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

function persistResourceSafely(persistFn) {
  Promise.resolve()
    .then(() => persistFn())
    .catch(() => {
      // Persistencia em PostgreSQL nao deve bloquear resposta da API principal.
    });
}

const DATABASE_TABLES = {
  sharepoint_sites: { orderBy: 'last_seen_at' },
  sharepoint_drives: { orderBy: 'last_seen_at' },
  sharepoint_libraries: { orderBy: 'last_seen_at' },
  sharepoint_drive_items: { orderBy: 'last_seen_at' },
  sharepoint_item_permissions: { orderBy: 'last_seen_at' },
  sharepoint_groups: { orderBy: 'last_seen_at' },
  sharepoint_group_members: { orderBy: 'last_seen_at' },
  sharepoint_users: { orderBy: 'last_seen_at' },
  sharepoint_user_licenses: { orderBy: 'last_seen_at' },
  sharepoint_teams: { orderBy: 'last_seen_at' },
  sharepoint_team_channels: { orderBy: 'last_seen_at' },
  sharepoint_channel_members: { orderBy: 'last_seen_at' },
  sharepoint_channel_messages: { orderBy: 'last_seen_at' },
  sharepoint_channel_files: { orderBy: 'last_seen_at' },
  frontend_commands: { orderBy: 'created_at' },
  operations: { orderBy: 'started_at' },
  audit_events: { orderBy: 'occurred_at' },
  export_runs: { orderBy: 'started_at' },
  governance_packages: { orderBy: 'created_at' },
  resources: { orderBy: 'exported_at' },
  permissions: { orderBy: 'exported_at' }
};

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
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!refresh) {
      const cachedSites = await resourceQueryService.listSites({ search, top });
      if (cachedSites.length > 0) {
        return res.json({ success: true, count: cachedSites.length, data: cachedSites, dataSource: 'local-db' });
      }
    }

    const sites = await sharePointGraphService.listSites(search, top);
    persistInventorySafely(() => inventoryDbService.recordSites(sites, { search, top }));
    persistResourceSafely(() => resourcePersistenceService.upsertSites(sites));
    return res.json({ success: true, count: sites.length, data: sites, dataSource: 'graph' });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar sites SharePoint.');
  }
}

export async function createSite(req, res) {
  try {
    const { parentSiteId } = req.params;
    const displayName = String(req.body.displayName || '').trim();
    const name = String(req.body.name || '').trim();

    if (!parentSiteId) {
      return sendValidationError(res, req, 'parentSiteId é obrigatório (parâmetro de rota).');
    }
    if (!displayName || !name) {
      return sendValidationError(res, req, 'displayName e name são obrigatórios.');
    }

    const created = await sharePointGraphService.createSite(parentSiteId, {
      displayName,
      name,
      description: req.body.description
    });

    persistResourceSafely(() => resourcePersistenceService.upsertSites([created]));
    return res.status(201).json({ success: true, data: created });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao criar site SharePoint.');
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

    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!refresh) {
      const cachedDrives = await resourceQueryService.listDrives(siteId);
      if (cachedDrives.length > 0) {
        return res.json({ success: true, count: cachedDrives.length, data: cachedDrives, dataSource: 'local-db' });
      }
    }

    const drives = await sharePointGraphService.listDrives(siteId);
    persistInventorySafely(() => inventoryDbService.recordDrives(siteId, drives));
    persistResourceSafely(() => resourcePersistenceService.upsertDrives(siteId, drives));
    return res.json({ success: true, count: drives.length, data: drives, dataSource: 'graph' });
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

    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!refresh) {
      const cachedLibraries = await resourceQueryService.listLibraries(siteId);
      if (cachedLibraries.length > 0) {
        return res.json({ success: true, count: cachedLibraries.length, data: cachedLibraries, dataSource: 'local-db' });
      }
    }

    const libraries = await sharePointGraphService.listLibraries(siteId);
    persistInventorySafely(() => inventoryDbService.recordLibraries(siteId, libraries));
    persistResourceSafely(() => resourcePersistenceService.upsertLibraries(siteId, libraries));
    return res.json({ success: true, count: libraries.length, data: libraries, dataSource: 'graph' });
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
    persistResourceSafely(() => resourcePersistenceService.upsertLibraries(siteId, [created]));

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
    persistResourceSafely(() => resourcePersistenceService.upsertLibraries(siteId, [updated]));
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
    persistResourceSafely(() => {
      if (created?.drive) {
        return resourcePersistenceService.upsertDrives(siteId, [created.drive]);
      }
      return resourcePersistenceService.upsertLibraries(siteId, [created]);
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
    persistResourceSafely(() => resourcePersistenceService.upsertDrives(null, [updated]));
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar drive SharePoint.');
  }
}

export async function listDriveChildren(req, res) {
  try {
    const { driveId } = req.params;
    const path = req.query.path || '';
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!driveId) {
      return res.status(400).json({
        success: false,
        error: { code: 'SP_400', message: 'driveId é obrigatório.' }
      });
    }

    if (!refresh) {
      const cachedItems = await resourceQueryService.listDriveItems(driveId, { path, top: 500, filesOnly: false });
      if (cachedItems.length > 0) {
        return res.json({ success: true, count: cachedItems.length, data: cachedItems, dataSource: 'local-db' });
      }
    }

    const items = await sharePointGraphService.listChildren(driveId, path);
    persistInventorySafely(() => inventoryDbService.recordFiles(driveId, items, { path, source: 'children' }));
    persistResourceSafely(() => resourcePersistenceService.upsertDriveItems(driveId, items, { path }));
    return res.json({ success: true, count: items.length, data: items, dataSource: 'graph' });
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
    persistResourceSafely(() => resourcePersistenceService.upsertDriveItems(driveId, [folder], { path: parentPath || '' }));
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
    persistResourceSafely(() => resourcePersistenceService.upsertDriveItems(driveId, [item], { path: parentPath || '' }));

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
    persistResourceSafely(() => resourcePersistenceService.upsertDriveItems(driveId, [updated]));
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
    persistResourceSafely(() => resourcePersistenceService.deleteDriveItem(driveId, itemId));
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
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!driveId) {
      return sendValidationError(res, req, 'driveId é obrigatório.');
    }

    if (!refresh) {
      const cachedItems = await resourceQueryService.listDriveItems(driveId, { path, top, filesOnly: true });
      if (cachedItems.length > 0) {
        return res.json({
          success: true,
          count: cachedItems.length,
          data: cachedItems,
          dataSource: 'local-db'
        });
      }
    }

    const items = await sharePointGraphService.listDriveFilesWithMetadata(driveId, path, top);
    persistInventorySafely(() => inventoryDbService.recordFiles(driveId, items, { path, source: 'files-metadata' }));
    persistResourceSafely(() => resourcePersistenceService.upsertDriveItems(driveId, items, { path }));
    return res.json({
      success: true,
      count: items.length,
      data: items,
      dataSource: 'graph'
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar arquivos e metadados do drive SharePoint.');
  }
}

export async function listGroups(req, res) {
  try {
    const search = req.query.search || '';
    const top = req.query.top ? parseInt(req.query.top, 10) : 25;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!refresh) {
      const cachedGroups = await resourceQueryService.listGroups({ search, top });
      if (cachedGroups.length > 0) {
        return res.json({ success: true, count: cachedGroups.length, data: cachedGroups, dataSource: 'local-db' });
      }
    }

    const groups = await sharePointGraphService.listGroups(search, top);
    persistResourceSafely(() => resourcePersistenceService.upsertGroups(groups));
    return res.json({ success: true, count: groups.length, data: groups, dataSource: 'graph' });
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

    persistResourceSafely(() => resourcePersistenceService.upsertGroups([created]));

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
    persistResourceSafely(() => resourcePersistenceService.upsertGroups([updated]));
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar grupo Entra ID.');
  }
}

export async function listUsers(req, res) {
  try {
    const search = req.query.search || '';
    const top = req.query.top ? parseInt(req.query.top, 10) : 25;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!refresh) {
      const cachedUsers = await resourceQueryService.listUsers({ search, top });
      if (cachedUsers.length > 0) {
        return res.json({ success: true, count: cachedUsers.length, data: cachedUsers, dataSource: 'local-db' });
      }
    }

    const users = await sharePointGraphService.listUsers(search, top);
    persistResourceSafely(() => resourcePersistenceService.upsertUsers(users));
    return res.json({ success: true, count: users.length, data: users, dataSource: 'graph' });
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
    persistResourceSafely(() => resourcePersistenceService.upsertUsers([updated]));
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar usuário.');
  }
}

export async function listUserLicenses(req, res) {
  try {
    const { userId } = req.params;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';
    if (!userId) {
      return sendValidationError(res, req, 'userId é obrigatório.');
    }

    if (!refresh) {
      const cachedLicenses = await resourceQueryService.listUserLicenses(userId);
      if (cachedLicenses.length > 0) {
        return res.json({ success: true, count: cachedLicenses.length, data: cachedLicenses, dataSource: 'local-db' });
      }
    }

    const licenses = await sharePointGraphService.listUserLicenses(userId);
    persistResourceSafely(() => resourcePersistenceService.replaceUserLicenses(userId, licenses));
    return res.json({ success: true, count: licenses.length, data: licenses, dataSource: 'graph' });
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
    persistResourceSafely(async () => {
      const refreshed = await sharePointGraphService.listUserLicenses(userId);
      await resourcePersistenceService.replaceUserLicenses(userId, refreshed);
    });
    return res.json({ success: true, data: result });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao alterar licenças do usuário.');
  }
}

export async function listTeams(req, res) {
  try {
    const search = req.query.search || '';
    const top = req.query.top ? parseInt(req.query.top, 10) : 25;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!refresh) {
      const cachedTeams = await resourceQueryService.listTeams({ search, top });
      if (cachedTeams.length > 0) {
        return res.json({ success: true, count: cachedTeams.length, data: cachedTeams, dataSource: 'local-db' });
      }
    }

    const teams = await sharePointGraphService.listTeams(search, top);
    persistResourceSafely(() => resourcePersistenceService.upsertTeams(teams));
    return res.json({ success: true, count: teams.length, data: teams, dataSource: 'graph' });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar times.');
  }
}

export async function listItemPermissions(req, res) {
  try {
    const { driveId, itemId } = req.params;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';
    if (!driveId || !itemId) {
      return sendValidationError(res, req, 'driveId e itemId são obrigatórios.');
    }

    if (!refresh) {
      const cachedPermissions = await resourceQueryService.listItemPermissions(driveId, itemId);
      if (cachedPermissions.length > 0) {
        return res.json({ success: true, count: cachedPermissions.length, data: cachedPermissions, dataSource: 'local-db' });
      }
    }

    const permissions = await sharePointGraphService.listItemPermissions(driveId, itemId);
    persistResourceSafely(() => resourcePersistenceService.replaceItemPermissions(driveId, itemId, permissions));
    return res.json({ success: true, count: permissions.length, data: permissions, dataSource: 'graph' });
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

    persistResourceSafely(async () => {
      const refreshed = await sharePointGraphService.listItemPermissions(driveId, itemId);
      await resourcePersistenceService.replaceItemPermissions(driveId, itemId, refreshed);
    });

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
    persistResourceSafely(() => resourcePersistenceService.deleteItemPermission(driveId, itemId, permissionId));
    return res.status(204).send();
  } catch (error) {
    return sendError(res, req, error, 'Falha ao remover permissão do item.');
  }
}

export async function listTeamChannels(req, res) {
  try {
    const { teamId } = req.params;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';
    if (!teamId) {
      return sendValidationError(res, req, 'teamId é obrigatório.');
    }

    if (!refresh) {
      const cachedChannels = await resourceQueryService.listTeamChannels(teamId);
      if (cachedChannels.length > 0) {
        return res.json({ success: true, count: cachedChannels.length, data: cachedChannels, dataSource: 'local-db' });
      }
    }

    const channels = await sharePointGraphService.listTeamChannels(teamId);
    persistResourceSafely(async () => {
      await resourcePersistenceService.ensureTeam(teamId, {});
      await resourcePersistenceService.upsertTeamChannels(teamId, channels);
    });
    return res.json({ success: true, count: channels.length, data: channels, dataSource: 'graph' });
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

    persistResourceSafely(async () => {
      await resourcePersistenceService.ensureTeam(teamId, {});
      await resourcePersistenceService.upsertTeamChannels(teamId, [created]);
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
    persistResourceSafely(async () => {
      await resourcePersistenceService.ensureTeam(teamId, {});
      await resourcePersistenceService.upsertTeamChannels(teamId, [updated]);
    });
    return res.json({ success: true, data: updated });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar canal do Teams.');
  }
}

export async function listChannelMembers(req, res) {
  try {
    const { teamId, channelId } = req.params;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';
    if (!teamId || !channelId) {
      return sendValidationError(res, req, 'teamId e channelId são obrigatórios.');
    }

    if (!refresh) {
      const cachedMembers = await resourceQueryService.listChannelMembers(teamId, channelId);
      if (cachedMembers.length > 0) {
        return res.json({ success: true, count: cachedMembers.length, data: cachedMembers, dataSource: 'local-db' });
      }
    }

    const members = await sharePointGraphService.listChannelMembers(teamId, channelId);
    persistResourceSafely(async () => {
      await resourcePersistenceService.ensureTeam(teamId, {});
      await resourcePersistenceService.replaceChannelMembers(teamId, channelId, members);
    });
    return res.json({ success: true, count: members.length, data: members, dataSource: 'graph' });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar membros do canal do Teams.');
  }
}

export async function listChannelContent(req, res) {
  try {
    const { teamId, channelId } = req.params;
    const topMessages = req.query.topMessages ? parseInt(req.query.topMessages, 10) : 25;
    const refresh = String(req.query.refresh || 'false').toLowerCase() === 'true';

    if (!teamId || !channelId) {
      return sendValidationError(res, req, 'teamId e channelId são obrigatórios.');
    }

    if (!refresh) {
      const cachedContent = await resourceQueryService.listChannelContent(teamId, channelId, topMessages);
      if ((cachedContent.messages || []).length > 0 || (cachedContent.files || []).length > 0) {
        return res.json({
          success: true,
          data: {
            teamId,
            channelId,
            filesFolder: cachedContent.filesFolder,
            messagesCount: cachedContent.messages.length,
            filesCount: cachedContent.files.length,
            messages: cachedContent.messages,
            files: cachedContent.files
          },
          dataSource: 'local-db'
        });
      }
    }

    const content = await sharePointGraphService.listChannelContent(teamId, channelId, topMessages);
    persistResourceSafely(async () => {
      await resourcePersistenceService.ensureTeam(teamId, {});
      await resourcePersistenceService.upsertChannelContent(teamId, channelId, content);
    });
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
      },
      dataSource: 'graph'
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
    persistResourceSafely(async () => {
      const members = await sharePointGraphService.listChannelMembers(teamId, channelId);
      await resourcePersistenceService.replaceChannelMembers(teamId, channelId, members);
    });
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
    persistResourceSafely(() => resourcePersistenceService.removeChannelMember(teamId, channelId, membershipId));
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
    persistResourceSafely(() => resourcePersistenceService.upsertGroupMember(groupId, memberObjectId));
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
    persistResourceSafely(() => resourcePersistenceService.removeGroupMember(groupId, memberObjectId));
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

    // Track export run in PostgreSQL. The INSERT is awaited so exportRunId is
    // available before the response is sent; the UPDATE fires in the background
    // via res.on('finish'). Both operations are no-ops when PG is not available.
    let exportRunId = null;
    if (pgService.isAvailable()) {
      const tenantId = process.env.AZURE_TENANT_ID || 'default';
      const r = await pgService.query(
        `INSERT INTO shp.export_runs (tenant_id, source, format, status, metadata)
         VALUES ($1, $2, $3, 'running', $4) RETURNING id`,
        [tenantId, source, format, { filters: req.query }]
      );
      exportRunId = r?.rows?.[0]?.id ?? null;
    }

    res.on('finish', () => {
      if (!exportRunId) return;
      const rowCount = Array.isArray(rowsForCsv) ? rowsForCsv.length : (payload?.count ?? null);
      const status = res.statusCode < 400 ? 'succeeded' : 'failed';
      pgService
        .query(
          `UPDATE shp.export_runs SET status=$2, row_count=$3, finished_at=now() WHERE id=$1`,
          [exportRunId, status, rowCount]
        )
        .catch(() => {});
    });

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

    persistResourceSafely(async () => {
      if (source === 'drive-files') {
        await resourcePersistenceService.upsertDriveItems(String(req.query.driveId || ''), rowsForCsv || [], {
          path: String(req.query.path || '')
        });
      } else if (source === 'site-drives') {
        await resourcePersistenceService.upsertDrives(String(req.query.siteId || ''), rowsForCsv || []);
      } else if (source === 'site-libraries') {
        await resourcePersistenceService.upsertLibraries(String(req.query.siteId || ''), rowsForCsv || []);
      } else if (source === 'groups') {
        await resourcePersistenceService.upsertGroups(rowsForCsv || []);
      } else if (source === 'users') {
        await resourcePersistenceService.upsertUsers(rowsForCsv || []);
      } else if (source === 'user-licenses') {
        await resourcePersistenceService.replaceUserLicenses(String(req.query.userId || ''), payload?.data || []);
      } else if (source === 'item-permissions') {
        await resourcePersistenceService.replaceItemPermissions(
          String(req.query.driveId || ''),
          String(req.query.itemId || ''),
          payload?.data || []
        );
      } else if (source === 'team-channels') {
        const teamId = String(req.query.teamId || '');
        await resourcePersistenceService.ensureTeam(teamId, {});
        await resourcePersistenceService.upsertTeamChannels(teamId, rowsForCsv || []);
      } else if (source === 'team-channel-members') {
        await resourcePersistenceService.replaceChannelMembers(
          String(req.query.teamId || ''),
          String(req.query.channelId || ''),
          payload?.data || []
        );
      } else if (source === 'team-channel-content') {
        await resourcePersistenceService.upsertChannelContent(
          String(req.query.teamId || ''),
          String(req.query.channelId || ''),
          payload || {}
        );
      } else if (source === 'tenant-sharepoint-inventory') {
        await resourcePersistenceService.upsertSites(payload?.data?.sites || []);
        await resourcePersistenceService.upsertDrives(null, payload?.data?.drives || []);
        await resourcePersistenceService.upsertDriveItems('', [
          ...(payload?.data?.files || []),
          ...(payload?.data?.folders || [])
        ]);
        for (const channel of payload?.data?.channels || []) {
          await resourcePersistenceService.upsertTeamChannels(channel.teamId, [channel]);
        }
      } else if (source === 'tenant-permissions-standard') {
        const grouped = new Map();
        for (const row of payload?.data?.permissions || []) {
          if (!row?.driveId || !row?.itemId) continue;
          const key = `${row.driveId}::${row.itemId}`;
          if (!grouped.has(key)) grouped.set(key, []);
          grouped.get(key).push({
            id: row.permissionId || null,
            roles: row.roles || [],
            inheritedFrom: row.inheritedFrom || null,
            link: row.link || null,
            invitation: row.invitation || null,
            grantedToV2: {
              user: {
                id: row.principalId || null,
                email: row.principalEmail || null,
                displayName: row.principalDisplayName || null
              }
            }
          });
        }

        for (const [key, permissions] of grouped.entries()) {
          const [driveId, itemId] = key.split('::');
          await resourcePersistenceService.replaceItemPermissions(driveId, itemId, permissions);
        }
      }
    });

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
          persistResourceSafely(async () => {
            const members = await sharePointGraphService.listChannelMembers(teamId, channelId);
            await resourcePersistenceService.replaceChannelMembers(teamId, channelId, members);
          });
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
        persistResourceSafely(async () => {
          const permissions = await sharePointGraphService.listItemPermissions(driveId, itemId);
          await resourcePersistenceService.replaceItemPermissions(driveId, itemId, permissions);
        });
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

export async function listFrontendCommands(req, res) {
  try {
    const commandType = String(req.query.commandType || '').trim().toLowerCase();
    const surface = String(req.query.surface || '').trim().toLowerCase();
    const pathContains = String(req.query.pathContains || '').trim();
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : 50;
    const offset = req.query.offset ? parseInt(req.query.offset, 10) : 0;

    let statusCode;
    if (req.query.statusCode !== undefined && String(req.query.statusCode).trim() !== '') {
      statusCode = parseInt(req.query.statusCode, 10);
      if (Number.isNaN(statusCode)) {
        return sendValidationError(res, req, 'statusCode inválido.');
      }
    }

    const data = await frontendCommandService.listCommands({
      commandType: commandType || undefined,
      surface: surface || undefined,
      pathContains: pathContains || undefined,
      statusCode,
      limit,
      offset
    });

    return res.status(200).json({ success: true, data });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar comandos executados via frontend.');
  }
}

export async function listDatabaseRecords(req, res) {
  try {
    if (!pgService.isAvailable()) {
      return res.status(200).json({
        success: true,
        data: {
          table: null,
          total: 0,
          limit: 0,
          offset: 0,
          items: [],
          availableTables: Object.keys(DATABASE_TABLES)
        }
      });
    }

    const table = String(req.query.table || 'sharepoint_sites').trim();
    const config = DATABASE_TABLES[table];
    if (!config) {
      return sendValidationError(res, req, `table inválida. Valores suportados: ${Object.keys(DATABASE_TABLES).join(', ')}`);
    }

    const limit = req.query.limit ? parseInt(req.query.limit, 10) : 50;
    const offset = req.query.offset ? parseInt(req.query.offset, 10) : 0;
    const safeLimit = Number.isFinite(limit) && limit > 0 ? Math.min(limit, 500) : 50;
    const safeOffset = Number.isFinite(offset) && offset >= 0 ? offset : 0;

    const q = String(req.query.q || '').trim();
    const queryText = q ? `%${q.toLowerCase()}%` : null;

    const whereClause = queryText
      ? `tenant_id = $1 AND CAST(to_jsonb(${table}) AS text) ILIKE $2`
      : 'tenant_id = $1';

    const countParams = queryText ? [process.env.AZURE_TENANT_ID || 'default', queryText] : [process.env.AZURE_TENANT_ID || 'default'];
    const countResult = await pgService.query(
      `SELECT COUNT(*) AS total FROM shp.${table} WHERE ${whereClause}`,
      countParams
    );

    const total = parseInt(countResult?.rows?.[0]?.total ?? '0', 10);
    const rowsResult = await pgService.query(
      `SELECT * FROM shp.${table}
        WHERE ${whereClause}
        ORDER BY ${config.orderBy} DESC NULLS LAST
        LIMIT ${safeLimit}
       OFFSET ${safeOffset}`,
      countParams
    );

    return res.status(200).json({
      success: true,
      data: {
        table,
        total,
        limit: safeLimit,
        offset: safeOffset,
        items: rowsResult?.rows || [],
        availableTables: Object.keys(DATABASE_TABLES)
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar conteúdo da base PostgreSQL.');
  }
}

export async function getDocumentation(req, res) {
  try {
    const docs = {
      tutorials: [
        { id: 'primeiros-passos', title: 'Primeiros passos', path: '/docs/tutorials/primeiros-passos.md', category: 'tutorial' },
        { id: 'postgresql-primeiros-passos', title: 'PostgreSQL: primeiros passos', path: '/docs/tutorials/postgresql-primeiros-passos.md', category: 'tutorial' }
      ],
      howto: [
        { id: 'expandir-recursos', title: 'Expandir recursos da API nas páginas HTML', path: '/docs/how-to/expandir-recursos-nas-paginas-html.md', category: 'how-to' },
        { id: 'operar-postgresql', title: 'Operar, manter e expandir PostgreSQL (inclui Azure Flexible Server)', path: '/docs/how-to/operar-e-expandir-postgresql.md', category: 'how-to' },
        { id: 'runbook-postgresql', title: 'Runbook de incidentes e troubleshooting PostgreSQL', path: '/docs/how-to/runbook-incidentes-postgresql.md', category: 'how-to' }
      ],
      reference: [
        { id: 'arquitetura-codigo', title: 'Arquitetura e código', path: '/docs/reference/arquitetura-e-codigo.md', category: 'reference' },
        { id: 'dependencias', title: 'Dependências', path: '/docs/reference/dependencias.md', category: 'reference' },
        { id: 'endpoints', title: 'Endpoints da API', path: '/docs/reference/endpoints.md', category: 'reference' },
        { id: 'endpoints-uso', title: 'Uso dos endpoints com Invoke-RestMethod, curl e Postman', path: '/docs/reference/endpoints-uso-cli-postman.md', category: 'reference' },
        { id: 'postgresql-ambiente', title: 'PostgreSQL: ambiente e schema', path: '/docs/reference/postgresql-ambiente-e-schema.md', category: 'reference' }
      ],
      explanation: [
        { id: 'design-decisoes', title: 'Decisões de design e limites do escopo', path: '/docs/explanation/design-e-decisoes.md', category: 'explanation' },
        { id: 'postgresql-plataforma', title: 'Por que PostgreSQL foi escolhido', path: '/docs/explanation/postgresql-como-plataforma-de-dados.md', category: 'explanation' }
      ]
    };

    const allDocs = [
      ...docs.tutorials,
      ...docs.howto,
      ...docs.reference,
      ...docs.explanation
    ];

    return res.json({
      success: true,
      data: {
        categories: {
          tutorial: { label: 'Tutoriais', count: docs.tutorials.length, items: docs.tutorials },
          howto: { label: 'Como fazer (How-to)', count: docs.howto.length, items: docs.howto },
          reference: { label: 'Referência', count: docs.reference.length, items: docs.reference },
          explanation: { label: 'Explicação', count: docs.explanation.length, items: docs.explanation }
        },
        all: allDocs,
        summary: {
          totalDocs: allDocs.length,
          totalTutorials: docs.tutorials.length,
          totalHowto: docs.howto.length,
          totalReference: docs.reference.length,
          totalExplanation: docs.explanation.length
        }
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar documentação.');
  }
}
