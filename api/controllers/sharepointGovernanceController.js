import auditTrailService from '../services/auditTrailService.js';
import compareService from '../services/compareService.js';
import config from '../config/config.js';
import importExportService from '../services/importExportService.js';
import operationsStoreService from '../services/operationsStoreService.js';
import XLSX from 'xlsx';

function createCorrelationId(req) {
  return req.headers['x-correlation-id'] || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function isFeatureEnabled(flag) {
  const activeFlags = Array.isArray(config.FEATURE_FLAGS) ? config.FEATURE_FLAGS : [];
  return activeFlags.includes(flag);
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

function parseIntQuery(value, fallbackValue) {
  const parsed = Number.parseInt(String(value || ''), 10);
  return Number.isFinite(parsed) ? parsed : fallbackValue;
}

function escapeCsvValue(value) {
  const asText = value === null || value === undefined ? '' : String(value);
  if (asText.includes(',') || asText.includes('"') || asText.includes('\n') || asText.includes('\r')) {
    return `"${asText.replace(/"/g, '""')}"`;
  }
  return asText;
}

function normalizeForCsv(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'object') return JSON.stringify(value);
  return value;
}

function toCsv(rows) {
  const safeRows = Array.isArray(rows) ? rows : [];
  if (safeRows.length === 0) return 'result\n';

  const headers = Array.from(
    safeRows.reduce((set, row) => {
      Object.keys(row || {}).forEach((key) => set.add(key));
      return set;
    }, new Set())
  );

  const headerLine = headers.map(escapeCsvValue).join(',');
  const dataLines = safeRows.map((row) => headers
    .map((header) => escapeCsvValue(normalizeForCsv(row?.[header])))
    .join(','));

  return [headerLine, ...dataLines].join('\n');
}

function normalizeRowsForSpreadsheet(rows) {
  return (Array.isArray(rows) ? rows : []).map((row) => {
    const normalized = {};
    Object.entries(row || {}).forEach(([key, value]) => {
      normalized[key] = normalizeForCsv(value);
    });
    return normalized;
  });
}

function toXlsxBuffer(rows, sheetName = 'CompareDiff') {
  const workbook = XLSX.utils.book_new();
  const normalizedRows = normalizeRowsForSpreadsheet(rows);
  const worksheet = XLSX.utils.json_to_sheet(normalizedRows.length > 0 ? normalizedRows : [{ result: '' }]);
  XLSX.utils.book_append_sheet(workbook, worksheet, sheetName.slice(0, 31));
  return XLSX.write(workbook, { bookType: 'xlsx', type: 'buffer' });
}

function flattenCompareResultRows(operationId, compareResult) {
  return (compareResult?.details || []).map((item) => ({
    operationId,
    type: item.type || '',
    status: item.status || '',
    name: item.name || '',
    siteId: item.siteId || '',
    driveId: item.driveId || '',
    itemId: item.itemId || '',
    currentId: item.currentId || '',
    diffsCount: Array.isArray(item.diffs) ? item.diffs.length : 0,
    diffs: item.diffs || []
  }));
}

function runImportOperationAsync(operation, correlationId) {
  setTimeout(() => {
    (async () => {
      try {
        operationsStoreService.updateOperation(operation.id, {
          status: 'running',
          startedAt: new Date().toISOString()
        });

        auditTrailService.appendEvent({
          action: 'import.execute',
          status: 'running',
          operationId: operation.id,
          targetType: 'sharepoint-import-package',
          correlationId,
          details: {
            mode: operation.payload.mode,
            objectCount: operation.payload.objects?.length || 0
          }
        });

        const result = await importExportService.executeImport(operation.payload);
        operationsStoreService.updateOperation(operation.id, {
          status: result.status === 'failed' ? 'failed' : result.status === 'partial' ? 'partial' : 'succeeded',
          result,
          finishedAt: new Date().toISOString()
        });

        auditTrailService.appendEvent({
          action: 'import.execute',
          status: result.status === 'failed' ? 'failed' : result.status === 'partial' ? 'warning' : 'succeeded',
          operationId: operation.id,
          targetType: 'sharepoint-import-package',
          correlationId,
          details: result
        });
      } catch (error) {
        operationsStoreService.updateOperation(operation.id, {
          status: 'failed',
          error: {
            code: error.code || 'SP_500',
            message: error.publicMessage || error.message || 'Falha na execucao de import.'
          },
          finishedAt: new Date().toISOString()
        });

        auditTrailService.appendEvent({
          action: 'import.execute',
          status: 'failed',
          operationId: operation.id,
          targetType: 'sharepoint-import-package',
          correlationId,
          details: {
            message: error.publicMessage || error.message || 'Falha na execucao de import.'
          }
        });
      }
    })();
  }, 10);
}

function runCompareOperationAsync(operation, correlationId) {
  setTimeout(() => {
    (async () => {
      try {
        operationsStoreService.updateOperation(operation.id, {
          status: 'running',
          startedAt: new Date().toISOString()
        });

        auditTrailService.appendEvent({
          action: 'compare.execute',
          status: 'running',
          operationId: operation.id,
          targetType: 'sharepoint-compare-package',
          correlationId,
          details: {
            objectCount: operation.payload.objects?.length || 0
          }
        });

        const result = await compareService.executeCompare(operation.payload);
        operationsStoreService.updateOperation(operation.id, {
          status: result.status === 'failed' ? 'failed' : result.status === 'partial' ? 'partial' : 'succeeded',
          result,
          finishedAt: new Date().toISOString()
        });

        auditTrailService.appendEvent({
          action: 'compare.execute',
          status: result.status === 'failed' ? 'failed' : result.status === 'partial' ? 'warning' : 'succeeded',
          operationId: operation.id,
          targetType: 'sharepoint-compare-package',
          correlationId,
          details: result.summary || {}
        });
      } catch (error) {
        operationsStoreService.updateOperation(operation.id, {
          status: 'failed',
          error: {
            code: error.code || 'SP_500',
            message: error.publicMessage || error.message || 'Falha na execucao de compare.'
          },
          finishedAt: new Date().toISOString()
        });

        auditTrailService.appendEvent({
          action: 'compare.execute',
          status: 'failed',
          operationId: operation.id,
          targetType: 'sharepoint-compare-package',
          correlationId,
          details: {
            message: error.publicMessage || error.message || 'Falha na execucao de compare.'
          }
        });
      }
    })();
  }, 10);
}

export async function previewImportPackage(req, res) {
  try {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

    const normalized = importExportService.normalizeImportRequest(req.body || {});
    importExportService.validateImportRequest(normalized);

    const preview = importExportService.previewImport(normalized);

    auditTrailService.appendEvent({
      action: 'import.preview',
      status: 'succeeded',
      correlationId,
      targetType: 'sharepoint-import-package',
      details: {
        mode: preview.mode,
        objectCount: preview.objectCount,
        dryRun: preview.dryRun
      }
    });

    return res.status(200).json({
      success: true,
      data: {
        featureFlag: 'governance-import-export',
        preview
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao gerar preview de importacao SharePoint.');
  }
}

export async function executeImportPackage(req, res) {
  try {
    if (!isFeatureEnabled('governance-import-export')) {
      const error = new Error('Feature governance-import-export desabilitada para este ambiente.');
      error.status = 403;
      error.code = 'SP_403';
      error.publicMessage = error.message;
      throw error;
    }

    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

    const normalized = importExportService.normalizeImportRequest(req.body || {});
    importExportService.validateImportRequest(normalized);

    const operation = operationsStoreService.createOperation({
      type: 'sharepoint-import',
      requestedBy: req.get('x-actor') || 'api',
      featureFlag: 'governance-import-export',
      payload: normalized
    });

    auditTrailService.appendEvent({
      action: 'import.execute.requested',
      status: 'queued',
      operationId: operation.id,
      targetType: 'sharepoint-import-package',
      correlationId,
      details: {
        mode: normalized.mode,
        objectCount: normalized.objects.length,
        dryRun: normalized.dryRun
      }
    });

    runImportOperationAsync(operation, correlationId);

    return res.status(202).json({
      success: true,
      data: {
        operationId: operation.id,
        status: operation.status
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar importacao SharePoint.');
  }
}

export async function getOperationStatus(req, res) {
  try {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

    const { operationId } = req.params;
    if (!operationId) {
      const error = new Error('operationId e obrigatorio.');
      error.status = 400;
      error.code = 'SP_400';
      error.publicMessage = error.message;
      throw error;
    }

    const operation = await operationsStoreService.getOperation(operationId);
    if (!operation) {
      const error = new Error('Operacao nao encontrada.');
      error.status = 404;
      error.code = 'SP_404';
      error.publicMessage = error.message;
      throw error;
    }

    return res.status(200).json({ success: true, data: operation });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao consultar operacao.');
  }
}

export async function listAuditEvents(req, res) {
  try {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

      const rows = await auditTrailService.listEvents({
      action: req.query.action,
      status: req.query.status,
      operationId: req.query.operationId,
      correlationId: req.query.correlationId,
      limit: parseIntQuery(req.query.limit, 50),
      offset: parseIntQuery(req.query.offset, 0)
    });

    return res.status(200).json({
      success: true,
      data: rows
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao listar eventos de auditoria.');
  }
}

export async function getExportPackageContract(req, res) {
  try {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

    const contract = importExportService.buildExportPackageContract(req.query || {});

    auditTrailService.appendEvent({
      action: 'export.package.contract',
      status: 'succeeded',
      targetType: 'sharepoint-export-package',
      correlationId,
      details: {
        source: contract.source,
        format: contract.format
      }
    });

    return res.status(200).json({
      success: true,
      data: contract
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao obter contrato de exportacao.');
  }
}

export async function previewComparePackage(req, res) {
  try {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

    const normalized = compareService.normalizeCompareRequest(req.body || {});
    compareService.validateCompareRequest(normalized);

    const preview = await compareService.previewCompare(normalized);

    auditTrailService.appendEvent({
      action: 'compare.preview',
      status: 'succeeded',
      targetType: 'sharepoint-compare-package',
      correlationId,
      details: preview.summary
    });

    return res.status(200).json({
      success: true,
      data: {
        featureFlag: 'governance-compare',
        preview
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao gerar preview de comparacao SharePoint.');
  }
}

export async function executeComparePackage(req, res) {
  try {
    if (!isFeatureEnabled('governance-compare')) {
      const error = new Error('Feature governance-compare desabilitada para este ambiente.');
      error.status = 403;
      error.code = 'SP_403';
      error.publicMessage = error.message;
      throw error;
    }

    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

    const normalized = compareService.normalizeCompareRequest(req.body || {});
    compareService.validateCompareRequest(normalized);

    const operation = operationsStoreService.createOperation({
      type: 'sharepoint-compare',
      requestedBy: req.get('x-actor') || 'api',
      featureFlag: 'governance-compare',
      payload: normalized
    });

    auditTrailService.appendEvent({
      action: 'compare.execute.requested',
      status: 'queued',
      operationId: operation.id,
      targetType: 'sharepoint-compare-package',
      correlationId,
      details: {
        objectCount: normalized.objects.length
      }
    });

    runCompareOperationAsync(operation, correlationId);

    return res.status(202).json({
      success: true,
      data: {
        operationId: operation.id,
        status: operation.status
      }
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao iniciar comparacao SharePoint.');
  }
}

export async function exportCompareResult(req, res) {
  try {
    const correlationId = createCorrelationId(req);
    res.setHeader('x-correlation-id', correlationId);

    const operationId = String(req.query.operationId || '').trim();
    const format = String(req.query.format || 'json').toLowerCase();

    if (!operationId) {
      const error = new Error('operationId e obrigatorio.');
      error.status = 400;
      error.code = 'SP_400';
      error.publicMessage = error.message;
      throw error;
    }

    if (!['json', 'csv', 'xlsx'].includes(format)) {
      const error = new Error('format invalido. Valores suportados: json, csv, xlsx.');
      error.status = 400;
      error.code = 'SP_400';
      error.publicMessage = error.message;
      throw error;
    }

    const operation = operationsStoreService.getOperation(operationId);
    if (!operation) {
      const error = new Error('Operacao nao encontrada.');
      error.status = 404;
      error.code = 'SP_404';
      error.publicMessage = error.message;
      throw error;
    }

    if (operation.type !== 'sharepoint-compare') {
      const error = new Error('operationId informado nao pertence a uma operacao de compare.');
      error.status = 400;
      error.code = 'SP_400';
      error.publicMessage = error.message;
      throw error;
    }

    if (!operation.result) {
      const error = new Error('Resultado de compare ainda nao disponivel para exportacao.');
      error.status = 409;
      error.code = 'SP_409';
      error.publicMessage = error.message;
      throw error;
    }

    const payload = {
      operationId,
      status: operation.status,
      createdAt: operation.createdAt,
      finishedAt: operation.finishedAt,
      result: operation.result
    };

    const rows = flattenCompareResultRows(operationId, operation.result);
    const fileBase = `compare-diff-${operationId}`;

    auditTrailService.appendEvent({
      action: 'compare.export',
      status: 'succeeded',
      operationId,
      targetType: 'sharepoint-compare-package',
      correlationId,
      details: {
        format,
        rowCount: rows.length
      }
    });

    if (format === 'csv') {
      const csv = toCsv(rows);
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${fileBase}.csv"`);
      return res.status(200).send(csv);
    }

    if (format === 'xlsx') {
      const buffer = toXlsxBuffer(rows, 'CompareDiff');
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${fileBase}.xlsx"`);
      return res.status(200).send(buffer);
    }

    res.setHeader('Content-Disposition', `attachment; filename="${fileBase}.json"`);
    return res.status(200).json({
      success: true,
      data: payload
    });
  } catch (error) {
    return sendError(res, req, error, 'Falha ao exportar resultado de comparacao.');
  }
}
