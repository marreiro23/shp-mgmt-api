import cors from 'cors';
import config from '../config/config.js';

/**
 * Middleware CORS
 */
const corsMiddleware = cors({
  origin: (origin, callback) => {
    // Permitir requisicoes sem origin (ex: Postman, curl)
    if (!origin) return callback(null, true);

    // Alguns contextos (ex: file://) enviam Origin: null
    if (origin === 'null') return callback(null, true);

    // Verificar se origin esta na lista
    if (config.CORS_ORIGINS.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Origin nao permitida pelo CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
});

export default corsMiddleware;
