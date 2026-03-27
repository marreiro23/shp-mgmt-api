-- ================================================================
-- shp-mgmt-api :: Docker init script
-- Executed automatically on first postgres container start
-- (placed in /docker-entrypoint-initdb.d by docker-compose.yml)
--
-- Context: runs as POSTGRES_USER (postgres) against POSTGRES_DB (shp_mgmt_db)
-- ================================================================

\set ON_ERROR_STOP on

-- ----------------------------------------------------------------
-- Application role
-- ----------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'shp_app_user') THEN
        CREATE ROLE shp_app_user WITH LOGIN PASSWORD 'shp_app_pass';
        RAISE NOTICE 'Role shp_app_user created.';
    ELSE
        RAISE NOTICE 'Role shp_app_user already exists, skipping.';
    END IF;
END$$;

-- ----------------------------------------------------------------
-- SCHEMA
-- ----------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS shp;

COMMENT ON SCHEMA shp IS 'shp-mgmt-api: SharePoint tenant inventory and governance data';

-- ----------------------------------------------------------------
-- TABLE: shp.export_runs
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.export_runs (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    source          TEXT            NOT NULL,
    format          TEXT            NOT NULL DEFAULT 'json',
    started_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ     NULL,
    status          TEXT            NOT NULL DEFAULT 'running',
    row_count       INTEGER         NULL,
    summary         JSONB           NOT NULL DEFAULT '{}'::jsonb,
    metadata        JSONB           NOT NULL DEFAULT '{}'::jsonb
);

