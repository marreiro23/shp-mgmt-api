import { spawn } from 'child_process';
import { readFileSync } from 'fs';
import { basename, dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import config from '../config/config.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, '..', '..');
const SCRIPT_PATH = resolve(REPO_ROOT, 'scripts', 'Update-GraphAppScopes.ps1');
const CATALOG_PATH = resolve(REPO_ROOT, 'config', 'graph-app-permissions.json');

function trimToString(value) {
  return value === undefined || value === null ? '' : String(value).trim();
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function getCatalog() {
  const raw = readFileSync(CATALOG_PATH, 'utf8');
  return JSON.parse(raw);
}

function getRecommendedPermissionNames() {
  return getCatalog().recommendedApplicationPermissions.map((item) => item.name);
}

function normalizeRequest(input = {}) {
  const explicitPermissions = Array.isArray(input.graphApplicationPermissions)
    ? input.graphApplicationPermissions.map((item) => trimToString(item)).filter(Boolean)
    : [];

  return {
    tenantId: trimToString(input.tenantId),
    clientId: trimToString(input.clientId),
    applicationObjectId: trimToString(input.applicationObjectId),
    graphApplicationPermissions: explicitPermissions.length > 0 ? explicitPermissions : getRecommendedPermissionNames(),
    grantAdminConsentAssignments: input.grantAdminConsentAssignments === true,
    whatIf: input.whatIf !== false,
    execute: input.execute === true
  };
}

function validateRequest(input) {
  if (!input.tenantId) {
    const error = new Error('tenantId é obrigatório para atualizar escopos da App Registration.');
    error.status = 400;
    error.code = 'SP_400';
    error.publicMessage = error.message;
    throw error;
  }

  if (!input.clientId && !input.applicationObjectId) {
    const error = new Error('Informe clientId ou applicationObjectId para localizar a App Registration.');
    error.status = 400;
    error.code = 'SP_400';
    error.publicMessage = error.message;
    throw error;
  }
}

function getCommandArguments(input, includeOutputJson = true) {
  const args = [
    '-NoLogo',
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    SCRIPT_PATH,
    '-TenantId',
    input.tenantId
  ];

  if (input.clientId) {
    args.push('-ClientId', input.clientId);
  }

  if (input.applicationObjectId) {
    args.push('-ApplicationObjectId', input.applicationObjectId);
  }

  if (input.graphApplicationPermissions.length > 0) {
    args.push('-GraphApplicationPermissions', ...input.graphApplicationPermissions);
  }

  if (input.grantAdminConsentAssignments) {
    args.push('-GrantAdminConsentAssignments');
  }

  if (input.whatIf) {
    args.push('-WhatIf');
  }

  if (includeOutputJson) {
    args.push('-OutputJson');
  }

  return args;
}

function buildCommandPreview(input) {
  const tokens = ['pwsh', '-File', shellQuote(SCRIPT_PATH), '-TenantId', shellQuote(input.tenantId || '<tenant-id>')];

  if (input.clientId) {
    tokens.push('-ClientId', shellQuote(input.clientId));
  } else if (input.applicationObjectId) {
    tokens.push('-ApplicationObjectId', shellQuote(input.applicationObjectId));
  } else {
    tokens.push('-ClientId', shellQuote('<client-id>'));
  }

  if (input.graphApplicationPermissions.length > 0) {
    tokens.push('-GraphApplicationPermissions');
    input.graphApplicationPermissions.forEach((permission) => tokens.push(shellQuote(permission)));
  }

  if (input.grantAdminConsentAssignments) {
    tokens.push('-GrantAdminConsentAssignments');
  }

  if (input.whatIf) {
    tokens.push('-WhatIf');
  }

  tokens.push('-OutputJson');
  return tokens.join(' ');
}

function parseExecutionOutput(stdout) {
  const trimmed = trimToString(stdout);
  if (!trimmed) {
    return null;
  }

  try {
    return JSON.parse(trimmed);
  } catch {
    return { raw: trimmed };
  }
}

function getExecutionEnabled() {
  return config.ENABLE_ADMIN_SCRIPT_EXECUTION === true;
}

function getPowerShellExecutable() {
  return trimToString(config.POWERSHELL_EXECUTABLE) || 'pwsh';
}

async function executeUpdateScopes(request) {
  if (!getExecutionEnabled()) {
    const error = new Error('Execução remota do script está desabilitada. Defina ENABLE_ADMIN_SCRIPT_EXECUTION=true para habilitar.');
    error.status = 403;
    error.code = 'SP_403';
    error.publicMessage = error.message;
    throw error;
  }

  const args = getCommandArguments(request, true);

  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(getPowerShellExecutable(), args, {
      cwd: REPO_ROOT,
      windowsHide: true,
      env: process.env
    });

    let stdout = '';
    let stderr = '';
    let completed = false;

    const timeoutHandle = setTimeout(() => {
      if (completed) return;
      completed = true;
      child.kill();
      const error = new Error('Tempo limite excedido ao executar Update-GraphAppScopes.ps1.');
      error.status = 504;
      error.code = 'SP_504';
      error.publicMessage = error.message;
      rejectPromise(error);
    }, config.ADMIN_SCRIPT_TIMEOUT_MS);

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    child.on('error', (spawnError) => {
      if (completed) return;
      completed = true;
      clearTimeout(timeoutHandle);
      const error = new Error(`Falha ao iniciar PowerShell: ${spawnError.message}`);
      error.status = 500;
      error.code = 'SP_500';
      error.publicMessage = error.message;
      rejectPromise(error);
    });

    child.on('close', (code) => {
      if (completed) return;
      completed = true;
      clearTimeout(timeoutHandle);

      if (code !== 0) {
        const details = trimToString(stderr) || trimToString(stdout) || `Processo retornou código ${code}.`;
        const error = new Error(details);
        error.status = 500;
        error.code = 'SP_500';
        error.publicMessage = details;
        rejectPromise(error);
        return;
      }

      resolvePromise({
        exitCode: code,
        stdout: trimToString(stdout),
        stderr: trimToString(stderr),
        parsed: parseExecutionOutput(stdout)
      });
    });
  });
}

function getAdministrationMetadata() {
  const catalog = getCatalog();
  return {
    executionEnabled: getExecutionEnabled(),
    scriptPath: `scripts/${basename(SCRIPT_PATH)}`,
    powerShellExecutable: getPowerShellExecutable(),
    recommendedApplicationPermissions: catalog.recommendedApplicationPermissions,
    optionalApplicationPermissions: catalog.optionalApplicationPermissions,
    leastPrivilegeGuidance: catalog.leastPrivilegeGuidance,
    executionExamples: catalog.executionExamples,
    commandTemplate: buildCommandPreview({
      tenantId: '',
      clientId: '',
      applicationObjectId: '',
      graphApplicationPermissions: getRecommendedPermissionNames(),
      grantAdminConsentAssignments: false,
      whatIf: true
    })
  };
}

export default {
  getAdministrationMetadata,
  normalizeRequest,
  validateRequest,
  buildCommandPreview,
  executeUpdateScopes
};
