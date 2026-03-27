import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const DB_PATH = resolve(__dirname, '..', 'data', 'inventory', 'inventory-db.json');

const DEFAULT_DB = {
  version: 1,
  createdAt: null,
  updatedAt: null,
  sites: {},
  drives: {},
  libraries: {},
  files: {}
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
    sites: parsed?.sites || {},
    drives: parsed?.drives || {},
    libraries: parsed?.libraries || {},
    files: parsed?.files || {}
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

function upsertRecord(collection, id, record) {
  if (!id) return;
  collection[id] = {
    ...(collection[id] || {}),
    ...record,
    id,
    lastSeenAt: nowIso()
  };
}

function normalizeFileMetadata(file) {
  return {
    id: file.id,
    name: file.name || '',
    webUrl: file.webUrl || '',
    size: file.size || 0,
    createdDateTime: file.createdDateTime || null,
    lastModifiedDateTime: file.lastModifiedDateTime || null,
    eTag: file.eTag || null,
    cTag: file.cTag || null,
    file: file.file || null,
    folder: file.folder || null,
    parentReference: file.parentReference || null,
    createdBy: file.createdBy || null,
    lastModifiedBy: file.lastModifiedBy || null,
    shared: file.shared || null
  };
}

class InventoryDbService {
  getPath() {
    ensureDbFile();
    return DB_PATH;
  }

  getDatabase() {
    const db = readDb();
    return {
      path: DB_PATH,
      summary: {
        sites: Object.keys(db.sites).length,
        drives: Object.keys(db.drives).length,
        libraries: Object.keys(db.libraries).length,
        files: Object.keys(db.files).length,
        updatedAt: db.updatedAt
      },
      data: db
    };
  }

  recordSites(items = [], context = {}) {
    const db = readDb();
    for (const site of items) {
      upsertRecord(db.sites, site?.id, {
        ...site,
        inventoryContext: {
          search: context.search || '',
          top: context.top || 0
        }
      });
    }
    writeDb(db);
  }

  recordDrives(siteId, items = []) {
    const db = readDb();
    for (const drive of items) {
      upsertRecord(db.drives, drive?.id, {
        ...drive,
        siteId: siteId || drive?.siteId || null
      });
    }
    writeDb(db);
  }

  recordLibraries(siteId, items = []) {
    const db = readDb();
    for (const library of items) {
      upsertRecord(db.libraries, library?.id, {
        ...library,
        siteId: siteId || library?.siteId || null,
        driveId: library?.drive?.id || null
      });
    }
    writeDb(db);
  }

  recordFiles(driveId, items = [], context = {}) {
    const db = readDb();
    for (const file of items) {
      const fileId = file?.id;
      if (!fileId) continue;
      const key = `${driveId}:${fileId}`;
      upsertRecord(db.files, key, {
        key,
        driveId,
        ...normalizeFileMetadata(file),
        metadataContext: {
          path: context.path || '',
          source: context.source || ''
        }
      });
    }
    writeDb(db);
  }

  recordDrive(drive, siteId = null) {
    const db = readDb();
    upsertRecord(db.drives, drive?.id, {
      ...drive,
      siteId: siteId || drive?.siteId || null
    });
    writeDb(db);
  }

  recordLibrary(library, siteId = null) {
    const db = readDb();
    upsertRecord(db.libraries, library?.id, {
      ...library,
      siteId: siteId || library?.siteId || null,
      driveId: library?.drive?.id || null
    });

    if (library?.drive?.id) {
      upsertRecord(db.drives, library.drive.id, {
        ...library.drive,
        siteId: siteId || library?.siteId || null,
        sourceLibraryId: library.id
      });
    }

    writeDb(db);
  }
}

const inventoryDbService = new InventoryDbService();

export default inventoryDbService;
