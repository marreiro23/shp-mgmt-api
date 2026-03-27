import frontendCommandService from '../services/frontendCommandService.js';

function classifyCommand(req) {
  const method = String(req.method || '').toUpperCase();
  const path = String(req.path || '').toLowerCase();

  if (method === 'GET' && (path === '/export' || path.includes('/compare/export') || path.includes('/admin-governance/export/package'))) {
    return 'export';
  }

  if (method === 'POST' && path.includes('/import')) {
    return 'import';
  }

  if (method === 'POST' && path.includes('/update')) {
    return 'update';
  }

  if (method === 'PATCH') {
    return 'update';
  }

  if (method === 'POST') {
    return 'create';
  }

  return null;
}

export default function frontendCommandLogger(req, res, next) {
  const surface = String(req.headers['x-client-surface'] || '').trim().toLowerCase();
  const commandType = classifyCommand(req);

  if (!surface || !commandType) {
    return next();
  }

  const startedAt = Date.now();
  const requestPath = req.path;
  const method = req.method;
  const query = req.query || {};
  const body = req.body || {};
  const actor = req.headers['x-actor'] || 'web-user';

  res.on('finish', () => {
    frontendCommandService
      .appendCommand({
        surface,
        commandType,
        method,
        path: requestPath,
        query,
        body,
        statusCode: res.statusCode,
        success: res.statusCode < 400,
        correlationId: String(res.getHeader('x-correlation-id') || ''),
        actor,
        durationMs: Date.now() - startedAt,
        response: {
          statusCode: res.statusCode
        }
      })
      .catch((err) => {
        console.error('[frontendCommandLogger] failed to persist command:', err.message);
      });
  });

  return next();
}
