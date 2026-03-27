-- ================================================================
-- shp-mgmt-api :: PostgreSQL Schema Setup
-- Version : 1.0.0
-- Applies to: local PostgreSQL 16 and Azure Flexible Server 16+
--
-- Prerequisites:
--   - Database must already exist  (created by Initialize-Database.ps1)
--   - Role shp_app_user must already exist (created by Initialize-Database.ps1)
--   - Execute as: pgadmin / postgres superuser against target database
--
-- Usage (psql):
--   psql -h HOST -U pgadmin -d shp_mgmt_db -f setup-schema.sql
-- ================================================================

\set ON_ERROR_STOP on

-- ----------------------------------------------------------------
-- SCHEMA
-- ----------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS shp;

COMMENT ON SCHEMA shp IS 'shp-mgmt-api: SharePoint tenant inventory and governance data';

-- ----------------------------------------------------------------
-- TABLE: shp.export_runs
-- Tracks each execution of GET /api/v1/sharepoint/export
-- One row per export call (tenant + source + format + timestamp)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.export_runs (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    source          TEXT            NOT NULL,           -- e.g. drive-files | tenant-sharepoint-inventory | tenant-permissions-standard
    format          TEXT            NOT NULL DEFAULT 'json',  -- json | csv | xlsx
    started_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ     NULL,
    status          TEXT            NOT NULL DEFAULT 'running',   -- running | succeeded | failed | partial
    row_count       INTEGER         NULL,
    summary         JSONB           NOT NULL DEFAULT '{}'::jsonb,
    metadata        JSONB           NOT NULL DEFAULT '{}'::jsonb  -- filters used, request context, etc.
);

COMMENT ON TABLE shp.export_runs IS 'Tracks each export run from /sharepoint/export endpoint';

