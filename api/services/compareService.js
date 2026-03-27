import sharePointGraphService from './sharepointGraphService.js';

const SUPPORTED_COMPARE_TYPES = ['library', 'folder', 'permission'];
const COMPARE_PRIORITY = {
  library: 10,
  folder: 20,
  permission: 30
};

function normalizeRecipients(items) {
  if (!Array.isArray(items)) return [];
  return items
    .map((item) => ({ email: String(item?.email || '').trim() }))
    .filter((item) => item.email);
}

function normalizeObjects(items) {
  if (!Array.isArray(items)) return [];
  return items
    .map((item, index) => ({
      sourceIndex: index,
      type: String(item?.type || '').trim().toLowerCase(),
      name: String(item?.name || item?.displayName || '').trim(),
      description: String(item?.description || '').trim(),
      siteId: String(item?.siteId || '').trim(),
      driveId: String(item?.driveId || '').trim(),
      parentPath: String(item?.parentPath || '').trim(),
      itemId: String(item?.itemId || '').trim(),
      recipients: normalizeRecipients(item?.recipients),
      roles: Array.isArray(item?.roles) && item.roles.length > 0 ? item.roles : ['read'],
      metadata: item?.metadata && typeof item.metadata === 'object' ? item.metadata : {}
    }))
    .filter((item) => item.type || item.name || item.siteId || item.driveId || item.itemId);
}

function createValidationError(message) {
  const error = new Error(message);
  error.status = 400;
  error.code = 'SP_400';
  return error;
}

function sortByDependency(items) {
  return [...items].sort((a, b) => {
    const pa = COMPARE_PRIORITY[a.type] || 999;
    const pb = COMPARE_PRIORITY[b.type] || 999;
    if (pa !== pb) return pa - pb;
    return a.sourceIndex - b.sourceIndex;
  });
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

function comparePrimitiveField(field, expected, actual) {
  if (expected === undefined || expected === null || String(expected).trim() === '') {
    return null;
  }

  if (String(expected) === String(actual || '')) {
    return null;
  }

  return {
    field,
    expected,
    actual: actual || ''
  };
}

class CompareService {
  normalizeCompareRequest(payload = {}) {
    return {
      baseline: String(payload.baseline || 'package').toLowerCase(),
      includeUnchanged: payload.includeUnchanged === true,
      objects: normalizeObjects(payload.objects)
    };
  }

  validateCompareRequest(payload = {}) {
    if (!Array.isArray(payload.objects) || payload.objects.length === 0) {
      throw createValidationError('objects e obrigatorio e deve conter ao menos um item para comparacao.');
    }

    const invalidTypes = payload.objects
      .map((item) => item.type)
      .filter((type) => type && !SUPPORTED_COMPARE_TYPES.includes(type));

    if (invalidTypes.length > 0) {
      throw createValidationError(`type invalido em objects: ${[...new Set(invalidTypes)].join(', ')}.`);
    }
  }

  async compareLibrary(item) {
    if (!item.siteId || !item.name) {
      throw createValidationError('Objetos do tipo library exigem siteId e name.');
    }

    const libraries = await sharePointGraphService.listLibraries(item.siteId);
    const existing = libraries.find((entry) => String(entry?.displayName || entry?.name || '').trim().toLowerCase() === item.name.toLowerCase());

    if (!existing) {
      return {
        type: item.type,
        name: item.name,
        siteId: item.siteId,
        status: 'missing',
        diffs: [{ field: 'displayName', expected: item.name, actual: null }]
      };
    }

    const diffs = [];
    const descriptionDiff = comparePrimitiveField('description', item.description, existing.description);
    if (descriptionDiff) diffs.push(descriptionDiff);

    return {
      type: item.type,
      name: item.name,
      siteId: item.siteId,
      status: diffs.length > 0 ? 'different' : 'equal',
      currentId: existing.id,
      diffs
    };
  }

  async compareFolder(item) {
    if (!item.driveId || !item.name) {
      throw createValidationError('Objetos do tipo folder exigem driveId e name.');
    }

    const children = await sharePointGraphService.listChildren(item.driveId, item.parentPath || '');
    const existing = children.find((entry) => String(entry?.name || '').trim().toLowerCase() === item.name.toLowerCase() && Boolean(entry?.folder));

    if (!existing) {
      return {
        type: item.type,
        name: item.name,
        driveId: item.driveId,
        parentPath: item.parentPath || '',
        status: 'missing',
        diffs: [{ field: 'name', expected: item.name, actual: null }]
      };
    }

    return {
      type: item.type,
      name: item.name,
      driveId: item.driveId,
      parentPath: item.parentPath || '',
      status: 'equal',
      currentId: existing.id,
      diffs: []
    };
  }

  async comparePermission(item) {
    if (!item.driveId || !item.itemId || item.recipients.length === 0) {
      throw createValidationError('Objetos do tipo permission exigem driveId, itemId e recipients.');
    }

    const currentPermissions = await sharePointGraphService.listItemPermissions(item.driveId, item.itemId);
    const recipientEmails = item.recipients.map((entry) => entry.email.toLowerCase());

    const matched = currentPermissions.find((permission) => {
      const emails = parsePermissionEmails(permission);
      const hasRecipients = recipientEmails.every((email) => emails.includes(email));
      return hasRecipients;
    });

    if (!matched) {
      return {
        type: item.type,
        driveId: item.driveId,
        itemId: item.itemId,
        status: 'missing',
        diffs: [{ field: 'recipients', expected: recipientEmails, actual: [] }]
      };
    }

    const diffs = [];
    if (!isSameRoleSet(item.roles, matched.roles || [])) {
      diffs.push({
        field: 'roles',
        expected: item.roles,
        actual: matched.roles || []
      });
    }

    return {
      type: item.type,
      driveId: item.driveId,
      itemId: item.itemId,
      status: diffs.length > 0 ? 'different' : 'equal',
      currentId: matched.id,
      diffs
    };
  }

  async compareObject(item) {
    if (item.type === 'library') {
      return this.compareLibrary(item);
    }

    if (item.type === 'folder') {
      return this.compareFolder(item);
    }

    if (item.type === 'permission') {
      return this.comparePermission(item);
    }

    throw createValidationError(`type nao suportado para comparacao: ${item.type}`);
  }

  async previewCompare(normalized = {}) {
    const ordered = sortByDependency(normalized.objects || []);
    const details = [];
    const errors = [];

    for (const item of ordered) {
      try {
        const result = await this.compareObject(item);
        if (normalized.includeUnchanged || result.status !== 'equal') {
          details.push({ sourceIndex: item.sourceIndex, ...result });
        }
      } catch (error) {
        errors.push({
          sourceIndex: item.sourceIndex,
          type: item.type,
          name: item.name,
          code: error.code || 'SP_500',
          message: error.publicMessage || error.message || 'Falha na comparacao do objeto.'
        });
      }
    }

    const summary = {
      total: ordered.length,
      equal: details.filter((item) => item.status === 'equal').length,
      missing: details.filter((item) => item.status === 'missing').length,
      different: details.filter((item) => item.status === 'different').length,
      failed: errors.length
    };

    return {
      baseline: normalized.baseline,
      executionOrder: ordered.map((item) => item.type),
      summary,
      details,
      errors,
      status: errors.length > 0 ? (details.length > 0 ? 'partial' : 'failed') : 'succeeded'
    };
  }

  async executeCompare(normalized = {}) {
    return this.previewCompare(normalized);
  }
}

const compareService = new CompareService();

export default compareService;
