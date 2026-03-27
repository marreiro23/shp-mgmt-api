/**
 * pgService.js — PostgreSQL connection pool singleton
 *
 * Lazy-initialises a pg.Pool only when config.PG is set.
 * All callers receive null / false when PostgreSQL is not configured,
 * so the rest of the API continues to work without a database.
 *
 * Usage:
 *   import pgService from './pgService.js';
 *   await pgService.initialize();          // call once on startup
 *   const result = await pgService.query('SELECT 1');   // null if unavailable
 *   await pgService.close();               // graceful shutdown
 */

import pg from 'pg';
import config from '../config/config.js';

const { Pool } = pg;

let _pool = null;
let _connected = false;

/**
 * Returns the Pool instance (creating it on first call) or null when
 * PostgreSQL is not configured.
 */
function getPool() {
  if (!config.PG) return null;

  if (!_pool) {
    _pool = new Pool({
      host: config.PG.host,
      port: config.PG.port,
      database: config.PG.database,
      user: config.PG.user,
      password: config.PG.password,
      ssl: config.PG.ssl ? { rejectUnauthorized: false } : false,
      max: 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000
    });

    _pool.on('error', (err) => {
      console.error('[pgService] Unexpected pool error:', err.message);
      _connected = false;
    });
  }

  return _pool;
}

/**
 * Test the connection. Must be called once at application startup.
 * Returns true on success, false otherwise (does not throw).
 */
async function initialize() {
  const pool = getPool();
  if (!pool) {
    console.info('[pgService] PostgreSQL not configured — running without database.');
    return false;
  }

  try {
    await pool.query('SELECT 1');
    _connected = true;
    console.info(`[pgService] Connected to ${config.PG.database}@${config.PG.host}:${config.PG.port}`);
    return true;
  } catch (err) {
    _connected = false;
    console.error('[pgService] Connection failed:', err.message);
    return false;
  }
}

/**
 * Execute a parameterised query.
 * Returns the pg QueryResult or null when PostgreSQL is unavailable / query fails.
 * Never throws.
 */
async function query(text, params) {
  const pool = getPool();
  if (!pool) return null;

  try {
    return await pool.query(text, params);
  } catch (err) {
    console.error('[pgService] Query error:', err.message, '|', String(text).slice(0, 120));
    return null;
  }
}

/**
 * Gracefully end all pool connections.
 * Safe to call even if the pool was never initialised.
 */
async function close() {
  if (_pool) {
    await _pool.end();
    _pool = null;
    _connected = false;
    console.info('[pgService] Pool closed.');
  }
}

/**
 * Returns true only after a successful initialize() call.
 * Use this to gate pg-primary reads; fall back to file store when false.
 */
function isAvailable() {
  return _connected && !!_pool;
}

export default { getPool, initialize, query, close, isAvailable };