-- ----------------------------------------------------------------
-- TABLE: shp.resources
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.resources (
    id                  BIGSERIAL       PRIMARY KEY,
    export_run_id       BIGINT          NOT NULL REFERENCES shp.export_runs(id) ON DELETE CASCADE,
    tenant_id           TEXT            NOT NULL,
    resource_type       TEXT            NOT NULL,
    resource_id         TEXT            NOT NULL,
    parent_resource_id  TEXT            NULL,
    site_id             TEXT            NULL,
    drive_id            TEXT            NULL,
    item_id             TEXT            NULL,
    team_id             TEXT            NULL,
    channel_id          TEXT            NULL,
    display_name        TEXT            NULL,
    web_url             TEXT            NULL,
    email               TEXT            NULL,
    created_by_email    TEXT            NULL,
    last_modified_by_email TEXT         NULL,
    created_at          TIMESTAMPTZ     NULL,
    last_modified_at    TIMESTAMPTZ     NULL,
    size_bytes          BIGINT          NULL,
    is_folder           BOOLEAN         NULL,
    mime_type           TEXT            NULL,
    visibility          TEXT            NULL,
    payload             JSONB           NOT NULL DEFAULT '{}'::jsonb,
    exported_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- TABLE: shp.permissions
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.permissions (
    id                      BIGSERIAL       PRIMARY KEY,
    export_run_id           BIGINT          NOT NULL REFERENCES shp.export_runs(id) ON DELETE CASCADE,
    tenant_id               TEXT            NOT NULL,
    schema_version          TEXT            NOT NULL DEFAULT 'sharepoint-permission-v1',
    resource_type           TEXT            NOT NULL,
    resource_name           TEXT            NULL,
    site_id                 TEXT            NULL,
    drive_id                TEXT            NULL,
    item_id                 TEXT            NULL,
    team_id                 TEXT            NULL,
    channel_id              TEXT            NULL,
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
    exported_at             TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- TABLE: shp.operations
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.operations (
    id              TEXT            PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    operation_type  TEXT            NOT NULL,
    status          TEXT            NOT NULL DEFAULT 'pending',
    started_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ     NULL,
    progress        INTEGER         NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
    trigger_user    TEXT            NULL,
    summary         JSONB           NOT NULL DEFAULT '{}'::jsonb,
    result          JSONB           NULL,
    error           JSONB           NULL
);

-- ----------------------------------------------------------------
-- TABLE: shp.audit_events
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.audit_events (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    event_type      TEXT            NOT NULL,
    actor           TEXT            NULL,
    resource_type   TEXT            NULL,
    resource_id     TEXT            NULL,
    site_id         TEXT            NULL,
    drive_id        TEXT            NULL,
    operation_id    TEXT            NULL REFERENCES shp.operations(id) ON DELETE SET NULL,
    export_run_id   BIGINT          NULL REFERENCES shp.export_runs(id) ON DELETE SET NULL,
    status          TEXT            NOT NULL DEFAULT 'success',
    detail          JSONB           NOT NULL DEFAULT '{}'::jsonb,
    occurred_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- TABLE: shp.governance_packages
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shp.governance_packages (
    id              BIGSERIAL       PRIMARY KEY,
    tenant_id       TEXT            NOT NULL,
    package_type    TEXT            NOT NULL,
    direction       TEXT            NOT NULL,
    operation_id    TEXT            NULL REFERENCES shp.operations(id) ON DELETE SET NULL,
    dry_run         BOOLEAN         NOT NULL DEFAULT false,
    status          TEXT            NOT NULL DEFAULT 'pending',
    rows_total      INTEGER         NULL,
    rows_processed  INTEGER         NULL DEFAULT 0,
    rows_created    INTEGER         NULL DEFAULT 0,
    rows_updated    INTEGER         NULL DEFAULT 0,
    rows_skipped    INTEGER         NULL DEFAULT 0,
    rows_failed     INTEGER         NULL DEFAULT 0,
    payload         JSONB           NOT NULL DEFAULT '{}'::jsonb,
    error_detail    JSONB           NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ     NULL
);

-- ================================================================
-- INDEXES
-- ================================================================
CREATE INDEX IF NOT EXISTS ix_er_tenant_started   ON shp.export_runs     (tenant_id, started_at DESC);
CREATE INDEX IF NOT EXISTS ix_er_source_status    ON shp.export_runs     (source, status);
CREATE INDEX IF NOT EXISTS ix_res_run_type        ON shp.resources       (export_run_id, resource_type);
CREATE INDEX IF NOT EXISTS ix_res_site_drive_item ON shp.resources       (site_id, drive_id, item_id);
CREATE INDEX IF NOT EXISTS ix_res_tenant_type     ON shp.resources       (tenant_id, resource_type);
CREATE INDEX IF NOT EXISTS ix_res_resource_id     ON shp.resources       (resource_id);
CREATE INDEX IF NOT EXISTS ix_res_payload_gin     ON shp.resources       USING GIN (payload);
CREATE INDEX IF NOT EXISTS ix_perm_run_type       ON shp.permissions     (export_run_id, resource_type);
CREATE INDEX IF NOT EXISTS ix_perm_email          ON shp.permissions     (principal_email);
CREATE INDEX IF NOT EXISTS ix_perm_drive_item     ON shp.permissions     (drive_id, item_id);
CREATE INDEX IF NOT EXISTS ix_perm_tenant_type    ON shp.permissions     (tenant_id, resource_type);
CREATE INDEX IF NOT EXISTS ix_perm_roles_gin      ON shp.permissions     USING GIN (roles);
CREATE INDEX IF NOT EXISTS ix_perm_raw_gin        ON shp.permissions     USING GIN (raw_payload);
CREATE INDEX IF NOT EXISTS ix_ops_tenant_type     ON shp.operations      (tenant_id, operation_type);
CREATE INDEX IF NOT EXISTS ix_ops_status_started  ON shp.operations      (status, started_at DESC);
CREATE INDEX IF NOT EXISTS ix_audit_tenant_type   ON shp.audit_events    (tenant_id, event_type);
CREATE INDEX IF NOT EXISTS ix_audit_occurred      ON shp.audit_events    (occurred_at DESC);
CREATE INDEX IF NOT EXISTS ix_audit_operation     ON shp.audit_events    (operation_id);
CREATE INDEX IF NOT EXISTS ix_audit_export_run    ON shp.audit_events    (export_run_id);
CREATE INDEX IF NOT EXISTS ix_gov_tenant_type     ON shp.governance_packages (tenant_id, package_type);
CREATE INDEX IF NOT EXISTS ix_gov_operation       ON shp.governance_packages (operation_id);

-- ================================================================
-- GRANTS
-- ================================================================
GRANT USAGE ON SCHEMA shp TO shp_app_user;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA shp
    TO shp_app_user;

GRANT USAGE, SELECT
    ON ALL SEQUENCES IN SCHEMA shp
    TO shp_app_user;

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

    RAISE NOTICE 'Init complete: % tables, % indexes created in schema shp.', tbl_count, idx_count;
END$$;
