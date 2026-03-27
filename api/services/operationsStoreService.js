import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
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
    return next;
  }

  getOperation(operationId) {
    const db = readDb();
    return db.operations[operationId] || null;
  }
}

const operationsStoreService = new OperationsStoreService();

export default operationsStoreService;
