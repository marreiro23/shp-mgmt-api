import express from 'express';
import {
  getSyncStatus,
  runFullSync,
  runSitesSync,
  runUsersSync,
  runGroupsSync,
  runTeamsSync,
  runDrivesAndLibrariesSync
} from '../controllers/syncController.js';

const router = express.Router();

/**
 * Sync endpoints for manual resource synchronization
 * These endpoints trigger async syncs to populate the database
 */

// GET /api/v1/sharepoint/sync/status
router.get('/status', getSyncStatus);

// POST /api/v1/sharepoint/sync/run-full
router.post('/run-full', runFullSync);

// POST /api/v1/sharepoint/sync/run-sites
router.post('/run-sites', runSitesSync);

// POST /api/v1/sharepoint/sync/run-users
router.post('/run-users', runUsersSync);

// POST /api/v1/sharepoint/sync/run-groups
router.post('/run-groups', runGroupsSync);

// POST /api/v1/sharepoint/sync/run-teams
router.post('/run-teams', runTeamsSync);

// POST /api/v1/sharepoint/sync/run-drives-and-libraries
router.post('/run-drives-and-libraries', runDrivesAndLibrariesSync);

export default router;
