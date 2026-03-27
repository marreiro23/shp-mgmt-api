import pgService from './pgService.js';

function tenantId() {
  return process.env.AZURE_TENANT_ID || 'default';
}

function mergePayload(row, fallback = {}) {
  const payload = row?.raw_payload && typeof row.raw_payload === 'object' ? row.raw_payload : {};
  return {
    ...fallback,
    ...payload
  };
}

function parseTop(top, fallback = 25, max = 500) {
  const parsed = Number(top);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.trunc(parsed), max);
}

class ResourceQueryService {
  async listSites({ search = '*', top = 25 } = {}) {
    if (!pgService.isAvailable()) return [];

    const effectiveTop = parseTop(top, 25, 500);
    const text = search && search !== '*' ? `%${String(search).toLowerCase()}%` : null;

    const result = await pgService.query(
      `SELECT site_id, display_name, web_url, hostname, raw_payload
         FROM shp.sharepoint_sites
        WHERE tenant_id = $1
          AND ($2::text IS NULL OR LOWER(COALESCE(display_name, '')) LIKE $2 OR LOWER(site_id) LIKE $2)
        ORDER BY last_seen_at DESC
        LIMIT ${effectiveTop}`,
      [tenantId(), text]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.site_id,
      displayName: row.display_name,
      webUrl: row.web_url,
      siteCollection: row.hostname ? { hostname: row.hostname } : undefined
    }));
  }

  async listDrives(siteId) {
    if (!pgService.isAvailable()) return [];

    const result = await pgService.query(
      `SELECT drive_id, name, web_url, drive_type, raw_payload
         FROM shp.sharepoint_drives
        WHERE tenant_id = $1 AND site_id = $2
        ORDER BY last_seen_at DESC`,
      [tenantId(), String(siteId)]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.drive_id,
      name: row.name,
      webUrl: row.web_url,
      driveType: row.drive_type
    }));
  }

  async listLibraries(siteId) {
    if (!pgService.isAvailable()) return [];

    const result = await pgService.query(
      `SELECT list_id, drive_id, name, description, web_url, raw_payload
         FROM shp.sharepoint_libraries
        WHERE tenant_id = $1 AND site_id = $2
        ORDER BY last_seen_at DESC`,
      [tenantId(), String(siteId)]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.list_id,
      displayName: row.name,
      description: row.description,
      webUrl: row.web_url,
      drive: row.drive_id ? { id: row.drive_id } : undefined
    }));
  }

  async listDriveItems(driveId, { path = '', top = 100, filesOnly = false } = {}) {
    if (!pgService.isAvailable()) return [];

    const effectiveTop = parseTop(top, 100, 1000);
    const pathLike = path ? `%${String(path).toLowerCase()}%` : null;

    const result = await pgService.query(
      `SELECT item_id, name, web_url, is_folder, mime_type, size_bytes, path, raw_payload
         FROM shp.sharepoint_drive_items
        WHERE tenant_id = $1
          AND drive_id = $2
          AND ($3::text IS NULL OR LOWER(COALESCE(path, '')) LIKE $3)
          AND ($4::bool = false OR COALESCE(is_folder, false) = false)
        ORDER BY last_seen_at DESC
        LIMIT ${effectiveTop}`,
      [tenantId(), String(driveId), pathLike, filesOnly]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.item_id,
      name: row.name,
      webUrl: row.web_url,
      size: row.size_bytes,
      folder: row.is_folder ? {} : undefined,
      file: row.mime_type ? { mimeType: row.mime_type } : undefined,
      parentReference: row.path ? { path: row.path } : undefined
    }));
  }

  async listGroups({ search = '', top = 25 } = {}) {
    if (!pgService.isAvailable()) return [];

    const effectiveTop = parseTop(top, 25, 500);
    const text = search ? `%${String(search).toLowerCase()}%` : null;

    const result = await pgService.query(
      `SELECT group_id, display_name, mail, mail_nickname, visibility, security_enabled, group_types, raw_payload
         FROM shp.sharepoint_groups
        WHERE tenant_id = $1
          AND ($2::text IS NULL OR LOWER(COALESCE(display_name, '')) LIKE $2 OR LOWER(COALESCE(mail, '')) LIKE $2)
        ORDER BY last_seen_at DESC
        LIMIT ${effectiveTop}`,
      [tenantId(), text]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.group_id,
      displayName: row.display_name,
      mail: row.mail,
      mailNickname: row.mail_nickname,
      visibility: row.visibility,
      securityEnabled: row.security_enabled,
      groupTypes: row.group_types || []
    }));
  }

  async listUsers({ search = '', top = 25 } = {}) {
    if (!pgService.isAvailable()) return [];

    const effectiveTop = parseTop(top, 25, 500);
    const text = search ? `%${String(search).toLowerCase()}%` : null;

    const result = await pgService.query(
      `SELECT user_id, user_principal_name, mail, display_name, job_title, account_enabled, raw_payload
         FROM shp.sharepoint_users
        WHERE tenant_id = $1
          AND ($2::text IS NULL
               OR LOWER(COALESCE(display_name, '')) LIKE $2
               OR LOWER(COALESCE(mail, '')) LIKE $2
               OR LOWER(COALESCE(user_principal_name, '')) LIKE $2)
        ORDER BY last_seen_at DESC
        LIMIT ${effectiveTop}`,
      [tenantId(), text]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.user_id,
      userPrincipalName: row.user_principal_name,
      mail: row.mail,
      displayName: row.display_name,
      jobTitle: row.job_title,
      accountEnabled: row.account_enabled
    }));
  }

  async listUserLicenses(userId) {
    if (!pgService.isAvailable()) return [];

    const result = await pgService.query(
      `SELECT sku_id, sku_part_number, service_plans, raw_payload
         FROM shp.sharepoint_user_licenses
        WHERE tenant_id = $1 AND user_id = $2
        ORDER BY last_seen_at DESC`,
      [tenantId(), String(userId)]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      skuId: row.sku_id,
      skuPartNumber: row.sku_part_number,
      servicePlans: row.service_plans || []
    }));
  }

  async listItemPermissions(driveId, itemId) {
    if (!pgService.isAvailable()) return [];

    const result = await pgService.query(
      `SELECT permission_id, principal_type, principal_id, principal_email, principal_display_name,
              roles, inherited_from, link, invitation, raw_payload
         FROM shp.sharepoint_item_permissions
        WHERE tenant_id = $1 AND drive_id = $2 AND item_id = $3
        ORDER BY last_seen_at DESC`,
      [tenantId(), String(driveId), String(itemId)]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.permission_id,
      roles: row.roles || [],
      grantedToV2: {
        user: {
          id: row.principal_id,
          email: row.principal_email,
          displayName: row.principal_display_name
        }
      },
      inheritedFrom: row.inherited_from,
      link: row.link,
      invitation: row.invitation
    }));
  }

  async listTeamChannels(teamId) {
    if (!pgService.isAvailable()) return [];

    const result = await pgService.query(
      `SELECT channel_id, display_name, description, membership_type, web_url, email, raw_payload
         FROM shp.sharepoint_team_channels
        WHERE tenant_id = $1 AND team_id = $2
        ORDER BY last_seen_at DESC`,
      [tenantId(), String(teamId)]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.channel_id,
      displayName: row.display_name,
      description: row.description,
      membershipType: row.membership_type,
      webUrl: row.web_url,
      email: row.email
    }));
  }

  async listChannelMembers(teamId, channelId) {
    if (!pgService.isAvailable()) return [];

    const result = await pgService.query(
      `SELECT membership_id, user_id, user_email, user_display_name, roles, raw_payload
         FROM shp.sharepoint_channel_members
        WHERE tenant_id = $1 AND team_id = $2 AND channel_id = $3
        ORDER BY last_seen_at DESC`,
      [tenantId(), String(teamId), String(channelId)]
    );

    return (result?.rows || []).map((row) => mergePayload(row, {
      id: row.membership_id,
      userId: row.user_id,
      email: row.user_email,
      displayName: row.user_display_name,
      roles: row.roles || []
    }));
  }

  async listChannelContent(teamId, channelId, topMessages = 25) {
    if (!pgService.isAvailable()) {
      return { filesFolder: null, messages: [], files: [] };
    }

    const messagesTop = parseTop(topMessages, 25, 200);

    const [messageResult, fileResult] = await Promise.all([
      pgService.query(
        `SELECT message_id, from_id, from_display_name, summary, content_type, content, web_url,
                created_date_time, last_modified_date_time, raw_payload
           FROM shp.sharepoint_channel_messages
          WHERE tenant_id = $1 AND team_id = $2 AND channel_id = $3
          ORDER BY created_date_time DESC NULLS LAST, last_seen_at DESC
          LIMIT ${messagesTop}`,
        [tenantId(), String(teamId), String(channelId)]
      ),
      pgService.query(
        `SELECT file_id, name, web_url, size_bytes, mime_type, is_folder,
                created_date_time, last_modified_date_time, raw_payload
           FROM shp.sharepoint_channel_files
          WHERE tenant_id = $1 AND team_id = $2 AND channel_id = $3
          ORDER BY last_seen_at DESC`,
        [tenantId(), String(teamId), String(channelId)]
      )
    ]);

    const messages = (messageResult?.rows || []).map((row) => mergePayload(row, {
      id: row.message_id,
      from: {
        user: {
          id: row.from_id,
          displayName: row.from_display_name
        }
      },
      summary: row.summary,
      body: {
        contentType: row.content_type,
        content: row.content
      },
      webUrl: row.web_url,
      createdDateTime: row.created_date_time,
      lastModifiedDateTime: row.last_modified_date_time
    }));

    const files = (fileResult?.rows || []).map((row) => mergePayload(row, {
      id: row.file_id,
      name: row.name,
      webUrl: row.web_url,
      size: row.size_bytes,
      file: row.mime_type ? { mimeType: row.mime_type } : undefined,
      folder: row.is_folder ? {} : undefined,
      createdDateTime: row.created_date_time,
      lastModifiedDateTime: row.last_modified_date_time
    }));

    return {
      filesFolder: null,
      messages,
      files
    };
  }
}

const resourceQueryService = new ResourceQueryService();

export default resourceQueryService;
