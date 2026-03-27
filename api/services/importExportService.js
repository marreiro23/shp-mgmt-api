import sharePointGraphService from './sharepointGraphService.js';

const SUPPORTED_IMPORT_MODES = ['always', 'skip-if-exists', 'update', 'replace-safe'];
const SUPPORTED_EXPORT_FORMATS = ['json', 'csv', 'xlsx'];
const SUPPORTED_OBJECT_TYPES = ['library', 'folder', 'permission'];

const IMPORT_PRIORITY = {
  library: 10,
  folder: 20,
  permission: 30
};

function normalizeRecipients(items) {
  if (!Array.isArray(items)) return [];
  return items
    .map((item) => ({
      email: String(item?.email || '').trim()
    }))
    .filter((item) => item.email);
}

function normalizeObjects(items) {
  if (!Array.isArray(items)) return [];
  return items
    .map((item, index) => {
      const type = String(item?.type || '').trim().toLowerCase();
      const name = String(item?.name || item?.displayName || '').trim();

      return {
        sourceIndex: index,
        type,
        name,
        description: String(item?.description || '').trim(),
        siteId: String(item?.siteId || '').trim(),
        driveId: String(item?.driveId || '').trim(),
        listId: String(item?.listId || '').trim(),
        parentPath: String(item?.parentPath || '').trim(),
        itemId: String(item?.itemId || '').trim(),
        recipients: normalizeRecipients(item?.recipients),
        roles: Array.isArray(item?.roles) && item.roles.length > 0 ? item.roles : ['read'],
        message: String(item?.message || '').trim(),
        columns: Array.isArray(item?.columns) ? item.columns : [],
        metadata: item?.metadata && typeof item.metadata === 'object' ? item.metadata : {}
      };
    })
    .filter((item) => item.type || item.name || item.siteId || item.driveId);
}

function resolveDependencies(items) {
  return [...items].sort((a, b) => {
    const priorityA = IMPORT_PRIORITY[a.type] || 999;
    const priorityB = IMPORT_PRIORITY[b.type] || 999;
    if (priorityA !== priorityB) return priorityA - priorityB;
    return a.sourceIndex - b.sourceIndex;
  });
}

function createValidationError(message) {
  const error = new Error(message);
  error.status = 400;
  error.code = 'SP_400';
  return error;
}

function isSameRoleSet(a, b) {
  const left = [...new Set(Array.isArray(a) ? a.map((role) => String(role).toLowerCase()) : [])].sort();
  const right = [...new Set(Array.isArray(b) ? b.map((role) => String(role).toLowerCase()) : [])].sort();
  return JSON.stringify(left) === JSON.stringify(right);
}

function parsePermissionEmails(permission) {
  const fromIdentities = Array.isArray(permission?.grantedToIdentitiesV2)
    ? permission.grantedToIdentitiesV2
    : Array.isArray(permission?.grantedToIdentities)
      ? permission.grantedToIdentities
      : [];

  const fromSingle = permission?.grantedToV2
    ? [permission.grantedToV2]
    : permission?.grantedTo
      ? [permission.grantedTo]
      : [];

  const emails = [...fromIdentities, ...fromSingle]
    .map((entry) => String(entry?.user?.email || entry?.user?.userPrincipalName || '').trim().toLowerCase())
    .filter(Boolean);

  return [...new Set(emails)];
}

function getModeAction(mode, exists) {
  if (mode === 'always') return exists ? 'create-new' : 'create';
  if (mode === 'skip-if-exists') return exists ? 'skip' : 'create';
  if (mode === 'update') return exists ? 'update' : 'create';
  if (mode === 'replace-safe') return exists ? 'replace' : 'create';
  return 'create';
}

class ImportExportService {
  getImportModes() {
    return [...SUPPORTED_IMPORT_MODES];
  }

  normalizeImportRequest(payload = {}) {
    const mode = String(payload.mode || 'always').toLowerCase();
    const objects = normalizeObjects(payload.objects);
    const options = payload.options && typeof payload.options === 'object' ? payload.options : {};

    return {
      mode,
      objects,
      options,
      sourceTenant: String(payload.sourceTenant || '').trim(),
      targetTenant: String(payload.targetTenant || '').trim(),
      dryRun: payload.dryRun !== false
    };
  }

