import pgService from './pgService.js';

function tenantId() {
  return process.env.AZURE_TENANT_ID || 'default';
}

function sanitizeValue(value, depth = 0) {
  if (value === null || value === undefined) return null;
  if (depth > 4) return '[depth-limit]';

  if (typeof value === 'string') {
    return value.length > 500 ? `${value.slice(0, 500)}...[truncated]` : value;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (Array.isArray(value)) {
    return value.slice(0, 30).map((item) => sanitizeValue(item, depth + 1));
  }

  if (typeof value === 'object') {
    const sensitivePattern = /password|secret|token|authorization|content/i;
    const entries = Object.entries(value).slice(0, 40);
    const normalized = {};

    for (const [key, entryValue] of entries) {
      if (sensitivePattern.test(key)) {
        normalized[key] = '[redacted]';
      } else {
        normalized[key] = sanitizeValue(entryValue, depth + 1);
      }
    }

    return normalized;
  }

  return String(value);
}

function mapCommandRow(row) {
  return {
    id: row.id,
    commandType: row.command_type,
    method: row.http_method,
    path: row.request_path,
    surface: row.client_surface,
    statusCode: row.response_status,
    success: row.success,
    correlationId: row.correlation_id,
    actor: row.actor,
    durationMs: row.duration_ms,
    query: row.query_params || {},
    body: row.request_body || {},
    response: row.response_summary || {},
    createdAt: row.created_at?.toISOString?.() || null
  };
}

class FrontendCommandService {
  async appendCommand(command) {
    if (!pgService.isAvailable()) return null;

    return pgService.query(
      `INSERT INTO shp.frontend_commands
         (tenant_id, client_surface, command_type, http_method, request_path, query_params, request_body,
          response_status, success, correlation_id, actor, duration_ms, response_summary)
       VALUES
         ($1, $2, $3, $4, $5, $6, $7,
          $8, $9, $10, $11, $12, $13)
       RETURNING id`,
      [
        tenantId(),
        command.surface || 'unknown',
        command.commandType || 'unknown',
        command.method || 'GET',
        command.path || '/',
        sanitizeValue(command.query || {}),
        sanitizeValue(command.body || {}),
        Number(command.statusCode || 0),
        Boolean(command.success),
        command.correlationId || null,
        command.actor || 'web',
        Number(command.durationMs || 0),
        sanitizeValue(command.response || {})
      ]
    );
  }

  async listCommands(filters = {}) {
    if (!pgService.isAvailable()) {
      return { total: 0, limit: 50, offset: 0, items: [] };
    }

    const whereParts = ['tenant_id = $1'];
    const params = [tenantId()];

    if (filters.commandType) {
      params.push(String(filters.commandType).toLowerCase());
      whereParts.push(`LOWER(command_type) = $${params.length}`);
    }

    if (filters.surface) {
      params.push(String(filters.surface).toLowerCase());
      whereParts.push(`LOWER(client_surface) = $${params.length}`);
    }

    if (filters.pathContains) {
      params.push(`%${String(filters.pathContains).toLowerCase()}%`);
      whereParts.push(`LOWER(request_path) LIKE $${params.length}`);
    }

    if (Number.isFinite(filters.statusCode)) {
      params.push(Number(filters.statusCode));
      whereParts.push(`response_status = $${params.length}`);
    }

    const whereClause = whereParts.join(' AND ');
    const limit = Number.isFinite(filters.limit) && filters.limit > 0 ? Math.min(filters.limit, 200) : 50;
    const offset = Number.isFinite(filters.offset) && filters.offset >= 0 ? filters.offset : 0;

    const countResult = await pgService.query(
      `SELECT COUNT(*) AS total
         FROM shp.frontend_commands
        WHERE ${whereClause}`,
      params
    );

    const total = parseInt(countResult?.rows?.[0]?.total ?? '0', 10);

    const rowsResult = await pgService.query(
      `SELECT id, command_type, http_method, request_path, client_surface, response_status, success,
              correlation_id, actor, duration_ms, query_params, request_body, response_summary, created_at
         FROM shp.frontend_commands
        WHERE ${whereClause}
        ORDER BY created_at DESC
        LIMIT ${limit}
       OFFSET ${offset}`,
      params
    );

    return {
      total,
      limit,
      offset,
      items: Array.isArray(rowsResult?.rows) ? rowsResult.rows.map(mapCommandRow) : []
    };
  }
}

const frontendCommandService = new FrontendCommandService();

export default frontendCommandService;
