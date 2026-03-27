import pgService from './pgService.js';

function tenantId() {
  return process.env.AZURE_TENANT_ID || 'default';
}

function asText(value) {
  if (value === null || value === undefined) return null;
  const str = String(value).trim();
  return str.length > 0 ? str : null;
}

function asBool(value) {
  if (value === null || value === undefined) return null;
  return Boolean(value);
}

function asInt(value) {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
}

function asTimestamp(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

class ResourcePersistenceService {
  async upsertSites(sites = []) {
    if (!pgService.isAvailable() || !Array.isArray(sites)) return;

    for (const site of sites) {
      const siteId = asText(site?.id);
      if (!siteId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_sites
           (tenant_id, site_id, hostname, display_name, web_url, is_personal_site,
            created_date_time, last_modified_date_time, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6,
            $7, $8, $9, now())
         ON CONFLICT (tenant_id, site_id)
         DO UPDATE SET
           hostname = EXCLUDED.hostname,
           display_name = EXCLUDED.display_name,
           web_url = EXCLUDED.web_url,
           is_personal_site = EXCLUDED.is_personal_site,
           created_date_time = EXCLUDED.created_date_time,
           last_modified_date_time = EXCLUDED.last_modified_date_time,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          siteId,
          asText(site?.siteCollection?.hostname),
          asText(site?.displayName || site?.name),
          asText(site?.webUrl),
          asBool(site?.isPersonalSite),
          asTimestamp(site?.createdDateTime),
          asTimestamp(site?.lastModifiedDateTime),
          site || {}
        ]
      );
    }
  }

  async upsertDrives(siteId, drives = []) {
    if (!pgService.isAvailable() || !Array.isArray(drives)) return;

    for (const drive of drives) {
      const driveId = asText(drive?.id);
      if (!driveId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_drives
           (tenant_id, drive_id, site_id, drive_type, name, web_url,
            quota_total, quota_used, quota_remaining,
            created_date_time, last_modified_date_time, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6,
            $7, $8, $9,
            $10, $11, $12, now())
         ON CONFLICT (tenant_id, drive_id)
         DO UPDATE SET
           site_id = EXCLUDED.site_id,
           drive_type = EXCLUDED.drive_type,
           name = EXCLUDED.name,
           web_url = EXCLUDED.web_url,
           quota_total = EXCLUDED.quota_total,
           quota_used = EXCLUDED.quota_used,
           quota_remaining = EXCLUDED.quota_remaining,
           created_date_time = EXCLUDED.created_date_time,
           last_modified_date_time = EXCLUDED.last_modified_date_time,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          driveId,
          asText(siteId || drive?.siteId),
          asText(drive?.driveType),
          asText(drive?.name || drive?.displayName),
          asText(drive?.webUrl),
          asInt(drive?.quota?.total),
          asInt(drive?.quota?.used),
          asInt(drive?.quota?.remaining),
          asTimestamp(drive?.createdDateTime),
          asTimestamp(drive?.lastModifiedDateTime),
          drive || {}
        ]
      );
    }
  }

  async upsertLibraries(siteId, libraries = []) {
    if (!pgService.isAvailable() || !Array.isArray(libraries)) return;

    for (const library of libraries) {
      const listId = asText(library?.id);
      if (!listId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_libraries
           (tenant_id, list_id, site_id, drive_id, name, description, web_url,
            created_date_time, last_modified_date_time, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6, $7,
            $8, $9, $10, now())
         ON CONFLICT (tenant_id, site_id, list_id)
         DO UPDATE SET
           drive_id = EXCLUDED.drive_id,
           name = EXCLUDED.name,
           description = EXCLUDED.description,
           web_url = EXCLUDED.web_url,
           created_date_time = EXCLUDED.created_date_time,
           last_modified_date_time = EXCLUDED.last_modified_date_time,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          listId,
          asText(siteId),
          asText(library?.drive?.id || library?.driveId),
          asText(library?.displayName || library?.name),
          asText(library?.description),
          asText(library?.webUrl),
          asTimestamp(library?.createdDateTime),
          asTimestamp(library?.lastModifiedDateTime),
          library || {}
        ]
      );
    }
  }

  async upsertDriveItems(driveId, items = [], context = {}) {
    if (!pgService.isAvailable() || !Array.isArray(items)) return;

    for (const item of items) {
      const itemId = asText(item?.id);
      if (!itemId) continue;

      const resolvedDriveId = asText(driveId || item?.driveId || item?.parentReference?.driveId);
      if (!resolvedDriveId) continue;

      const parentRefPath = asText(item?.parentReference?.path);
      await pgService.query(
        `INSERT INTO shp.sharepoint_drive_items
           (tenant_id, drive_id, item_id, parent_item_id, site_id, name, web_url, path,
            is_folder, mime_type, size_bytes,
            created_by_email, last_modified_by_email,
            created_date_time, last_modified_date_time, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6, $7, $8,
            $9, $10, $11,
            $12, $13,
            $14, $15, $16, now())
         ON CONFLICT (tenant_id, drive_id, item_id)
         DO UPDATE SET
           parent_item_id = EXCLUDED.parent_item_id,
           site_id = EXCLUDED.site_id,
           name = EXCLUDED.name,
           web_url = EXCLUDED.web_url,
           path = EXCLUDED.path,
           is_folder = EXCLUDED.is_folder,
           mime_type = EXCLUDED.mime_type,
           size_bytes = EXCLUDED.size_bytes,
           created_by_email = EXCLUDED.created_by_email,
           last_modified_by_email = EXCLUDED.last_modified_by_email,
           created_date_time = EXCLUDED.created_date_time,
           last_modified_date_time = EXCLUDED.last_modified_date_time,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          resolvedDriveId,
          itemId,
          asText(item?.parentReference?.id),
          asText(context?.siteId || item?.parentReference?.siteId || item?.siteId),
          asText(item?.name),
          asText(item?.webUrl),
          asText(context?.path || parentRefPath),
          asBool(item?.folder),
          asText(item?.file?.mimeType || item?.mimeType),
          asInt(item?.size),
          asText(item?.createdBy?.user?.email || item?.createdBy?.user?.userPrincipalName),
          asText(item?.lastModifiedBy?.user?.email || item?.lastModifiedBy?.user?.userPrincipalName),
          asTimestamp(item?.createdDateTime),
          asTimestamp(item?.lastModifiedDateTime),
          item || {}
        ]
      );
    }
  }

  async deleteDriveItem(driveId, itemId) {
    if (!pgService.isAvailable()) return;
    await pgService.query(
      `DELETE FROM shp.sharepoint_drive_items
        WHERE tenant_id = $1 AND drive_id = $2 AND item_id = $3`,
      [tenantId(), asText(driveId), asText(itemId)]
    );
  }

  async replaceItemPermissions(driveId, itemId, permissions = []) {
    if (!pgService.isAvailable()) return;

    await pgService.query(
      `DELETE FROM shp.sharepoint_item_permissions
        WHERE tenant_id = $1 AND drive_id = $2 AND item_id = $3`,
      [tenantId(), asText(driveId), asText(itemId)]
    );

    for (const permission of Array.isArray(permissions) ? permissions : []) {
      const principals = this.extractPrincipals(permission);
      const baseRoles = Array.isArray(permission?.roles) ? permission.roles : [];

      for (const principal of principals) {
        await pgService.query(
          `INSERT INTO shp.sharepoint_item_permissions
             (tenant_id, drive_id, item_id, permission_id,
              principal_type, principal_id, principal_email, principal_display_name,
              roles, inherited_from, link, invitation, raw_payload, last_seen_at)
           VALUES
             ($1, $2, $3, $4,
              $5, $6, $7, $8,
              $9, $10, $11, $12, $13, now())`,
          [
            tenantId(),
            asText(driveId),
            asText(itemId),
            asText(permission?.id),
            asText(principal.principalType),
            asText(principal.principalId),
            asText(principal.principalEmail),
            asText(principal.principalDisplayName),
            baseRoles,
            permission?.inheritedFrom || null,
            permission?.link || null,
            permission?.invitation || null,
            permission || {}
          ]
        );
      }
    }
  }

  async deleteItemPermission(driveId, itemId, permissionId) {
    if (!pgService.isAvailable()) return;
    await pgService.query(
      `DELETE FROM shp.sharepoint_item_permissions
        WHERE tenant_id = $1
          AND drive_id = $2
          AND item_id = $3
          AND permission_id = $4`,
      [tenantId(), asText(driveId), asText(itemId), asText(permissionId)]
    );
  }

  extractPrincipals(permission) {
    const principals = [];

    const identities = Array.isArray(permission?.grantedToIdentitiesV2)
      ? permission.grantedToIdentitiesV2
      : Array.isArray(permission?.grantedToIdentities)
        ? permission.grantedToIdentities
        : [];

    identities.forEach((identity) => {
      const user = identity?.user || {};
      principals.push({
        principalType: 'user',
        principalId: user.id || '',
        principalEmail: user.email || user.userPrincipalName || '',
        principalDisplayName: user.displayName || ''
      });
    });

    const single = permission?.grantedToV2 || permission?.grantedTo;
    if (single?.user) {
      principals.push({
        principalType: 'user',
        principalId: single.user.id || '',
        principalEmail: single.user.email || single.user.userPrincipalName || '',
        principalDisplayName: single.user.displayName || ''
      });
    }

    if (principals.length === 0) {
      principals.push({
        principalType: permission?.link ? 'link' : 'unknown',
        principalId: '',
        principalEmail: '',
        principalDisplayName: ''
      });
    }

    return principals;
  }

  async upsertGroups(groups = []) {
    if (!pgService.isAvailable() || !Array.isArray(groups)) return;

    for (const group of groups) {
      const groupId = asText(group?.id);
      if (!groupId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_groups
           (tenant_id, group_id, display_name, mail_nickname, mail, visibility,
            security_enabled, group_types, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6,
            $7, $8, $9, now())
         ON CONFLICT (tenant_id, group_id)
         DO UPDATE SET
           display_name = EXCLUDED.display_name,
           mail_nickname = EXCLUDED.mail_nickname,
           mail = EXCLUDED.mail,
           visibility = EXCLUDED.visibility,
           security_enabled = EXCLUDED.security_enabled,
           group_types = EXCLUDED.group_types,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          groupId,
          asText(group?.displayName),
          asText(group?.mailNickname),
          asText(group?.mail),
          asText(group?.visibility),
          asBool(group?.securityEnabled),
          Array.isArray(group?.groupTypes) ? group.groupTypes : [],
          group || {}
        ]
      );
    }
  }

  async upsertUsers(users = []) {
    if (!pgService.isAvailable() || !Array.isArray(users)) return;

    for (const user of users) {
      const userId = asText(user?.id);
      if (!userId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_users
           (tenant_id, user_id, user_principal_name, mail, display_name,
            given_name, surname, job_title, account_enabled,
            raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5,
            $6, $7, $8, $9,
            $10, now())
         ON CONFLICT (tenant_id, user_id)
         DO UPDATE SET
           user_principal_name = EXCLUDED.user_principal_name,
           mail = EXCLUDED.mail,
           display_name = EXCLUDED.display_name,
           given_name = EXCLUDED.given_name,
           surname = EXCLUDED.surname,
           job_title = EXCLUDED.job_title,
           account_enabled = EXCLUDED.account_enabled,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          userId,
          asText(user?.userPrincipalName),
          asText(user?.mail),
          asText(user?.displayName),
          asText(user?.givenName),
          asText(user?.surname),
          asText(user?.jobTitle),
          asBool(user?.accountEnabled),
          user || {}
        ]
      );
    }
  }

  async replaceUserLicenses(userId, licenses = []) {
    if (!pgService.isAvailable()) return;
    const safeUserId = asText(userId);
    if (!safeUserId) return;

    await pgService.query(
      `DELETE FROM shp.sharepoint_user_licenses
        WHERE tenant_id = $1 AND user_id = $2`,
      [tenantId(), safeUserId]
    );

    for (const license of Array.isArray(licenses) ? licenses : []) {
      const skuId = asText(license?.skuId);
      if (!skuId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_user_licenses
           (tenant_id, user_id, sku_id, sku_part_number, service_plans, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6, now())
         ON CONFLICT (tenant_id, user_id, sku_id)
         DO UPDATE SET
           sku_part_number = EXCLUDED.sku_part_number,
           service_plans = EXCLUDED.service_plans,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          safeUserId,
          skuId,
          asText(license?.skuPartNumber),
          Array.isArray(license?.servicePlans) ? license.servicePlans : [],
          license || {}
        ]
      );
    }
  }

  async ensureTeam(teamId, team = {}) {
    if (!pgService.isAvailable()) return;
    const safeTeamId = asText(teamId);
    if (!safeTeamId) return;

    await pgService.query(
      `INSERT INTO shp.sharepoint_teams
         (tenant_id, team_id, group_id, display_name, description, web_url, is_archived, raw_payload, last_seen_at)
       VALUES
         ($1, $2, $3, $4, $5, $6, $7, $8, now())
       ON CONFLICT (tenant_id, team_id)
       DO UPDATE SET
         group_id = COALESCE(EXCLUDED.group_id, shp.sharepoint_teams.group_id),
         display_name = COALESCE(EXCLUDED.display_name, shp.sharepoint_teams.display_name),
         description = COALESCE(EXCLUDED.description, shp.sharepoint_teams.description),
         web_url = COALESCE(EXCLUDED.web_url, shp.sharepoint_teams.web_url),
         is_archived = COALESCE(EXCLUDED.is_archived, shp.sharepoint_teams.is_archived),
         raw_payload = CASE WHEN EXCLUDED.raw_payload = '{}'::jsonb THEN shp.sharepoint_teams.raw_payload ELSE EXCLUDED.raw_payload END,
         last_seen_at = now()`,
      [
        tenantId(),
        safeTeamId,
        asText(team?.groupId),
        asText(team?.displayName),
        asText(team?.description),
        asText(team?.webUrl),
        asBool(team?.isArchived),
        Object.keys(team || {}).length > 0 ? team : {}
      ]
    );
  }

  async upsertTeamChannels(teamId, channels = []) {
    if (!pgService.isAvailable() || !Array.isArray(channels)) return;
    await this.ensureTeam(teamId, {});

    for (const channel of channels) {
      const channelId = asText(channel?.id);
      if (!channelId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_team_channels
           (tenant_id, team_id, channel_id, display_name, description,
            membership_type, web_url, email, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5,
            $6, $7, $8, $9, now())
         ON CONFLICT (tenant_id, team_id, channel_id)
         DO UPDATE SET
           display_name = EXCLUDED.display_name,
           description = EXCLUDED.description,
           membership_type = EXCLUDED.membership_type,
           web_url = EXCLUDED.web_url,
           email = EXCLUDED.email,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          asText(teamId),
          channelId,
          asText(channel?.displayName),
          asText(channel?.description),
          asText(channel?.membershipType),
          asText(channel?.webUrl),
          asText(channel?.email),
          channel || {}
        ]
      );
    }
  }

  async replaceChannelMembers(teamId, channelId, members = []) {
    if (!pgService.isAvailable()) return;
    const safeTeamId = asText(teamId);
    const safeChannelId = asText(channelId);
    if (!safeTeamId || !safeChannelId) return;

    await pgService.query(
      `DELETE FROM shp.sharepoint_channel_members
        WHERE tenant_id = $1 AND team_id = $2 AND channel_id = $3`,
      [tenantId(), safeTeamId, safeChannelId]
    );

    for (const member of Array.isArray(members) ? members : []) {
      const membershipId = asText(member?.id || member?.membershipId || member?.userId || member?.email);
      if (!membershipId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_channel_members
           (tenant_id, team_id, channel_id, membership_id, user_id, user_email,
            user_display_name, roles, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6,
            $7, $8, $9, now())
         ON CONFLICT (tenant_id, team_id, channel_id, membership_id)
         DO UPDATE SET
           user_id = EXCLUDED.user_id,
           user_email = EXCLUDED.user_email,
           user_display_name = EXCLUDED.user_display_name,
           roles = EXCLUDED.roles,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          safeTeamId,
          safeChannelId,
          membershipId,
          asText(member?.userId),
          asText(member?.email || member?.userPrincipalName),
          asText(member?.displayName || member?.name),
          Array.isArray(member?.roles) ? member.roles : [],
          member || {}
        ]
      );
    }
  }

  async removeChannelMember(teamId, channelId, membershipId) {
    if (!pgService.isAvailable()) return;
    await pgService.query(
      `DELETE FROM shp.sharepoint_channel_members
        WHERE tenant_id = $1 AND team_id = $2 AND channel_id = $3 AND membership_id = $4`,
      [tenantId(), asText(teamId), asText(channelId), asText(membershipId)]
    );
  }

  async upsertChannelContent(teamId, channelId, content) {
    if (!pgService.isAvailable()) return;

    const messages = Array.isArray(content?.messages) ? content.messages : [];
    const files = Array.isArray(content?.files) ? content.files : [];

    for (const message of messages) {
      const messageId = asText(message?.id);
      if (!messageId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_channel_messages
           (tenant_id, team_id, channel_id, message_id,
            from_id, from_display_name, summary, content_type, content, web_url,
            created_date_time, last_modified_date_time, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4,
            $5, $6, $7, $8, $9, $10,
            $11, $12, $13, now())
         ON CONFLICT (tenant_id, team_id, channel_id, message_id)
         DO UPDATE SET
           from_id = EXCLUDED.from_id,
           from_display_name = EXCLUDED.from_display_name,
           summary = EXCLUDED.summary,
           content_type = EXCLUDED.content_type,
           content = EXCLUDED.content,
           web_url = EXCLUDED.web_url,
           created_date_time = EXCLUDED.created_date_time,
           last_modified_date_time = EXCLUDED.last_modified_date_time,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          asText(teamId),
          asText(channelId),
          messageId,
          asText(message?.from?.user?.id || message?.from?.application?.id),
          asText(message?.from?.user?.displayName || message?.from?.application?.displayName),
          asText(message?.summary),
          asText(message?.body?.contentType),
          asText(message?.body?.content),
          asText(message?.webUrl),
          asTimestamp(message?.createdDateTime),
          asTimestamp(message?.lastModifiedDateTime),
          message || {}
        ]
      );
    }

    for (const file of files) {
      const fileId = asText(file?.id);
      if (!fileId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_channel_files
           (tenant_id, team_id, channel_id, file_id, drive_id, item_id, name, web_url,
            size_bytes, mime_type, is_folder, created_date_time, last_modified_date_time,
            raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6, $7, $8,
            $9, $10, $11, $12, $13,
            $14, now())
         ON CONFLICT (tenant_id, team_id, channel_id, file_id)
         DO UPDATE SET
           drive_id = EXCLUDED.drive_id,
           item_id = EXCLUDED.item_id,
           name = EXCLUDED.name,
           web_url = EXCLUDED.web_url,
           size_bytes = EXCLUDED.size_bytes,
           mime_type = EXCLUDED.mime_type,
           is_folder = EXCLUDED.is_folder,
           created_date_time = EXCLUDED.created_date_time,
           last_modified_date_time = EXCLUDED.last_modified_date_time,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          asText(teamId),
          asText(channelId),
          fileId,
          asText(file?.parentReference?.driveId || file?.driveId),
          asText(file?.id),
          asText(file?.name),
          asText(file?.webUrl),
          asInt(file?.size),
          asText(file?.file?.mimeType || file?.mimeType),
          asBool(file?.folder),
          asTimestamp(file?.createdDateTime),
          asTimestamp(file?.lastModifiedDateTime),
          file || {}
        ]
      );
    }
  }

  async upsertGroupMember(groupId, memberObjectId) {
    if (!pgService.isAvailable()) return;
    const safeGroupId = asText(groupId);
    const safeMemberId = asText(memberObjectId);
    if (!safeGroupId || !safeMemberId) return;

    await pgService.query(
      `INSERT INTO shp.sharepoint_group_members
         (tenant_id, group_id, member_id, member_type, member_email, member_display_name, raw_payload, last_seen_at)
       VALUES
         ($1, $2, $3, 'directoryObject', NULL, NULL, $4, now())
       ON CONFLICT (tenant_id, group_id, member_id)
       DO UPDATE SET
         last_seen_at = now()`,
      [tenantId(), safeGroupId, safeMemberId, { memberObjectId: safeMemberId }]
    );
  }

  async removeGroupMember(groupId, memberObjectId) {
    if (!pgService.isAvailable()) return;
    await pgService.query(
      `DELETE FROM shp.sharepoint_group_members
        WHERE tenant_id = $1 AND group_id = $2 AND member_id = $3`,
      [tenantId(), asText(groupId), asText(memberObjectId)]
    );
  }

  async upsertTeams(teams = []) {
    if (!pgService.isAvailable() || !Array.isArray(teams)) return;

    for (const team of teams) {
      const teamId = asText(team?.id);
      if (!teamId) continue;

      await pgService.query(
        `INSERT INTO shp.sharepoint_teams
           (tenant_id, team_id, group_id, display_name, description, web_url, is_archived, raw_payload, last_seen_at)
         VALUES
           ($1, $2, $3, $4, $5, $6, $7, $8, now())
         ON CONFLICT (tenant_id, team_id)
         DO UPDATE SET
           group_id = EXCLUDED.group_id,
           display_name = EXCLUDED.display_name,
           description = EXCLUDED.description,
           web_url = EXCLUDED.web_url,
           is_archived = EXCLUDED.is_archived,
           raw_payload = EXCLUDED.raw_payload,
           last_seen_at = now()`,
        [
          tenantId(),
          teamId,
          asText(team?.groupId || team?.group_id),
          asText(team?.displayName),
          asText(team?.description),
          asText(team?.webUrl),
          asBool(team?.isArchived),
          team || {}
        ]
      );
    }
  }
}

const resourcePersistenceService = new ResourcePersistenceService();

export default resourcePersistenceService;
