import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import dotenv from 'dotenv';
import Joi from 'joi';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '..', '.env') });

const envSchema = Joi.object({
  PORT: Joi.number().port().default(3001),
  HOST: Joi.string().hostname().default('localhost'),
  NODE_ENV: Joi.string().valid('development', 'staging', 'production').default('development'),
  LOG_LEVEL: Joi.string().valid('error', 'warn', 'info', 'verbose', 'debug', 'silly').default('info'),
  CORS_ORIGINS: Joi.string().default('http://localhost:3000,http://localhost:3001,http://127.0.0.1:3000,http://127.0.0.1:3001'),
  RATE_LIMIT_WINDOW_MS: Joi.number().positive().default(15 * 60 * 1000),
  RATE_LIMIT_MAX_REQUESTS: Joi.number().positive().default(1000),
  API_PREFIX: Joi.string().default('/api/v1'),
  API_VERSION: Joi.string().default('3.0.0'),
  ENABLE_ADMIN_SCRIPT_EXECUTION: Joi.boolean().truthy('true').falsy('false').default(false),
  ADMIN_SCRIPT_TIMEOUT_MS: Joi.number().positive().default(120000),
  POWERSHELL_EXECUTABLE: Joi.string().default('pwsh'),
  FEATURE_FLAGS: Joi.string().default('governance-import-export,governance-compare,audit-trail'),

  // PostgreSQL — all optional; API runs without them (in-memory fallback)
  PG_HOST: Joi.string().hostname().optional(),
  PG_PORT: Joi.number().port().default(5432),
  PG_DATABASE: Joi.string().optional(),
  PG_USER: Joi.string().optional(),
  PG_PASSWORD: Joi.string().allow('').optional(),
  PG_SSL: Joi.boolean().truthy('true').falsy('false').default(false),
  PG_SCHEMA: Joi.string().default('shp')
}).unknown(true);

const { value } = envSchema.validate(process.env, { abortEarly: false, allowUnknown: true });

const config = {
  PORT: Number(value.PORT),
  HOST: value.HOST,
  NODE_ENV: value.NODE_ENV,
  API_PREFIX: value.API_PREFIX,
  API_VERSION: value.API_VERSION,
  LOG_LEVEL: value.LOG_LEVEL,
  LOG_TO_FILE: true,
  RATE_LIMIT_WINDOW_MS: Number(value.RATE_LIMIT_WINDOW_MS),
  RATE_LIMIT_MAX_REQUESTS: Number(value.RATE_LIMIT_MAX_REQUESTS),
  ENABLE_ADMIN_SCRIPT_EXECUTION: Boolean(value.ENABLE_ADMIN_SCRIPT_EXECUTION),
  ADMIN_SCRIPT_TIMEOUT_MS: Number(value.ADMIN_SCRIPT_TIMEOUT_MS),
  POWERSHELL_EXECUTABLE: value.POWERSHELL_EXECUTABLE,
  FEATURE_FLAGS: String(value.FEATURE_FLAGS)
    .split(',')
    .map((flag) => flag.trim())
    .filter(Boolean),
  CORS_ORIGINS: String(value.CORS_ORIGINS)
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),

  // PostgreSQL connection (optional — API works without it)
  PG: value.PG_HOST
    ? {
        host: value.PG_HOST,
        port: Number(value.PG_PORT),
        database: value.PG_DATABASE,
        user: value.PG_USER,
        password: value.PG_PASSWORD || undefined,
        ssl: Boolean(value.PG_SSL),
        schema: value.PG_SCHEMA
      }
    : null
};

export default config;
