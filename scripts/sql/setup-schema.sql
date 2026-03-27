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