-- ----------------------------------------------------------------
-- TABLE: shp.resources
-- Inventory of SharePoint / Teams resources collected via Graph API.
-- Covers: sites, drives, files, folders, libraries, channels, groups, users.
-- Sourced from endpoints:
--   GET /sharepoint/sites
--   GET /sharepoint/sites/:siteId/drives
--   GET /sharepoint/sites/:siteId/libraries
--   GET /sharepoint/drives/:driveId/children
--   GET /sharepoint/drives/:driveId/files-metadata
--   GET /sharepoint/teams/:teamId/channels
--   GET /sharepoint/groups
--   GET /sharepoint/users
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.resources (
    id                  BIGSERIAL       PRIMARY KEY,
    export_run_id       BIGINT          NOT NULL REFERENCES shp.export_runs(id) ON DELETE CASCADE,
    tenant_id           TEXT            NOT NULL,
    resource_type       TEXT            NOT NULL,   -- site | drive | library | folder | file | channel | team | group | user
    resource_id         TEXT            NOT NULL,   -- Graph API object ID
    parent_resource_id  TEXT            NULL,       -- logical parent ID when applicable
    site_id             TEXT            NULL,
    drive_id            TEXT            NULL,
    item_id             TEXT            NULL,
    team_id             TEXT            NULL,
    channel_id          TEXT            NULL,
    display_name        TEXT            NULL,
    web_url             TEXT            NULL,
    email               TEXT            NULL,       -- for groups/users
    created_by_email    TEXT            NULL,
    last_modified_by_email TEXT         NULL,
    created_at          TIMESTAMPTZ     NULL,
    last_modified_at    TIMESTAMPTZ     NULL,
    size_bytes          BIGINT          NULL,
    is_folder           BOOLEAN         NULL,
    mime_type           TEXT            NULL,
    visibility          TEXT            NULL,       -- public | private | hiddenmembership (groups/channels)
    payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,  -- full Graph object
    exported_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE shp.resources IS 'SharePoint/Teams resource inventory from Graph API';

-- ----------------------------------------------------------------
-- TABLE: shp.permissions
-- Normalized permissions in sharepoint-permission-v1 schema.
-- Sourced from endpoints:
--   GET /sharepoint/drives/:driveId/items/:itemId/permissions
--   GET /sharepoint/export?source=tenant-permissions-standard
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.permissions (
    id                      BIGSERIAL       PRIMARY KEY,
    export_run_id           BIGINT          NOT NULL REFERENCES shp.export_runs(id) ON DELETE CASCADE,
    tenant_id               TEXT            NOT NULL,
    schema_version          TEXT            NOT NULL DEFAULT 'sharepoint-permission-v1',
    resource_type           TEXT            NOT NULL,   -- site | drive | folder | file | channel
    resource_name           TEXT            NULL,
    site_id                 TEXT            NULL,
    drive_id                TEXT            NULL,
    item_id                 TEXT            NULL,
    team_id                 TEXT            NULL,
    channel_id              TEXT            NULL,
    permission_id           TEXT            NULL,
    principal_type          TEXT            NULL,       -- user | group | app | link | anyone
    principal_id            TEXT            NULL,
    principal_email         TEXT            NULL,
    principal_display_name  TEXT            NULL,
    roles                   JSONB           NOT NULL DEFAULT '[]'::jsonb,   -- ["read","write","owner",...]
    inherited_from          JSONB           NULL,
    link                    JSONB           NULL,       -- sharing link details
    invitation              JSONB           NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    exported_at             TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE shp.permissions IS 'SharePoint permissions in sharepoint-permission-v1 schema';

-- ----------------------------------------------------------------
-- TABLE: shp.operations
-- Tracks async long-running operations (compare, import-execute, export).
-- Mirrors: GET /api/v1/sharepoint/operations/:operationId
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.operations (
    id              TEXT            PRIMARY KEY,        -- operationId (UUID)
    tenant_id       TEXT            NOT NULL,
    operation_type  TEXT            NOT NULL,           -- compare | import | export
    status          TEXT            NOT NULL DEFAULT 'pending',  -- pending | running | succeeded | failed
    started_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ     NULL,
    progress        INTEGER         NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
    trigger_user    TEXT            NULL,               -- user/service that triggered the operation
    summary         JSONB           NOT NULL DEFAULT '{}'::jsonb,
    result          JSONB           NULL,
    error           JSONB           NULL
);

COMMENT ON TABLE shp.operations IS 'Async operation tracking for compare/import/export workflows';

-- ----------------------------------------------------------------
-- TABLE: shp.audit_events
-- Audit trail for all significant API actions.
-- Mirrors: GET /api/v1/sharepoint/audit/events
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.audit_events (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    event_type      TEXT            NOT NULL,   -- export | import | compare | auth | permission-change | resource-change
    actor           TEXT            NULL,        -- user email or 'system'
    resource_type   TEXT            NULL,
    resource_id     TEXT            NULL,
    site_id         TEXT            NULL,
    drive_id        TEXT            NULL,
    operation_id    TEXT            NULL REFERENCES shp.operations(id) ON DELETE SET NULL,
    export_run_id   BIGINT          NULL REFERENCES shp.export_runs(id) ON DELETE SET NULL,
    status          TEXT            NOT NULL DEFAULT 'success',  -- success | failed | skipped
    detail          JSONB           NOT NULL DEFAULT '{}'::jsonb,
    occurred_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE shp.audit_events IS 'Audit trail for API operations and permission changes';

-- ----------------------------------------------------------------
-- TABLE: shp.governance_packages
-- Tracks governance import/export packages.
-- Sourced from:
--   GET  /sharepoint/admin-governance/export/package
--   POST /sharepoint/admin-governance/import/execute
--   POST /sharepoint/admin-governance/import/permissions-package
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.governance_packages (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    package_type    TEXT            NOT NULL,           -- export | import | permissions-package
    direction       TEXT            NOT NULL,           -- export | import
    operation_id    TEXT            NULL REFERENCES shp.operations(id) ON DELETE SET NULL,
    dry_run         BOOLEAN         NOT NULL DEFAULT false,
    status          TEXT            NOT NULL DEFAULT 'pending',
    rows_total      INTEGER         NULL,
    rows_processed  INTEGER         NULL DEFAULT 0,
    rows_created    INTEGER         NULL DEFAULT 0,
    rows_updated    INTEGER         NULL DEFAULT 0,
    rows_skipped    INTEGER         NULL DEFAULT 0,
    rows_failed     INTEGER         NULL DEFAULT 0,
    payload         JSONB           NOT NULL DEFAULT '{}'::jsonb,   -- full package content hash / metadata
    error_detail    JSONB           NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ     NULL
);

COMMENT ON TABLE shp.governance_packages IS 'Governance import/export package tracking';

-- ----------------------------------------------------------------
-- TABLE: shp.frontend_commands
-- Stores create/update/export/import commands triggered by web pages.
-- Supports command history query from the same UI.
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.frontend_commands (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    client_surface  TEXT            NOT NULL,           -- operations-center | operations-page | admin-page
    command_type    TEXT            NOT NULL,           -- create | update | export | import
    http_method     TEXT            NOT NULL,
    request_path    TEXT            NOT NULL,
    query_params    JSONB           NOT NULL DEFAULT '{}'::jsonb,
    request_body    JSONB           NOT NULL DEFAULT '{}'::jsonb,
    response_status INTEGER         NOT NULL,
    success         BOOLEAN         NOT NULL DEFAULT false,
    correlation_id  TEXT            NULL,
    actor           TEXT            NULL,
    duration_ms     INTEGER         NULL,
    response_summary JSONB          NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE shp.frontend_commands IS 'History of create/update/export/import commands triggered by web interfaces';

-- ----------------------------------------------------------------
-- TABLES: Dedicated SharePoint resources (one table per managed resource)
-- ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS shp.sharepoint_sites (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    site_id                 TEXT            NOT NULL,
    hostname                TEXT            NULL,
    display_name            TEXT            NULL,
    web_url                 TEXT            NULL,
    is_personal_site        BOOLEAN         NULL,
    created_date_time       TIMESTAMPTZ     NULL,
    last_modified_date_time TIMESTAMPTZ     NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, site_id)
);

COMMENT ON TABLE shp.sharepoint_sites IS 'SharePoint sites managed by API endpoints';

CREATE TABLE IF NOT EXISTS shp.sharepoint_drives (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    drive_id                TEXT            NOT NULL,
    site_id                 TEXT            NULL,
    drive_type              TEXT            NULL,
    name                    TEXT            NULL,
    web_url                 TEXT            NULL,
    quota_total             BIGINT          NULL,
    quota_used              BIGINT          NULL,
    quota_remaining         BIGINT          NULL,
    created_date_time       TIMESTAMPTZ     NULL,
    last_modified_date_time TIMESTAMPTZ     NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, drive_id)
);

COMMENT ON TABLE shp.sharepoint_drives IS 'SharePoint drives/libraries root containers managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_libraries (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    list_id                 TEXT            NOT NULL,
    site_id                 TEXT            NOT NULL,
    drive_id                TEXT            NULL,
    name                    TEXT            NULL,
    description             TEXT            NULL,
    web_url                 TEXT            NULL,
    created_date_time       TIMESTAMPTZ     NULL,
    last_modified_date_time TIMESTAMPTZ     NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, site_id, list_id)
);

