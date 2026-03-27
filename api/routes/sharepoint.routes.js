import express from 'express';
import {
  getAppRegistrationMetadata,
  updateAppRegistrationScopes
} from '../controllers/sharepointAdminController.js';
import {
  executeComparePackage,
  executeImportPackage,
  exportCompareResult,
  getExportPackageContract,
  getOperationStatus,
  listAuditEvents,
  previewComparePackage,
  previewImportPackage
} from '../controllers/sharepointGovernanceController.js';
import {
  addEntraGroupMember,
  addTeamChannelMember,
  assignUserLicenses,
  authenticate,
  createDrive,
  createGroup,
  createFolder,
  createItemPermission,
  createLibrary,
  createTeamChannel,
  deleteItem,
  deleteItemPermission,
  exportResults,
  getConfig,
  getInventoryDatabase,
  listChannelMembers,
  listChannelContent,
  listDriveChildren,
  listFilesMetadata,
  listDrives,
  listGroups,
  listLibraries,
  listItemPermissions,
  listSites,
  listTeamChannels,
  listUserLicenses,
  listUsers,
  renameItem,
  removeEntraGroupMember,
  removeTeamChannelMember,
  updateDrive,
  updateGroup,
  updateLibrary,
  updateTeamChannel,
  updateUser,
  uploadFile
} from '../controllers/sharepointController.js';

const router = express.Router();

router.get('/config', getConfig);
router.get('/inventory/database', getInventoryDatabase);
router.post('/authenticate', authenticate);
router.get('/sites', listSites);
router.get('/groups', listGroups);
router.post('/groups', createGroup);
router.patch('/groups/:groupId', updateGroup);
router.get('/users', listUsers);
router.patch('/users/:userId', updateUser);
router.get('/users/:userId/licenses', listUserLicenses);
router.post('/users/:userId/licenses', assignUserLicenses);
router.get('/sites/:siteId/drives', listDrives);
router.post('/sites/:siteId/drives', createDrive);
router.get('/sites/:siteId/libraries', listLibraries);
router.post('/sites/:siteId/libraries', createLibrary);
router.patch('/sites/:siteId/libraries/:listId', updateLibrary);
router.get('/drives/:driveId/children', listDriveChildren);
router.get('/drives/:driveId/files-metadata', listFilesMetadata);
router.patch('/drives/:driveId', updateDrive);
router.get('/drives/:driveId/items/:itemId/permissions', listItemPermissions);
router.post('/drives/:driveId/items/:itemId/permissions', createItemPermission);
router.delete('/drives/:driveId/items/:itemId/permissions/:permissionId', deleteItemPermission);
router.post('/drives/:driveId/folders', createFolder);
router.post('/drives/:driveId/files', uploadFile);
router.patch('/drives/:driveId/items/:itemId', renameItem);
router.delete('/drives/:driveId/items/:itemId', deleteItem);
router.get('/teams/:teamId/channels', listTeamChannels);
router.post('/teams/:teamId/channels', createTeamChannel);
router.patch('/teams/:teamId/channels/:channelId', updateTeamChannel);
router.get('/teams/:teamId/channels/:channelId/members', listChannelMembers);
router.get('/teams/:teamId/channels/:channelId/content', listChannelContent);
router.post('/teams/:teamId/channels/:channelId/members', addTeamChannelMember);
router.delete('/teams/:teamId/channels/:channelId/members/:membershipId', removeTeamChannelMember);
router.post('/groups/:groupId/members', addEntraGroupMember);
router.delete('/groups/:groupId/members/:memberObjectId', removeEntraGroupMember);
router.get('/export', exportResults);
router.get('/admin/app-registration', getAppRegistrationMetadata);
router.post('/admin/update-scopes', updateAppRegistrationScopes);
router.get('/operations/:operationId', getOperationStatus);
router.get('/audit/events', listAuditEvents);
router.get('/admin-governance/export/package', getExportPackageContract);
router.post('/admin-governance/import/preview', previewImportPackage);
router.post('/admin-governance/import/execute', executeImportPackage);
router.post('/admin-governance/compare/preview', previewComparePackage);
router.post('/admin-governance/compare/execute', executeComparePackage);
router.get('/admin-governance/compare/export', exportCompareResult);

export default router;
