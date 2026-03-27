import sharePointGraphService from './sharepointGraphService.js';
import resourcePersistenceService from './resourcePersistenceService.js';
import resourceQueryService from './resourceQueryService.js';

/**
 * ResourceSyncService
 * Periodically syncs SharePoint, Teams, Entra ID resources to PostgreSQL
 * Populates filter dropdowns by keeping DB up-to-date
 */
class ResourceSyncService {
  constructor() {
    this.isRunning = false;
    this.lastSyncTS = null;
    this.syncIntervalMs = parseInt(process.env.SYNC_INTERVAL_MS || '300000', 10); // Default 5 min
  }

  /**
   * Start the periodic sync process
   */
  start() {
    if (this.isRunning) return;
    this.isRunning = true;
    console.log(`[ResourceSyncService] Starting periodic sync (interval: ${this.syncIntervalMs}ms)`);
    this.scheduleSyncRun();
  }

  /**
   * Stop the periodic sync process
   */
  stop() {
    this.isRunning = false;
    if (this.syncTimeoutId) clearTimeout(this.syncTimeoutId);
    console.log('[ResourceSyncService] Stopped periodic sync');
  }

  /**
   * Schedule the next sync run
   */
  scheduleSyncRun() {
    if (!this.isRunning) return;
    this.syncTimeoutId = setTimeout(async () => {
      try {
        await this.runFullSync();
      } catch (error) {
        console.error('[ResourceSyncService] Sync error:', error.message);
      }
      this.scheduleSyncRun();
    }, this.syncIntervalMs);
  }

  /**
   * Execute full sync: sites, users, groups, teams, drives, libraries
   */
  async runFullSync() {
    const startTime = Date.now();
    console.log('[ResourceSyncService] Starting full sync run...');

    try {
      // Sync all resources in parallel
      await Promise.all([
        this.syncSites(),
        this.syncUsers(),
        this.syncGroups(),
        this.syncTeams()
      ]);

      this.lastSyncTS = new Date();
      const elapsedMs = Date.now() - startTime;
      console.log(`[ResourceSyncService] Full sync completed in ${elapsedMs}ms`);
    } catch (error) {
      console.error(`[ResourceSyncService] Full sync failed: ${error.message}`);
    }
  }

  /**
   * Sync SharePoint sites
   */
  async syncSites() {
    try {
      console.log('[ResourceSyncService] Syncing sites...');
      const sites = await sharePointGraphService.listSites('*', 999);
      
      if (Array.isArray(sites) && sites.length > 0) {
        await resourcePersistenceService.upsertSites(sites);
        console.log(`[ResourceSyncService] Synced ${sites.length} sites`);
      }
    } catch (error) {
      console.error(`[ResourceSyncService] Error syncing sites: ${error.message}`);
    }
  }

  /**
   * Sync Entra/M365 users
   */
  async syncUsers() {
    try {
      console.log('[ResourceSyncService] Syncing users...');
      const users = await sharePointGraphService.listUsers();
      
      if (Array.isArray(users) && users.length > 0) {
        await resourcePersistenceService.upsertUsers(users);
        console.log(`[ResourceSyncService] Synced ${users.length} users`);
      }
    } catch (error) {
      console.error(`[ResourceSyncService] Error syncing users: ${error.message}`);
    }
  }

  /**
   * Sync Microsoft 365 groups
   */
  async syncGroups() {
    try {
      console.log('[ResourceSyncService] Syncing groups...');
      const groups = await sharePointGraphService.listGroups();
      
      if (Array.isArray(groups) && groups.length > 0) {
        await resourcePersistenceService.upsertGroups(groups);
        console.log(`[ResourceSyncService] Synced ${groups.length} groups`);
      }
    } catch (error) {
      console.error(`[ResourceSyncService] Error syncing groups: ${error.message}`);
    }
  }

  /**
   * Sync Teams
   */
  async syncTeams() {
    try {
      console.log('[ResourceSyncService] Syncing teams...');
      const teams = await sharePointGraphService.listTeams();
      
      if (Array.isArray(teams) && teams.length > 0) {
        await resourcePersistenceService.upsertTeams(teams);
        console.log(`[ResourceSyncService] Synced ${teams.length} teams`);
      }
    } catch (error) {
      console.error(`[ResourceSyncService] Error syncing teams: ${error.message}`);
    }
  }

  /**
   * Sync drives for a specific site
   */
  async syncSiteDrives(siteId) {
    try {
      console.log(`[ResourceSyncService] Syncing drives for site ${siteId}...`);
      const drives = await sharePointGraphService.listDrives(siteId);
      
      if (Array.isArray(drives) && drives.length > 0) {
        await resourcePersistenceService.upsertDrives(siteId, drives);
        console.log(`[ResourceSyncService] Synced ${drives.length} drives for site ${siteId}`);
      }
    } catch (error) {
      console.error(`[ResourceSyncService] Error syncing drives for ${siteId}: ${error.message}`);
    }
  }

  /**
   * Sync libraries for a specific site
   */
  async syncSiteLibraries(siteId) {
    try {
      console.log(`[ResourceSyncService] Syncing libraries for site ${siteId}...`);
      const libraries = await sharePointGraphService.listLibraries(siteId);
      
      if (Array.isArray(libraries) && libraries.length > 0) {
        await resourcePersistenceService.upsertLibraries(siteId, libraries);
        console.log(`[ResourceSyncService] Synced ${libraries.length} libraries for site ${siteId}`);
      }
    } catch (error) {
      console.error(`[ResourceSyncService] Error syncing libraries for ${siteId}: ${error.message}`);
    }
  }

  /**
   * Sync all drives and libraries for all sites
   */
  async syncAllDrivesAndLibraries() {
    try {
      console.log('[ResourceSyncService] Syncing all drives and libraries...');
      
      const sites = await resourceQueryService.listSites({}, 999);
      if (!Array.isArray(sites) || sites.length === 0) {
        console.warn('[ResourceSyncService] No sites found to sync drives/libraries');
        return;
      }

      for (const site of sites) {
        await this.syncSiteDrives(site.site_id || site.id);
        await this.syncSiteLibraries(site.site_id || site.id);
      }
      
      console.log(`[ResourceSyncService] Completed sync of drives/libraries for ${sites.length} sites`);
    } catch (error) {
      console.error(`[ResourceSyncService] Error syncing all drives/libraries: ${error.message}`);
    }
  }

  /**
   * Get last sync timestamp
   */
  getLastSyncTS() {
    return this.lastSyncTS;
  }

  /**
   * Get sync status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      lastSyncTS: this.lastSyncTS,
      syncIntervalMs: this.syncIntervalMs
    };
  }
}

export default new ResourceSyncService();
