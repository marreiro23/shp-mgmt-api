import morgan from 'morgan';
import { promises as fs } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import config from '../config/config.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * Middleware de logging
 */

// Logger para console (desenvolvimento)
export const consoleLogger = morgan('dev');

// Logger para arquivo (producao)
export const fileLogger = async () => {
  const logDir = join(__dirname, '..', '..', 'logs');

  // Criar pasta de logs se nao existir
  try {
    await fs.mkdir(logDir, { recursive: true });
  } catch (err) {
    console.error('Erro ao criar pasta de logs:', err);
  }

  const logFile = join(logDir, 'api.log');
  const stream = await fs.open(logFile, 'a');

  return morgan('combined', {
    stream: stream.createWriteStream()
  });
};

// Logger customizado com informacoes extras
export const customLogger = (req, res, next) => {
  const start = Date.now();

  // Capturar corpo da requisição
  const requestBody = req.method !== 'GET' && req.body ? JSON.stringify(req.body) : null;

  res.on('finish', async () => {
    const duration = Date.now() - start;
    const log = {
      timestamp: new Date().toISOString(),
      method: req.method,
      url: req.originalUrl || req.url,
      path: req.path,
      query: req.query,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('user-agent'),
      requestBody: requestBody
    };

    const logString = JSON.stringify(log);

    // Log colorido no console
    const color = res.statusCode >= 500 ? '\x1b[31m' : res.statusCode >= 400 ? '\x1b[33m' : '\x1b[32m';
    console.log(`${color}${req.method} ${req.path} ${res.statusCode}\x1b[0m ${duration}ms`);

    if (config.LOG_LEVEL === 'debug') {
      console.log(logString);
    }

    // Salvar em arquivo se habilitado
    if (config.LOG_TO_FILE) {
      try {
        const logDir = join(__dirname, '..', '..', 'logs');
        await fs.mkdir(logDir, { recursive: true });
        const logFile = join(logDir, 'api.log');
        await fs.appendFile(logFile, logString + '\n', 'utf8');
      } catch (err) {
        console.error('Erro ao salvar log:', err);
      }
    }
  });

  next();
};
