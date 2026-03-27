import axios from 'axios';
import { X509Certificate } from 'crypto';
import { existsSync, readFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import { ClientCertificateCredential, ClientSecretCredential } from '@azure/identity';

const GRAPH_BASE_URL = 'https://graph.microsoft.com/v1.0';
const DEFAULT_GRAPH_SCOPE = 'https://graph.microsoft.com/.default';
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const API_ROOT = resolve(__dirname, '..');

function getNonEmptyValue(value) {
  if (value === undefined || value === null) return '';
  const normalized = String(value).trim();
  return normalized;
}

function parsePositiveInt(value, fallbackValue) {
  const parsed = Number.parseInt(String(value || ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackValue;
}

function normalizeThumbprint(value) {
  return getNonEmptyValue(value).replace(/[^a-fA-F0-9]/g, '').toUpperCase();
}

function encodeGraphPath(value) {
  return String(value || '')
    .trim()
    .replace(/^\/+|\/+$/g, '')
    .split('/')
    .filter(Boolean)
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}

function sanitizeTop(value, fallbackValue = 25, maxValue = 200) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallbackValue;
  return Math.min(parsed, maxValue);
}

function mapDriveItemMetadata(item) {
  return {
    id: item.id,
    name: item.name,
    webUrl: item.webUrl,
    createdDateTime: item.createdDateTime,
    lastModifiedDateTime: item.lastModifiedDateTime,
    size: item.size,
    eTag: item.eTag,
    cTag: item.cTag,
    file: item.file || null,
    folder: item.folder || null,
    parentReference: item.parentReference || null,
    createdBy: item.createdBy || null,
    lastModifiedBy: item.lastModifiedBy || null,
    shared: item.shared || null
  };
}

function mapDirectoryObjectSummary(item) {
  return {
    id: item.id,
    displayName: item.displayName,
    description: item.description || '',
    mail: item.mail || '',
    mailNickname: item.mailNickname || '',
    userPrincipalName: item.userPrincipalName || '',
    jobTitle: item.jobTitle || '',
    accountEnabled: item.accountEnabled,
    visibility: item.visibility || '',
    createdDateTime: item.createdDateTime || null,
    securityEnabled: item.securityEnabled,
    mailEnabled: item.mailEnabled,
    groupTypes: item.groupTypes || []
  };
}

function mapLibrarySummary(item) {
  return {
    id: item.id,
    name: item.name || item.displayName || '',
    displayName: item.displayName || item.name || '',
    description: item.description || '',
    webUrl: item.webUrl || '',
    createdDateTime: item.createdDateTime || null,
    lastModifiedDateTime: item.lastModifiedDateTime || null,
    template: item?.list?.template || '',
    drive: item.drive
      ? {
        id: item.drive.id,
        name: item.drive.name || '',
        description: item.drive.description || '',
        driveType: item.drive.driveType || '',
        webUrl: item.drive.webUrl || ''
      }
      : null
  };
}

function readCertificateThumbprint(certificatePath) {
  const pemContent = readFileSync(certificatePath, 'utf8');
  const certificateMatch = pemContent.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/);

  if (!certificateMatch) {
    throw new Error('O PEM informado em CERT_PRIVATE_KEY_PATH precisa conter o certificado publico alem da chave privada.');
  }

  const certificate = new X509Certificate(certificateMatch[0]);
  return normalizeThumbprint(certificate.fingerprint);
}

class SharePointGraphService {
  constructor() {
    this.credential = null;
    this.cachedToken = null;
    this.cachedTokenExpiresOn = 0;
    this.lastAuthTime = null;
    this.authMethod = null;
    this.certificatePath = null;
    this.certificateThumbprint = null;
  }

  getConfig() {
    const certPath = getNonEmptyValue(process.env.CERT_PRIVATE_KEY_PATH);
    const clientSecret = getNonEmptyValue(process.env.CLIENT_SECRET);
    const graphScope = getNonEmptyValue(process.env.GRAPH_SCOPE) || DEFAULT_GRAPH_SCOPE;

    return {
      tenantIdConfigured: Boolean(process.env.TENANT_ID),
      clientIdConfigured: Boolean(process.env.CLIENT_ID),
      certificatePathConfigured: Boolean(certPath),
      certificateThumbprintConfigured: Boolean(getNonEmptyValue(process.env.CERT_THUMBPRINT)),
      clientSecretConfigured: Boolean(clientSecret),
      authMethod: this.authMethod || 'not-authenticated',
      graphBaseUrl: GRAPH_BASE_URL,
      scope: graphScope,
      isAuthenticated: Boolean(this.cachedToken && Date.now() < this.cachedTokenExpiresOn),
      lastAuthTime: this.lastAuthTime,
      certificatePath: this.certificatePath,
      certificateThumbprint: this.certificateThumbprint
    };
  }

  getCredential() {
    const tenantId = getNonEmptyValue(process.env.TENANT_ID);
    const clientId = getNonEmptyValue(process.env.CLIENT_ID);
    const clientSecret = getNonEmptyValue(process.env.CLIENT_SECRET);
    const certificateRelativePath = getNonEmptyValue(process.env.CERT_PRIVATE_KEY_PATH);
    const expectedThumbprint = normalizeThumbprint(process.env.CERT_THUMBPRINT);

    if (!tenantId || !clientId) {
      throw new Error('Configure TENANT_ID e CLIENT_ID no ambiente para usar Microsoft Graph.');
    }

    if (!certificateRelativePath && !clientSecret) {
      throw new Error('Configure CLIENT_SECRET ou CERT_PRIVATE_KEY_PATH/CERT_THUMBPRINT para autenticar no Microsoft Graph.');
    }

    if (!this.credential) {
      if (certificateRelativePath) {
        const certificatePath = resolve(API_ROOT, certificateRelativePath);

        if (!existsSync(certificatePath)) {
          throw new Error(`Certificado não encontrado em ${certificatePath}. Verifique CERT_PRIVATE_KEY_PATH.`);
        }

        if (!expectedThumbprint) {
          throw new Error('Configure CERT_THUMBPRINT para autenticar no Microsoft Graph com certificado.');
        }

        const actualThumbprint = readCertificateThumbprint(certificatePath);
        if (actualThumbprint !== expectedThumbprint) {
          throw new Error(
            `O thumbprint configurado em CERT_THUMBPRINT nao corresponde ao certificado em ${certificatePath}.`
          );
        }

        this.credential = new ClientCertificateCredential(tenantId, clientId, {
          certificatePath,
          sendCertificateChain: true
        });
        this.authMethod = 'client-certificate';
        this.certificatePath = certificatePath;
        this.certificateThumbprint = actualThumbprint;
      } else {
        this.credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
        this.authMethod = 'client-secret';
        this.certificatePath = null;
        this.certificateThumbprint = null;
      }
    }

    return this.credential;
  }

  async authenticate() {
    const graphScope = getNonEmptyValue(process.env.GRAPH_SCOPE) || DEFAULT_GRAPH_SCOPE;
    const token = await this.getCredential().getToken([graphScope]);
    if (!token || !token.token) {
      throw new Error('Falha ao obter token de acesso do Microsoft Graph.');
    }

    this.cachedToken = token.token;
    this.cachedTokenExpiresOn = token.expiresOnTimestamp || Date.now() + 45 * 60 * 1000;
    this.lastAuthTime = new Date().toISOString();

    return true;
  }

  async getAccessToken() {
    const now = Date.now();
    if (this.cachedToken && now < this.cachedTokenExpiresOn - 120000) {
      return this.cachedToken;
    }

    await this.authenticate();
    return this.cachedToken;
  }

  async requestGraph(method, path, { params, data, headers, retries = 2 } = {}) {
    const token = await this.getAccessToken();
    const url = `${GRAPH_BASE_URL}${path}`;
    const timeoutMs = parsePositiveInt(process.env.REQUEST_TIMEOUT_SECONDS, 30) * 1000;
    const maxRetries = parsePositiveInt(process.env.RETRY_ATTEMPTS, retries + 1) - 1;

    try {
      const response = await axios({
        method,
        url,
        params,
        data,
        timeout: timeoutMs,
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          ...(headers || {})
        }
      });

      return response.data;
    } catch (error) {
      const status = error?.response?.status;
      const transient = status === 429 || (status >= 500 && status <= 599);

      if (transient && retries > 0) {
        const attempt = maxRetries - retries + 1;
        const delayMs = Math.min(8000, 500 * (2 ** (attempt - 1)));
        await new Promise((resolve) => setTimeout(resolve, delayMs));
        return this.requestGraph(method, path, { params, data, headers, retries: retries - 1 });
      }

      const normalizedError = new Error(
        error?.response?.data?.error?.message || error.message || 'Erro de chamada no Microsoft Graph.'
      );
      normalizedError.status = status || 500;
      normalizedError.details = error?.response?.data || null;
      throw normalizedError;
    }
  }

  async listSites(search, top = 25) {
    const params = {
      search: search || '*',
      $top: Number.isFinite(top) ? top : 25
    };

    const retries = Math.max(parsePositiveInt(process.env.RETRY_ATTEMPTS, 3) - 1, 0);
    const response = await this.requestGraph('GET', '/sites', { params, retries });
    return response.value || [];
  }

  async createSite(parentSiteId, siteInput) {
    const displayName = String(siteInput?.displayName || '').trim();
    const name = String(siteInput?.name || '').trim();

    if (!displayName || !name) {
      const error = new Error('displayName e name são obrigatórios para criar um site.');
      error.status = 400;
      throw error;
    }

    const payload = { displayName, name };
    if (siteInput?.description) {
      payload.description = String(siteInput.description);
    }

    return this.requestGraph('POST', `/sites/${encodeURIComponent(parentSiteId)}/sites`, {
      data: payload
    });
  }

  async listDrives(siteId) {
    const response = await this.requestGraph('GET', `/sites/${encodeURIComponent(siteId)}/drives`);
    return response.value || [];
  }

  async listSitePermissions(siteId) {
    const response = await this.requestGraph('GET', `/sites/${encodeURIComponent(siteId)}/permissions`);
    return response.value || [];
  }

  async listLibraries(siteId) {
    const response = await this.requestGraph('GET', `/sites/${encodeURIComponent(siteId)}/lists`, {
      params: {
        $expand: 'drive'
      }
    });

    return (response.value || [])
      .filter((item) => item?.list?.template === 'documentLibrary' || item?.drive)
      .map(mapLibrarySummary);
  }

  async getLibrary(siteId, listId) {
    const library = await this.requestGraph('GET', `/sites/${encodeURIComponent(siteId)}/lists/${encodeURIComponent(listId)}`, {
      params: {
        $expand: 'drive'
      }
    });

    return mapLibrarySummary(library);
  }

  async createLibrary(siteId, libraryInput) {
    const displayName = String(libraryInput?.displayName || libraryInput?.name || '').trim();
    if (!displayName) {
      throw new Error('displayName é obrigatório para criar biblioteca.');
    }

    const payload = {
      displayName,
      list: {
        template: 'documentLibrary'
      }
    };

    if (libraryInput?.description) {
      payload.description = String(libraryInput.description);
    }

    if (Array.isArray(libraryInput?.columns) && libraryInput.columns.length > 0) {
      payload.columns = libraryInput.columns;
    }

    const created = await this.requestGraph('POST', `/sites/${encodeURIComponent(siteId)}/lists`, {
      data: payload
    });

    if (!created?.id) {
      return created;
    }

    return this.getLibrary(siteId, created.id);
  }

  async updateLibrary(siteId, listId, libraryInput) {
    const library = await this.getLibrary(siteId, listId);
    const driveId = library?.drive?.id;

    if (!driveId) {
      const error = new Error('A biblioteca informada não possui drive associado para atualização via Graph.');
      error.status = 400;
      throw error;
    }

    await this.updateDrive(driveId, {
      name: libraryInput?.displayName || libraryInput?.name,
      description: libraryInput?.description
    });

    return this.getLibrary(siteId, listId);
  }

  async createDrive(siteId, driveInput) {
    return this.createLibrary(siteId, driveInput);
  }

  async updateDrive(driveId, driveInput) {
    const payload = {};
    const name = String(driveInput?.name || '').trim();
    const description = driveInput?.description;

    if (name) {
      payload.name = name;
    }

    if (description !== undefined) {
      payload.description = String(description || '');
    }

    if (Object.keys(payload).length === 0) {
      throw new Error('Informe ao menos name ou description para atualizar o drive.');
    }

    await this.requestGraph('PATCH', `/drives/${encodeURIComponent(driveId)}`, {
      data: payload
    });

    return this.requestGraph('GET', `/drives/${encodeURIComponent(driveId)}`);
  }

  async listGroups(search = '', top = 25) {
    const params = {
      $top: sanitizeTop(top, 25, 200),
      $select: 'id,displayName,description,mail,mailNickname,visibility,createdDateTime,securityEnabled,mailEnabled,groupTypes'
    };

    if (search) {
      params.$search = `"displayName:${search}"`;
      params.$count = true;
    }

    const response = await this.requestGraph('GET', '/groups', {
      params,
      headers: search ? { ConsistencyLevel: 'eventual' } : undefined
    });

    return (response.value || []).map(mapDirectoryObjectSummary);
  }

  async createGroup(groupInput) {
    return this.requestGraph('POST', '/groups', { data: groupInput });
  }

  async updateGroup(groupId, groupInput) {
    await this.requestGraph('PATCH', `/groups/${encodeURIComponent(groupId)}`, { data: groupInput });
    return { id: groupId, ...groupInput };
  }

  async listUsers(search = '', top = 25) {
    const params = {
      $top: sanitizeTop(top, 25, 200),
      $select: 'id,displayName,userPrincipalName,mail,jobTitle,accountEnabled'
    };

    if (search) {
      params.$search = `"displayName:${search}" OR "mail:${search}" OR "userPrincipalName:${search}"`;
      params.$count = true;
    }

    const response = await this.requestGraph('GET', '/users', {
      params,
      headers: search ? { ConsistencyLevel: 'eventual' } : undefined
    });

    return (response.value || []).map(mapDirectoryObjectSummary);
  }

  async updateUser(userId, userInput) {
    await this.requestGraph('PATCH', `/users/${encodeURIComponent(userId)}`, { data: userInput });
    return { id: userId, ...userInput };
  }

  async listUserLicenses(userId) {
    const response = await this.requestGraph('GET', `/users/${encodeURIComponent(userId)}/licenseDetails`);
    return response.value || [];
  }

  async assignUserLicenses(userId, addLicenses = [], removeLicenses = []) {
    return this.requestGraph('POST', `/users/${encodeURIComponent(userId)}/assignLicense`, {
      data: {
        addLicenses,
        removeLicenses
      }
    });
  }

  async listChildren(driveId, path = '') {
    const normalized = encodeGraphPath(path);
    const endpoint = normalized
      ? `/drives/${encodeURIComponent(driveId)}/root:/${normalized}:/children`
      : `/drives/${encodeURIComponent(driveId)}/root/children`;

    const response = await this.requestGraph('GET', endpoint);
    return response.value || [];
  }

  async listDriveFilesWithMetadata(driveId, path = '', top = 100) {
    const items = await this.listChildren(driveId, path);
    const limited = items.slice(0, sanitizeTop(top, 100, 500));
    return limited.map(mapDriveItemMetadata);
  }

  async createFolder(driveId, name, parentPath = '') {
    const safeName = String(name || '').trim();
    if (!safeName) {
      throw new Error('Nome da pasta é obrigatório.');
    }

    const normalizedParent = encodeGraphPath(parentPath);
    const endpoint = normalizedParent
      ? `/drives/${encodeURIComponent(driveId)}/root:/${normalizedParent}:/children`
      : `/drives/${encodeURIComponent(driveId)}/root/children`;

    return this.requestGraph('POST', endpoint, {
      data: {
        name: safeName,
        folder: {},
        '@microsoft.graph.conflictBehavior': 'rename'
      }
    });
  }

  async uploadTextFile(driveId, fileName, content, parentPath = '') {
    const safeName = String(fileName || '').trim();
    if (!safeName) {
      throw new Error('Nome do arquivo é obrigatório.');
    }

    const normalizedParent = encodeGraphPath(parentPath);
    const encodedFileName = encodeURIComponent(safeName);
    const fullPath = normalizedParent ? `${normalizedParent}/${encodedFileName}` : encodedFileName;

    return this.requestGraph('PUT', `/drives/${encodeURIComponent(driveId)}/root:/${fullPath}:/content`, {
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      data: content || ''
    });
  }

  async renameItem(driveId, itemId, newName) {
    const safeName = String(newName || '').trim();
    if (!safeName) {
      throw new Error('Novo nome é obrigatório.');
    }

    return this.requestGraph('PATCH', `/drives/${encodeURIComponent(driveId)}/items/${encodeURIComponent(itemId)}`, {
      data: { name: safeName }
    });
  }

  async deleteItem(driveId, itemId) {
    await this.requestGraph('DELETE', `/drives/${encodeURIComponent(driveId)}/items/${encodeURIComponent(itemId)}`);
    return true;
  }

  async listItemPermissions(driveId, itemId) {
    const response = await this.requestGraph(
      'GET',
      `/drives/${encodeURIComponent(driveId)}/items/${encodeURIComponent(itemId)}/permissions`
    );
    return response.value || [];
  }

  async listDriveRootPermissions(driveId) {
    const response = await this.requestGraph('GET', `/drives/${encodeURIComponent(driveId)}/root/permissions`);
    return response.value || [];
  }

  async inviteItemPermissions(driveId, itemId, recipients = [], roles = ['read'], message = '') {
    return this.requestGraph(
      'POST',
      `/drives/${encodeURIComponent(driveId)}/items/${encodeURIComponent(itemId)}/invite`,
      {
        data: {
          requireSignIn: true,
          sendInvitation: false,
          roles,
          recipients,
          message
        }
      }
    );
  }

  async deleteItemPermission(driveId, itemId, permissionId) {
    await this.requestGraph(
      'DELETE',
      `/drives/${encodeURIComponent(driveId)}/items/${encodeURIComponent(itemId)}/permissions/${encodeURIComponent(permissionId)}`
    );
    return true;
  }

  async listTeamChannels(teamId) {
    const response = await this.requestGraph('GET', `/teams/${encodeURIComponent(teamId)}/channels`);
    return response.value || [];
  }

  async createTeamChannel(teamId, channelInput) {
    return this.requestGraph('POST', `/teams/${encodeURIComponent(teamId)}/channels`, { data: channelInput });
  }

  async updateTeamChannel(teamId, channelId, channelInput) {
    await this.requestGraph(
      'PATCH',
      `/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}`,
      { data: channelInput }
    );
    return { id: channelId, teamId, ...channelInput };
  }

  async listChannelMembers(teamId, channelId) {
    const response = await this.requestGraph(
      'GET',
      `/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}/members`
    );
    return response.value || [];
  }

  async listChannelMessages(teamId, channelId, top = 25) {
    const params = {
      $top: sanitizeTop(top, 25, 50)
    };

    const response = await this.requestGraph(
      'GET',
      `/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}/messages`,
      { params }
    );

    return response.value || [];
  }

  async listChannelContent(teamId, channelId, topMessages = 25) {
    const [messages, filesFolder] = await Promise.all([
      this.listChannelMessages(teamId, channelId, topMessages),
      this.requestGraph('GET', `/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}/filesFolder`)
    ]);

    let files = [];
    const driveId = filesFolder?.parentReference?.driveId;
    const folderItemId = filesFolder?.id;

    if (driveId && folderItemId) {
      const driveChildren = await this.requestGraph(
        'GET',
        `/drives/${encodeURIComponent(driveId)}/items/${encodeURIComponent(folderItemId)}/children`
      );
      files = (driveChildren.value || []).map(mapDriveItemMetadata);
    }

    return {
      filesFolder,
      messages,
      files
    };
  }

  async addChannelMember(teamId, channelId, userId, roles = []) {
    const normalizedRoles = Array.isArray(roles) ? roles : [];
    return this.requestGraph(
      'POST',
      `/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}/members`,
      {
        data: {
          '@odata.type': '#microsoft.graph.aadUserConversationMember',
          roles: normalizedRoles,
          "user@odata.bind": `https://graph.microsoft.com/v1.0/users('${encodeURIComponent(userId)}')`
        }
      }
    );
  }

  async removeChannelMember(teamId, channelId, membershipId) {
    await this.requestGraph(
      'DELETE',
      `/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}/members/${encodeURIComponent(membershipId)}`
    );
    return true;
  }

  async addGroupMember(groupId, memberObjectId) {
    return this.requestGraph('POST', `/groups/${encodeURIComponent(groupId)}/members/$ref`, {
      data: {
        '@odata.id': `https://graph.microsoft.com/v1.0/directoryObjects/${encodeURIComponent(memberObjectId)}`
      }
    });
  }

  async removeGroupMember(groupId, memberObjectId) {
    await this.requestGraph(
      'DELETE',
      `/groups/${encodeURIComponent(groupId)}/members/${encodeURIComponent(memberObjectId)}/$ref`
    );
    return true;
  }

  async listTeams(search = '', top = 25) {
    const params = {
      $top: sanitizeTop(top, 25, 200),
      $select: 'id,displayName,description,webUrl,isArchived'
    };

    if (search) {
      params.$search = `"displayName:${search}"`;
      params.$count = true;
    }

    const response = await this.requestGraph('GET', '/teams', {
      params,
      headers: search ? { ConsistencyLevel: 'eventual' } : undefined
    });

    return (response.value || []).map(team => ({
      id: team.id,
      displayName: team.displayName,
      description: team.description,
      webUrl: team.webUrl,
      isArchived: team.isArchived
    }));
  }
}

const sharePointGraphService = new SharePointGraphService();
export default sharePointGraphService;