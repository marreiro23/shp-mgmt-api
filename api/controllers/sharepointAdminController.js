import appRegistrationAdminService from '../services/appRegistrationAdminService.js';

function createCorrelationId(req) {
  return req.headers['x-correlation-id'] || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function sendError(res, req, error, fallbackMessage) {
  const correlationId = createCorrelationId(req);
  res.setHeader('x-correlation-id', correlationId);

  return res.status(error.status || 500).json({
    success: false,
    correlationId,
    error: {
      code: error.code || `SP_${error.status || 500}`,
      message: error.publicMessage || fallbackMessage
    }
  });
}

export async function getAppRegistrationMetadata(req, res) {
  try {
    return res.json({
      success: true,
      data: appRegistrationAdminService.getAdministrationMetadata()
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao carregar a configuração administrativa da App Registration.');
  }
}

export async function updateAppRegistrationScopes(req, res) {
  try {
    const request = appRegistrationAdminService.normalizeRequest(req.body || {});
    appRegistrationAdminService.validateRequest(request);

    const metadata = appRegistrationAdminService.getAdministrationMetadata();
    const commandPreview = appRegistrationAdminService.buildCommandPreview(request);

    if (!request.execute) {
      return res.json({
        success: true,
        data: {
          executionRequested: false,
          executionPerformed: false,
          executionEnabled: metadata.executionEnabled,
          commandPreview,
          graphApplicationPermissions: request.graphApplicationPermissions,
          grantAdminConsentAssignments: request.grantAdminConsentAssignments,
          whatIf: request.whatIf
        }
      });
    }

    const execution = await appRegistrationAdminService.executeUpdateScopes(request);
    return res.json({
      success: true,
      data: {
        executionRequested: true,
        executionPerformed: true,
        executionEnabled: metadata.executionEnabled,
        commandPreview,
        graphApplicationPermissions: request.graphApplicationPermissions,
        grantAdminConsentAssignments: request.grantAdminConsentAssignments,
        whatIf: request.whatIf,
        execution
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao atualizar escopos da App Registration.');
  }
}
