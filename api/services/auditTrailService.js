import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
import pgService from './pgService.js';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const DB_PATH = resolve(__dirname, '..', 'data', 'audit', 'audit-events.json');

const DEFAULT_DB = {
  version: 1,
  createdAt: null,
  updatedAt: null,
  events: []
};

function nowIso() {
  return new Date().toISOString();
}

function ensureDbFile() {
  const folder = dirname(DB_PATH);
  if (!existsSync(folder)) {
    mkdirSync(folder, { recursive: true });
  }

  if (!existsSync(DB_PATH)) {
    const initial = {
      ...DEFAULT_DB,
      createdAt: nowIso(),
      updatedAt: nowIso()
    };
    writeFileSync(DB_PATH, `${JSON.stringify(initial, null, 2)}\n`, 'utf8');
  }
}

function readDb() {
  ensureDbFile();
  const raw = readFileSync(DB_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  return {
    ...DEFAULT_DB,
    ...parsed,
    events: Array.isArray(parsed?.events) ? parsed.events : []
  };
}

function writeDb(db) {
  const persisted = {
    ...db,
    updatedAt: nowIso(),
    createdAt: db.createdAt || nowIso()
  };

  writeFileSync(DB_PATH, `${JSON.stringify(persisted, null, 2)}\n`, 'utf8');
  return persisted;
}

function createEventId() {
  return `audit-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function _tenantId() {
  return process.env.AZURE_TENANT_ID || 'default';
}

class AuditTrailService {
  appendEvent(eventInput = {}) {
    const db = readDb();
    const event = {
      id: createEventId(),
      timestamp: nowIso(),
      action: eventInput.action || 'unknown',
      status: eventInput.status || 'info',
      operationId: eventInput.operationId || null,
      targetType: eventInput.targetType || null,
      targetId: eventInput.targetId || null,
      correlationId: eventInput.correlationId || null,
      actor: eventInput.actor || 'api',
      details: eventInput.details || {}
    };

    db.events.push(event);
    writeDb(db);
    // Persist to PostgreSQL (fire-and-forget)
    pgService
      .query(
        `INSERT INTO shp.audit_events
           (tenant_id, event_type, actor, resource_type, resource_id, operation_id, status, detail, occurred_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          _tenantId(),
          event.action,
          typeof event.actor === 'string' ? event.actor : JSON.stringify(event.actor),
          event.targetType ?? null,
          event.targetId ?? null,
          event.operationId ?? null,
          event.status,
          event,
          event.timestamp
        ]
      )
      .catch((err) => console.error('[auditTrail] PG insert failed:', err.message));

    return event;
  }

  async listEvents(query = {}) {
    // PG-primary: build parameterised query and fall back to file store on failure
    if (pgService.isAvailable()) {
      const tenantId = _tenantId();
      const filters = [];
      const params = [tenantId];

      if (query.action) {
        params.push(String(query.action).toLowerCase());
        filters.push(`LOWER(event_type) = $${params.length}`);
      }
      if (query.status) {
        params.push(String(query.status).toLowerCase());
        filters.push(`LOWER(status) = $${params.length}`);
      }
      if (query.operationId) {
        params.push(query.operationId);
        filters.push(`operation_id = $${params.length}`);
      }
      if (query.correlationId) {
        params.push(query.correlationId);
        filters.push(`detail->>'correlationId' = $${params.length}`);
      }

      const where = filters.length > 0 ? `AND ${filters.join(' AND ')}` : '';
      const limit = Number.isFinite(query.limit) && query.limit > 0 ? Math.min(query.limit, 1000) : 50;
      const offset = Number.isFinite(query.offset) && query.offset >= 0 ? query.offset : 0;

      // COUNT query to get total matching rows
      const countResult = await pgService.query(
        `SELECT COUNT(*) AS total FROM shp.audit_events WHERE tenant_id = $1 ${where}`,
        params
      );
      const total = parseInt(countResult?.rows?.[0]?.total ?? '0', 10);

      const rowsResult = await pgService.query(
        `SELECT detail FROM shp.audit_events WHERE tenant_id = $1 ${where}
         ORDER BY occurred_at DESC LIMIT ${limit} OFFSET ${offset}`,
        params
      );

      if (rowsResult?.rows) {
        return {
          total,
          limit,
          offset,
          items: rowsResult.rows.map((r) => r.detail)
        };
      }
    }

    // File-store fallback
    const db = readDb();
    let rows = [...db.events].reverse();

    if (query.action) {
      rows = rows.filter((event) => String(event.action || '').toLowerCase() === String(query.action).toLowerCase());
    }

    if (query.status) {
      rows = rows.filter((event) => String(event.status || '').toLowerCase() === String(query.status).toLowerCase());
    }

    if (query.operationId) {
      rows = rows.filter((event) => event.operationId === query.operationId);
    }

    if (query.correlationId) {
      rows = rows.filter((event) => event.correlationId === query.correlationId);
    }

    const limit = Number.isFinite(query.limit) && query.limit > 0 ? query.limit : 50;
    const offset = Number.isFinite(query.offset) && query.offset >= 0 ? query.offset : 0;
    return {
      total: rows.length,
      limit,
      offset,
      items: rows.slice(offset, offset + limit)
    };
  }
}

const auditTrailService = new AuditTrailService();

export default auditTrailService;