COMMENT ON TABLE shp.sharepoint_libraries IS 'SharePoint document libraries managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_drive_items (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    drive_id                TEXT            NOT NULL,
    item_id                 TEXT            NOT NULL,
    parent_item_id          TEXT            NULL,
    site_id                 TEXT            NULL,
    name                    TEXT            NULL,
    web_url                 TEXT            NULL,
    path                    TEXT            NULL,
    is_folder               BOOLEAN         NULL,
    mime_type               TEXT            NULL,
    size_bytes              BIGINT          NULL,
    created_by_email        TEXT            NULL,
    last_modified_by_email  TEXT            NULL,
    created_date_time       TIMESTAMPTZ     NULL,
    last_modified_date_time TIMESTAMPTZ     NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, drive_id, item_id)
);

COMMENT ON TABLE shp.sharepoint_drive_items IS 'SharePoint drive items (files/folders) managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_item_permissions (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    drive_id                TEXT            NOT NULL,
    item_id                 TEXT            NOT NULL,
    permission_id           TEXT            NULL,
    principal_type          TEXT            NULL,
    principal_id            TEXT            NULL,
    principal_email         TEXT            NULL,
    principal_display_name  TEXT            NULL,
    roles                   JSONB           NOT NULL DEFAULT '[]'::jsonb,
    inherited_from          JSONB           NULL,
    link                    JSONB           NULL,
    invitation              JSONB           NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE shp.sharepoint_item_permissions IS 'Permissions per drive item managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_groups (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    group_id                TEXT            NOT NULL,
    display_name            TEXT            NULL,
    mail_nickname           TEXT            NULL,
    mail                    TEXT            NULL,
    visibility              TEXT            NULL,
    security_enabled        BOOLEAN         NULL,
    group_types             JSONB           NOT NULL DEFAULT '[]'::jsonb,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, group_id)
);

