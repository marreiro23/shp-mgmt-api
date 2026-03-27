import { expect } from 'chai';
import config from './config.js';

describe('SharePoint API Config', () => {
  it('should expose required runtime keys', () => {
    expect(config).to.have.property('PORT');
    expect(config).to.have.property('HOST');
    expect(config).to.have.property('API_PREFIX');
    expect(config).to.have.property('API_VERSION');
    expect(config).to.have.property('CORS_ORIGINS');
  });

  it('should keep CORS origins as an array', () => {
    expect(config.CORS_ORIGINS).to.be.an('array');
    expect(config.CORS_ORIGINS.length).to.be.greaterThan(0);
  });

  it('should keep positive rate limit values', () => {
    expect(config.RATE_LIMIT_WINDOW_MS).to.be.greaterThan(0);
    expect(config.RATE_LIMIT_MAX_REQUESTS).to.be.greaterThan(0);
  });

  it('should expose admin script execution settings', () => {
    expect(config).to.have.property('ENABLE_ADMIN_SCRIPT_EXECUTION');
    expect(config).to.have.property('ADMIN_SCRIPT_TIMEOUT_MS');
    expect(config.ADMIN_SCRIPT_TIMEOUT_MS).to.be.greaterThan(0);
    expect(config).to.have.property('POWERSHELL_EXECUTABLE');
  });
});
