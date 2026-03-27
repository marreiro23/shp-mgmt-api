import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
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
    return event;
  }

  listEvents(query = {}) {
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