COMMENT ON TABLE shp.sharepoint_groups IS 'Microsoft 365 / Entra groups managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_group_members (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    group_id                TEXT            NOT NULL,
    member_id               TEXT            NOT NULL,
    member_type             TEXT            NULL,
    member_email            TEXT            NULL,
    member_display_name     TEXT            NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, group_id, member_id)
);

COMMENT ON TABLE shp.sharepoint_group_members IS 'Group membership managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_users (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    user_id                 TEXT            NOT NULL,
    user_principal_name     TEXT            NULL,
    mail                    TEXT            NULL,
    display_name            TEXT            NULL,
    given_name              TEXT            NULL,
    surname                 TEXT            NULL,
    job_title               TEXT            NULL,
    account_enabled         BOOLEAN         NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, user_id)
);

COMMENT ON TABLE shp.sharepoint_users IS 'Users managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_user_licenses (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    user_id                 TEXT            NOT NULL,
    sku_id                  TEXT            NOT NULL,
    sku_part_number         TEXT            NULL,
    service_plans           JSONB           NOT NULL DEFAULT '[]'::jsonb,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, user_id, sku_id)
);

COMMENT ON TABLE shp.sharepoint_user_licenses IS 'User license assignments managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_teams (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    team_id                 TEXT            NOT NULL,
    group_id                TEXT            NULL,
    display_name            TEXT            NULL,
    description             TEXT            NULL,
    web_url                 TEXT            NULL,
    is_archived             BOOLEAN         NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, team_id)
);

COMMENT ON TABLE shp.sharepoint_teams IS 'Teams managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_team_channels (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    team_id                 TEXT            NOT NULL,
    channel_id              TEXT            NOT NULL,
    display_name            TEXT            NULL,
    description             TEXT            NULL,
    membership_type         TEXT            NULL,
    web_url                 TEXT            NULL,
    email                   TEXT            NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, team_id, channel_id)
);

COMMENT ON TABLE shp.sharepoint_team_channels IS 'Team channels managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_channel_members (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    team_id                 TEXT            NOT NULL,
    channel_id              TEXT            NOT NULL,
    membership_id           TEXT            NOT NULL,
    user_id                 TEXT            NULL,
    user_email              TEXT            NULL,
    user_display_name       TEXT            NULL,
    roles                   JSONB           NOT NULL DEFAULT '[]'::jsonb,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, team_id, channel_id, membership_id)
);

COMMENT ON TABLE shp.sharepoint_channel_members IS 'Channel members managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_channel_messages (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    team_id                 TEXT            NOT NULL,
    channel_id              TEXT            NOT NULL,
    message_id              TEXT            NOT NULL,
    from_id                 TEXT            NULL,
    from_display_name       TEXT            NULL,
    summary                 TEXT            NULL,
    content_type            TEXT            NULL,
    content                 TEXT            NULL,
    web_url                 TEXT            NULL,
    created_date_time       TIMESTAMPTZ     NULL,
    last_modified_date_time TIMESTAMPTZ     NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, team_id, channel_id, message_id)
);

