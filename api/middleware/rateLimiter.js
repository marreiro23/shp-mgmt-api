import rateLimit from 'express-rate-limit';
import config from '../config/config.js';

/**
 * Middleware de rate limiting
 * Previne abuso da API
 */
const rateLimiter = rateLimit({
  windowMs: config.RATE_LIMIT_WINDOW_MS,
  max: config.RATE_LIMIT_MAX_REQUESTS,
  message: {
    success: false,
    message: 'Muitas requisicoes. Tente novamente em alguns minutos.'
  },
  standardHeaders: true,
  legacyHeaders: false
});

export default rateLimiter;
