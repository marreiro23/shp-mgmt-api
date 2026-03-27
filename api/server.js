import express from 'express';
import helmet from 'helmet';
import { existsSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

import config from './config/config.js';
import corsMiddleware from './middleware/cors.js';
import { consoleLogger, customLogger } from './middleware/logger.js';
import rateLimiter from './middleware/rateLimiter.js';
import sharepointRoutes from './routes/sharepoint.routes.js';
import pgService from './services/pgService.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const isMainModule = process.argv[1] && resolve(process.argv[1]) === __filename;

function createCorrelationId(req) {
  return req.headers['x-correlation-id'] || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function resolveStaticDir(candidates) {
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return candidates[0];
}

function createApp() {
  const app = express();

  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'", 'http://localhost:3000', 'http://localhost:3001'],
        objectSrc: ["'none'"],
        frameSrc: ["'none'"]
      }
    }
  }));

  app.use(corsMiddleware);
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  if (config.NODE_ENV === 'development') {
    app.use(consoleLogger);
  }

  app.use(customLogger);
  app.use('/api', rateLimiter);

  const webDir = resolveStaticDir([
    join(__dirname, '..', 'web'),
    join(__dirname, 'web')
  ]);
  app.use('/web', express.static(webDir));

  app.get('/', (req, res) => {
    res.json({
      success: true,
      name: 'shp-mgmt-api',
      version: config.API_VERSION || '3.0.0',
      scope: 'Microsoft Graph para SharePoint Online',
      endpoints: {
        health: '/health',
        config: `${config.API_PREFIX}/config`,
        sharepointConfig: `${config.API_PREFIX}/sharepoint/config`,
        sharepointAuthenticate: `${config.API_PREFIX}/sharepoint/authenticate`,
        sharepointInventoryDatabase: `${config.API_PREFIX}/sharepoint/inventory/database`,
        sharepointSites: `${config.API_PREFIX}/sharepoint/sites`,
        sharepointGroups: `${config.API_PREFIX}/sharepoint/groups`,
        sharepointUsers: `${config.API_PREFIX}/sharepoint/users`,
        sharepointUserLicenses: `${config.API_PREFIX}/sharepoint/users/:userId/licenses`,
        sharepointDrives: `${config.API_PREFIX}/sharepoint/sites/:siteId/drives`,
        sharepointCreateDrive: `${config.API_PREFIX}/sharepoint/sites/:siteId/drives`,
        sharepointLibraries: `${config.API_PREFIX}/sharepoint/sites/:siteId/libraries`,
        sharepointCreateLibrary: `${config.API_PREFIX}/sharepoint/sites/:siteId/libraries`,
        sharepointUpdateLibrary: `${config.API_PREFIX}/sharepoint/sites/:siteId/libraries/:listId`,
        sharepointChildren: `${config.API_PREFIX}/sharepoint/drives/:driveId/children`,
        sharepointUpdateDrive: `${config.API_PREFIX}/sharepoint/drives/:driveId`,
        sharepointFilesMetadata: `${config.API_PREFIX}/sharepoint/drives/:driveId/files-metadata`,
        sharepointItemPermissions: `${config.API_PREFIX}/sharepoint/drives/:driveId/items/:itemId/permissions`,
        sharepointExport: `${config.API_PREFIX}/sharepoint/export?source=drive-files&format=csv`,
        teamsChannels: `${config.API_PREFIX}/sharepoint/teams/:teamId/channels`,
        teamsCreateChannel: `${config.API_PREFIX}/sharepoint/teams/:teamId/channels`,
        teamsUpdateChannel: `${config.API_PREFIX}/sharepoint/teams/:teamId/channels/:channelId`,
        teamsChannelMembersList: `${config.API_PREFIX}/sharepoint/teams/:teamId/channels/:channelId/members`,
        teamsChannelContent: `${config.API_PREFIX}/sharepoint/teams/:teamId/channels/:channelId/content`,
        teamsChannelMembers: `${config.API_PREFIX}/sharepoint/teams/:teamId/channels/:channelId/members`,
        entraGroupMembers: `${config.API_PREFIX}/sharepoint/groups/:groupId/members`,
        adminAppRegistration: `${config.API_PREFIX}/sharepoint/admin/app-registration`,
        adminUpdateScopes: `${config.API_PREFIX}/sharepoint/admin/update-scopes`,
        governanceExportPackage: `${config.API_PREFIX}/sharepoint/admin-governance/export/package`,
        governanceImportPreview: `${config.API_PREFIX}/sharepoint/admin-governance/import/preview`,
        governanceImportExecute: `${config.API_PREFIX}/sharepoint/admin-governance/import/execute`,
        governanceImportPermissionsPackage: `${config.API_PREFIX}/sharepoint/admin-governance/import/permissions-package`,
        governanceComparePreview: `${config.API_PREFIX}/sharepoint/admin-governance/compare/preview`,
        governanceCompareExecute: `${config.API_PREFIX}/sharepoint/admin-governance/compare/execute`,
        governanceCompareExport: `${config.API_PREFIX}/sharepoint/admin-governance/compare/export?operationId=<id>&format=csv`,
        operationStatus: `${config.API_PREFIX}/sharepoint/operations/:operationId`,
        auditEvents: `${config.API_PREFIX}/sharepoint/audit/events`,
        frontendCommands: `${config.API_PREFIX}/sharepoint/frontend-commands`
      },
      web: {
        home: '/web/operations-center.html',
        legacyHome: '/web/index.html',
        operationsCenter: '/web/operations-center.html',
        operations: '/web/operations.html',
        collaboration: '/web/collaboration.html',
        admin: '/web/admin.html'
      }
    });
  });

  app.get('/health', (req, res) => {
    res.json({
      success: true,
      status: 'OK',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.NODE_ENV,
      database: {
        configured: !!config.PG,
        connected: pgService.isAvailable(),
        host: config.PG?.host ?? null,
        name: config.PG?.database ?? null
      }
    });
  });

  app.get(`${config.API_PREFIX}/config`, (req, res) => {
    res.json({
      success: true,
      data: {
        APPLICATION: {
          name: 'shp-mgmt-api',
          version: config.API_VERSION || '3.0.0'
        },
        api: {
          prefix: config.API_PREFIX,
          port: config.PORT,
          host: config.HOST
        },
        features: {
          sharepointGraph: true,
          legacyModulesEnabled: false
        }
      }
    });
  });

  app.use(`${config.API_PREFIX}/sharepoint`, sharepointRoutes);

  app.use((req, res) => {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);
    res.status(404).json({
      success: false,
      correlationId,
      error: {
        code: 'SP_404',
        message: 'Endpoint nao encontrado.'
      }
    });
  });

  app.use((err, req, res, next) => {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);
    res.status(err.status || 500).json({
      success: false,
      correlationId,
      error: {
        code: err.code || `SP_${err.status || 500}`,
        message: err.publicMessage || 'Erro interno do servidor.'
      }
    });
  });

  return app;
}

const app = createApp();

const PORT = config.PORT;
const HOST = config.HOST;

if (isMainModule) {
  const server = app.listen(PORT, HOST, async () => {
    console.log(`shp-mgmt-api em http://${HOST}:${PORT}`);
    await pgService.initialize();
  });

  async function gracefulShutdown(signal) {
    console.log(`[server] ${signal} received — shutting down gracefully...`);
    server.close(async () => {
      await pgService.close();
      process.exit(0);
    });
    // Force exit after 10 s if connections linger
    setTimeout(() => process.exit(1), 10_000).unref();
  }

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

export default app;
export { createApp };