  validateImportRequest(payload = {}) {
    if (!SUPPORTED_IMPORT_MODES.includes(payload.mode)) {
      const error = new Error(`mode invalido. Valores suportados: ${SUPPORTED_IMPORT_MODES.join(', ')}.`);
      error.status = 400;
      error.code = 'SP_400';
      throw error;
    }

    if (!Array.isArray(payload.objects) || payload.objects.length === 0) {
      throw createValidationError('objects e obrigatorio e deve conter ao menos um item.');
    }

    const unsupported = payload.objects
      .map((item) => item.type)
      .filter((type) => type && !SUPPORTED_OBJECT_TYPES.includes(type));

    if (unsupported.length > 0) {
      throw createValidationError(`type invalido em objects: ${[...new Set(unsupported)].join(', ')}.`);
    }
  }

  previewImport(normalized = {}) {
    const orderedObjects = resolveDependencies(normalized.objects || []);
    const objectCount = orderedObjects.length;
    const warnings = [];
    const unsupported = orderedObjects.filter((item) => !SUPPORTED_OBJECT_TYPES.includes(item.type));

    if (unsupported.length > 0) {
      warnings.push(`tipos ainda nao suportados no engine: ${[...new Set(unsupported.map((item) => item.type))].join(', ')}.`);
    }

    if (normalized.mode === 'replace-safe') {
      warnings.push('replace-safe pode sobrescrever configuracoes existentes; execute dry-run antes.');
    }

    if (!normalized.sourceTenant || !normalized.targetTenant) {
      warnings.push('sourceTenant e targetTenant nao informados; reconciliacao entre tenants pode ficar limitada.');
    }

    return {
      mode: normalized.mode,
      objectCount,
      dryRun: normalized.dryRun,
      warnings,
      executionOrder: orderedObjects.map((item) => ({
        type: item.type,
        name: item.name,
        siteId: item.siteId,
        driveId: item.driveId
      })),
      plannedSteps: [
        'validate-input',
        'resolve-dependencies',
        'resolve-identity-map',
        normalized.dryRun ? 'simulate-apply' : 'apply-changes'
      ]
    };
  }

  async findLibraryByName(siteId, displayName) {
    const libraries = await sharePointGraphService.listLibraries(siteId);
    const target = String(displayName || '').trim().toLowerCase();
    return libraries.find((item) => String(item?.displayName || item?.name || '').trim().toLowerCase() === target) || null;
  }

  async executeLibrary(item, mode, dryRun) {
    if (!item.siteId || !item.name) {
      throw createValidationError('Objetos do tipo library exigem siteId e name.');
    }

    const existing = await this.findLibraryByName(item.siteId, item.name);
    const action = getModeAction(mode, Boolean(existing));

    if (action === 'skip') {
      return { status: 'skipped', action, type: item.type, name: item.name, existingId: existing?.id || null };
    }

    if (dryRun) {
      return {
        status: 'simulated',
        action,
        type: item.type,
        name: item.name,
        existingId: existing?.id || null,
        siteId: item.siteId
      };
    }

    if (action === 'update' || action === 'replace') {
      const updated = await sharePointGraphService.updateLibrary(item.siteId, existing.id, {
        displayName: item.name,
        description: item.description,
        columns: item.columns
      });
      return { status: 'updated', action, type: item.type, name: item.name, id: updated?.id || existing.id, siteId: item.siteId };
    }

    const created = await sharePointGraphService.createLibrary(item.siteId, {
      displayName: item.name,
      description: item.description,
      columns: item.columns
    });
    return { status: 'created', action, type: item.type, name: item.name, id: created?.id || null, siteId: item.siteId };
  }

  async executeFolder(item, mode, dryRun) {
    if (!item.driveId || !item.name) {
      throw createValidationError('Objetos do tipo folder exigem driveId e name.');
    }

    const children = await sharePointGraphService.listChildren(item.driveId, item.parentPath || '');
    const existing = children.find((child) => String(child?.name || '').trim().toLowerCase() === item.name.toLowerCase() && Boolean(child?.folder));
    const action = getModeAction(mode, Boolean(existing));

    if (action === 'skip') {
      return { status: 'skipped', action, type: item.type, name: item.name, driveId: item.driveId };
    }

    if (dryRun) {
      return {
        status: 'simulated',
        action,
        type: item.type,
        name: item.name,
        driveId: item.driveId,
        parentPath: item.parentPath || ''
      };
    }

    if (action === 'update' || action === 'replace') {
      const renamed = await sharePointGraphService.renameItem(item.driveId, existing.id, item.name);
      return { status: 'updated', action, type: item.type, name: item.name, id: renamed?.id || existing.id, driveId: item.driveId };
    }

    const created = await sharePointGraphService.createFolder(item.driveId, item.name, item.parentPath || '');
    return { status: 'created', action, type: item.type, name: item.name, id: created?.id || null, driveId: item.driveId };
  }

