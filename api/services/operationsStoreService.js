import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
import pgService from './pgService.js';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const DB_PATH = resolve(__dirname, '..', 'data', 'operations', 'operations-db.json');

const DEFAULT_DB = {
  version: 1,
  createdAt: null,
  updatedAt: null,
  operations: {}
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
    operations: parsed?.operations || {}
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

function createOperationId() {
  return `op-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function _tenantId() {
  return process.env.AZURE_TENANT_ID || 'default';
}

function _mapRow(row) {
  return {
    id: row.id,
    type: row.operation_type,
    status: row.status,
    requestedBy: row.trigger_user || 'api',
    featureFlag: row.summary?.featureFlag ?? null,
    payload: row.summary?.payload ?? {},
    result: row.result ?? null,
    error: row.error ?? null,
    createdAt: row.started_at?.toISOString?.() ?? null,
    startedAt: row.started_at?.toISOString?.() ?? null,
    finishedAt: row.finished_at?.toISOString?.() ?? null,
    updatedAt: (row.finished_at ?? row.started_at)?.toISOString?.() ?? null
  };
}

class OperationsStoreService {
  createOperation(input = {}) {
    const db = readDb();
    const id = createOperationId();
    const operation = {
      id,
      type: input.type || 'generic',
      status: 'queued',
      requestedBy: input.requestedBy || 'api',
      featureFlag: input.featureFlag || null,
      payload: input.payload || {},
      result: null,
      error: null,
      createdAt: nowIso(),
      startedAt: null,
      finishedAt: null,
      updatedAt: nowIso()
    };

    db.operations[id] = operation;
    writeDb(db);
    // Persist to PostgreSQL (fire-and-forget — does not block the sync return)
    pgService
      .query(
        `INSERT INTO shp.operations (id, tenant_id, operation_type, status, trigger_user, summary, started_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (id) DO NOTHING`,
        [
          operation.id,
          _tenantId(),
          operation.type,
          operation.status,
          typeof operation.requestedBy === 'string' ? operation.requestedBy : JSON.stringify(operation.requestedBy),
          { featureFlag: operation.featureFlag, payload: operation.payload },
          operation.createdAt
        ]
      )
      .catch((err) => console.error('[operationsStore] PG insert failed:', err.message));

    return operation;
  }

  updateOperation(operationId, patch = {}) {
    const db = readDb();
    const current = db.operations[operationId];
    if (!current) return null;

    const next = {
      ...current,
      ...patch,
      updatedAt: nowIso()
    };

    db.operations[operationId] = next;
    writeDb(db);
    // Persist patch to PostgreSQL (fire-and-forget)
    pgService
      .query(
        `UPDATE shp.operations
         SET status=$2, result=$3, error=$4, finished_at=$5
         WHERE id=$1`,
        [
          operationId,
          next.status,
          next.result ?? null,
          next.error ?? null,
          next.finishedAt ?? null
        ]
      )
      .catch((err) => console.error('[operationsStore] PG update failed:', err.message));

    return next;
  }

  async getOperation(operationId) {
    // PG-primary read with file store fallback
    const result = await pgService.query('SELECT * FROM shp.operations WHERE id = $1', [operationId]);
    if (result?.rows?.[0]) return _mapRow(result.rows[0]);

    const db = readDb();
    return db.operations[operationId] || null;
  }
}

const operationsStoreService = new OperationsStoreService();

export default operationsStoreService;