COMMENT ON TABLE shp.sharepoint_channel_messages IS 'Channel messages managed by API';

CREATE TABLE IF NOT EXISTS shp.sharepoint_channel_files (
    id                      BIGSERIAL       PRIMARY KEY,
    tenant_id               TEXT            NOT NULL,
    team_id                 TEXT            NOT NULL,
    channel_id              TEXT            NOT NULL,
    file_id                 TEXT            NOT NULL,
    drive_id                TEXT            NULL,
    item_id                 TEXT            NULL,
    name                    TEXT            NULL,
    web_url                 TEXT            NULL,
    size_bytes              BIGINT          NULL,
    mime_type               TEXT            NULL,
    is_folder               BOOLEAN         NULL,
    created_date_time       TIMESTAMPTZ     NULL,
    last_modified_date_time TIMESTAMPTZ     NULL,
    raw_payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    last_seen_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, team_id, channel_id, file_id)
);

COMMENT ON TABLE shp.sharepoint_channel_files IS 'Files exposed in channel content managed by API';

-- ================================================================
-- INDEXES
-- ================================================================

-- export_runs
CREATE INDEX IF NOT EXISTS ix_er_tenant_started
    ON shp.export_runs (tenant_id, started_at DESC);

CREATE INDEX IF NOT EXISTS ix_er_source_status
    ON shp.export_runs (source, status);

-- resources
CREATE INDEX IF NOT EXISTS ix_res_run_type
    ON shp.resources (export_run_id, resource_type);

CREATE INDEX IF NOT EXISTS ix_res_site_drive_item
    ON shp.resources (site_id, drive_id, item_id);

CREATE INDEX IF NOT EXISTS ix_res_tenant_type
    ON shp.resources (tenant_id, resource_type);

CREATE INDEX IF NOT EXISTS ix_res_resource_id
    ON shp.resources (resource_id);

CREATE INDEX IF NOT EXISTS ix_res_payload_gin
    ON shp.resources USING GIN (payload);

-- permissions
CREATE INDEX IF NOT EXISTS ix_perm_run_type
    ON shp.permissions (export_run_id, resource_type);

CREATE INDEX IF NOT EXISTS ix_perm_email
    ON shp.permissions (principal_email);

CREATE INDEX IF NOT EXISTS ix_perm_drive_item
    ON shp.permissions (drive_id, item_id);

CREATE INDEX IF NOT EXISTS ix_perm_tenant_type
    ON shp.permissions (tenant_id, resource_type);

CREATE INDEX IF NOT EXISTS ix_perm_roles_gin
    ON shp.permissions USING GIN (roles);

CREATE INDEX IF NOT EXISTS ix_perm_raw_gin
    ON shp.permissions USING GIN (raw_payload);

-- operations
CREATE INDEX IF NOT EXISTS ix_ops_tenant_type
    ON shp.operations (tenant_id, operation_type);

CREATE INDEX IF NOT EXISTS ix_ops_status_started
    ON shp.operations (status, started_at DESC);

-- audit_events
CREATE INDEX IF NOT EXISTS ix_audit_tenant_type
    ON shp.audit_events (tenant_id, event_type);