  async executePermission(item, mode, dryRun) {
    if (!item.driveId || !item.itemId || item.recipients.length === 0) {
      throw createValidationError('Objetos do tipo permission exigem driveId, itemId e recipients.');
    }

    const existing = await sharePointGraphService.listItemPermissions(item.driveId, item.itemId);
    const recipientEmails = item.recipients.map((recipient) => recipient.email.toLowerCase());

    const matched = existing.find((permission) => {
      const permissionEmails = parsePermissionEmails(permission);
      const hasAllRecipients = recipientEmails.every((email) => permissionEmails.includes(email));
      return hasAllRecipients && isSameRoleSet(permission.roles, item.roles);
    });

    const action = getModeAction(mode, Boolean(matched));

    if (action === 'skip') {
      return { status: 'skipped', action, type: item.type, itemId: item.itemId, driveId: item.driveId };
    }

    if (dryRun) {
      return {
        status: 'simulated',
        action,
        type: item.type,
        itemId: item.itemId,
        driveId: item.driveId,
        recipients: item.recipients,
        roles: item.roles
      };
    }

    if ((action === 'update' || action === 'replace') && matched?.id) {
      await sharePointGraphService.deleteItemPermission(item.driveId, item.itemId, matched.id);
    }

    const created = await sharePointGraphService.inviteItemPermissions(
      item.driveId,
      item.itemId,
      item.recipients,
      item.roles,
      item.message || ''
    );

    return {
      status: action === 'update' || action === 'replace' ? 'updated' : 'created',
      action,
      type: item.type,
      itemId: item.itemId,
      driveId: item.driveId,
      id: created?.id || null
    };
  }

  async executeObject(item, mode, dryRun) {
    if (item.type === 'library') {
      return this.executeLibrary(item, mode, dryRun);
    }

    if (item.type === 'folder') {
      return this.executeFolder(item, mode, dryRun);
    }

    if (item.type === 'permission') {
      return this.executePermission(item, mode, dryRun);
    }

    throw createValidationError(`type nao suportado para execucao: ${item.type}`);
  }

  async executeImport(normalized = {}) {
    const orderedObjects = resolveDependencies(normalized.objects || []);
    const errors = [];
    const details = [];

    for (const item of orderedObjects) {
      try {
        const result = await this.executeObject(item, normalized.mode, normalized.dryRun);
        details.push({
          sourceIndex: item.sourceIndex,
          ...result
        });
      } catch (error) {
        errors.push({
          sourceIndex: item.sourceIndex,
          type: item.type,
          name: item.name,
          code: error.code || 'SP_500',
          message: error.publicMessage || error.message || 'Falha no processamento do objeto.'
        });
      }
    }

    const created = details.filter((item) => item.status === 'created').length;
    const updated = details.filter((item) => item.status === 'updated').length;
    const skipped = details.filter((item) => item.status === 'skipped').length;
    const replaced = details.filter((item) => item.action === 'replace' && (item.status === 'updated' || item.status === 'created')).length;

    const hasErrors = errors.length > 0;

    return {
      mode: normalized.mode,
      dryRun: normalized.dryRun,
      processed: orderedObjects.length,
      created,
      updated,
      skipped,
      replaced,
      failed: errors.length,
      status: hasErrors ? (details.length > 0 ? 'partial' : 'failed') : 'succeeded',
      details,
      errors
    };
  }

  buildExportPackageContract(input = {}) {
    const source = String(input.source || '').toLowerCase();
    const format = String(input.format || 'json').toLowerCase();

    if (!source) {
      const error = new Error('source e obrigatorio.');
      error.status = 400;
      error.code = 'SP_400';
      throw error;
    }

    if (!SUPPORTED_EXPORT_FORMATS.includes(format)) {
      const error = new Error(`format invalido. Valores suportados: ${SUPPORTED_EXPORT_FORMATS.join(', ')}.`);
      error.status = 400;
      error.code = 'SP_400';
      throw error;
    }

    return {
      source,
      format,
      packageVersion: '1.0.0',
      includes: ['data', 'manifest', 'dependency-map', 'identity-map'],
      pagination: {
        page: Number.parseInt(String(input.page || '1'), 10) || 1,
        pageSize: Number.parseInt(String(input.pageSize || '100'), 10) || 100
      },
      filters: {
        siteId: String(input.siteId || ''),
        driveId: String(input.driveId || ''),
        path: String(input.path || ''),
        search: String(input.search || '')
      }
    };
  }
}

const importExportService = new ImportExportService();

export default importExportService;
