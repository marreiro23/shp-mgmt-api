import resourceSyncService from '../services/resourceSyncService.js';
import pgService from '../services/pgService.js';

/**
 * Sync controller - manual sync endpoints
 */

function sendError(res, req, error, fallbackMessage) {
  const correlationId = req.headers['x-correlation-id'] || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  res.setHeader('x-correlation-id', correlationId);

  return res.status(error.status || 500).json({
    success: false,
    correlationId,
    error: {
      code: error.code || `SYNC_${error.status || 500}`,
      message: fallbackMessage
    }
  });
}

/**
 * GET /sync/status
 * Returns the current sync status
 */
export async function getSyncStatus(req, res) {
  try {
    const status = resourceSyncService.getStatus();
    const lastSync = resourceSyncService.getLastSyncTS();

    return res.json({
      success: true,
      sync: {
        running: status.isRunning,
        lastSyncAt: lastSync ? lastSync.toISOString() : null,
        intervalMs: status.syncIntervalMs
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao obter status de sincronização.');
  }
}

/**
 * POST /sync/run-full
 * Manually trigger a full sync (sites, users, groups, teams)
 */
export async function runFullSync(req, res) {
  try {
    if (!pgService.isAvailable()) {
      return res.status(503).json({
        success: false,
        error: {
          code: 'DB_UNAVAILABLE',
          message: 'Base de dados não está disponível.'
        }
      });
    }

    const startTime = Date.now();
    
    // Schedule the sync to run asynchronously
    resourceSyncService.runFullSync().catch(err => {
      console.error('[SyncController] Error during async full sync:', err.message);
    });

    return res.json({
      success: true,
      message: 'Sincronização completa iniciada.',
      syncStartedAt: new Date().toISOString()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar sincronização completa.');
  }
}

/**
 * POST /sync/run-sites
 * Manually trigger sites sync only
 */
export async function runSitesSync(req, res) {
  try {
    if (!pgService.isAvailable()) {
      return res.status(503).json({
        success: false,
        error: { code: 'DB_UNAVAILABLE', message: 'Base de dados não está disponível.' }
      });
    }

    resourceSyncService.syncSites().catch(err => {
      console.error('[SyncController] Error during async sites sync:', err.message);
    });

    return res.json({
      success: true,
      message: 'Sincronização de sites iniciada.',
      syncStartedAt: new Date().toISOString()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar sincronização de sites.');
  }
}

/**
 * POST /sync/run-users
 * Manually trigger users sync only
 */
export async function runUsersSync(req, res) {
  try {
    if (!pgService.isAvailable()) {
      return res.status(503).json({
        success: false,
        error: { code: 'DB_UNAVAILABLE', message: 'Base de dados não está disponível.' }
      });
    }

    resourceSyncService.syncUsers().catch(err => {
      console.error('[SyncController] Error during async users sync:', err.message);
    });

    return res.json({
      success: true,
      message: 'Sincronização de usuários iniciada.',
      syncStartedAt: new Date().toISOString()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar sincronização de usuários.');
  }
}

/**
 * POST /sync/run-groups
 * Manually trigger groups sync only
 */
export async function runGroupsSync(req, res) {
  try {
    if (!pgService.isAvailable()) {
      return res.status(503).json({
        success: false,
        error: { code: 'DB_UNAVAILABLE', message: 'Base de dados não está disponível.' }
      });
    }

    resourceSyncService.syncGroups().catch(err => {
      console.error('[SyncController] Error during async groups sync:', err.message);
    });

    return res.json({
      success: true,
      message: 'Sincronização de grupos iniciada.',
      syncStartedAt: new Date().toISOString()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar sincronização de grupos.');
  }
}

/**
 * POST /sync/run-teams
 * Manually trigger teams sync only
 */
export async function runTeamsSync(req, res) {
  try {
    if (!pgService.isAvailable()) {
      return res.status(503).json({
        success: false,
        error: { code: 'DB_UNAVAILABLE', message: 'Base de dados não está disponível.' }
      });
    }

    resourceSyncService.syncTeams().catch(err => {
      console.error('[SyncController] Error during async teams sync:', err.message);
    });

    return res.json({
      success: true,
      message: 'Sincronização de times iniciada.',
      syncStartedAt: new Date().toISOString()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar sincronização de times.');
  }
}

/**
 * POST /sync/run-drives-and-libraries
 * Sync all drives and libraries for all sites
 */
export async function runDrivesAndLibrariesSync(req, res) {
  try {
    if (!pgService.isAvailable()) {
      return res.status(503).json({
        success: false,
        error: { code: 'DB_UNAVAILABLE', message: 'Base de dados não está disponível.' }
      });
    }

    resourceSyncService.syncAllDrivesAndLibraries().catch(err => {
      console.error('[SyncController] Error during async drives/libraries sync:', err.message);
    });

    return res.json({
      success: true,
      message: 'Sincronização de drives e bibliotecas iniciada.',
      syncStartedAt: new Date().toISOString()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar sincronização de drives/bibliotecas.');
  }
}