CREATE INDEX IF NOT EXISTS ix_audit_occurred
    ON shp.audit_events (occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_audit_operation
    ON shp.audit_events (operation_id);

CREATE INDEX IF NOT EXISTS ix_audit_export_run
    ON shp.audit_events (export_run_id);

-- governance_packages
CREATE INDEX IF NOT EXISTS ix_gov_tenant_type
    ON shp.governance_packages (tenant_id, package_type);

CREATE INDEX IF NOT EXISTS ix_gov_operation
    ON shp.governance_packages (operation_id);

-- frontend_commands
CREATE INDEX IF NOT EXISTS ix_fc_tenant_created
    ON shp.frontend_commands (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_fc_type_status
    ON shp.frontend_commands (command_type, response_status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_fc_surface
    ON shp.frontend_commands (client_surface, created_at DESC);

-- dedicated sharepoint resources
CREATE INDEX IF NOT EXISTS ix_sps_tenant_site
    ON shp.sharepoint_sites (tenant_id, site_id);

CREATE INDEX IF NOT EXISTS ix_sps_hostname
    ON shp.sharepoint_sites (hostname);

CREATE INDEX IF NOT EXISTS ix_spd_tenant_drive
    ON shp.sharepoint_drives (tenant_id, drive_id);

CREATE INDEX IF NOT EXISTS ix_spd_site
    ON shp.sharepoint_drives (site_id);

CREATE INDEX IF NOT EXISTS ix_spl_site
    ON shp.sharepoint_libraries (tenant_id, site_id);

CREATE INDEX IF NOT EXISTS ix_spl_drive
    ON shp.sharepoint_libraries (drive_id);

CREATE INDEX IF NOT EXISTS ix_spi_drive_item
    ON shp.sharepoint_drive_items (tenant_id, drive_id, item_id);

CREATE INDEX IF NOT EXISTS ix_spi_parent
    ON shp.sharepoint_drive_items (tenant_id, drive_id, parent_item_id);

CREATE INDEX IF NOT EXISTS ix_spip_item
    ON shp.sharepoint_item_permissions (tenant_id, drive_id, item_id);

CREATE INDEX IF NOT EXISTS ix_spip_email
    ON shp.sharepoint_item_permissions (principal_email);

CREATE INDEX IF NOT EXISTS ix_spg_group
    ON shp.sharepoint_groups (tenant_id, group_id);

CREATE INDEX IF NOT EXISTS ix_spgm_group
    ON shp.sharepoint_group_members (tenant_id, group_id);

CREATE INDEX IF NOT EXISTS ix_spu_user
    ON shp.sharepoint_users (tenant_id, user_id);

CREATE INDEX IF NOT EXISTS ix_spu_upn
    ON shp.sharepoint_users (user_principal_name);

CREATE INDEX IF NOT EXISTS ix_spul_user
    ON shp.sharepoint_user_licenses (tenant_id, user_id);

CREATE INDEX IF NOT EXISTS ix_spt_team
    ON shp.sharepoint_teams (tenant_id, team_id);

CREATE INDEX IF NOT EXISTS ix_sptc_team_channel
    ON shp.sharepoint_team_channels (tenant_id, team_id, channel_id);

CREATE INDEX IF NOT EXISTS ix_spcm_channel
    ON shp.sharepoint_channel_members (tenant_id, team_id, channel_id);

CREATE INDEX IF NOT EXISTS ix_spmsg_channel
    ON shp.sharepoint_channel_messages (tenant_id, team_id, channel_id, created_date_time DESC);

CREATE INDEX IF NOT EXISTS ix_spcf_channel
    ON shp.sharepoint_channel_files (tenant_id, team_id, channel_id);

-- ================================================================
-- GRANTS FOR APPLICATION USER (shp_app_user)
-- ================================================================

GRANT USAGE ON SCHEMA shp TO shp_app_user;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA shp
    TO shp_app_user;

GRANT USAGE, SELECT
    ON ALL SEQUENCES IN SCHEMA shp
    TO shp_app_user;

-- Ensure future objects also get the same grants
ALTER DEFAULT PRIVILEGES IN SCHEMA shp
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO shp_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA shp
    GRANT USAGE, SELECT ON SEQUENCES TO shp_app_user;

-- ================================================================
-- VERIFICATION
-- ================================================================

DO $$
DECLARE
    tbl_count INTEGER;
    idx_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO tbl_count
    FROM information_schema.tables
    WHERE table_schema = 'shp';

    SELECT COUNT(*) INTO idx_count
    FROM pg_indexes
    WHERE schemaname = 'shp';

    RAISE NOTICE 'Setup complete: % tables, % indexes created in schema shp.', tbl_count, idx_count;
END$$;
