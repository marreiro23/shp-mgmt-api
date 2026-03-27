#!/usr/bin/env node

/**
 * API Test Suite - shp-mgmt-api
 * 
 * Testa todos os endpoints da aplicação
 * Uso: node api-test-suite.js
 */

const http = require('http');
const https = require('https');

const API_BASE = process.env.API_URL || 'http://localhost:3001/api/v1/sharepoint';
const TIMEOUT = 30000; // 30 segundos

// Cores para output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

class APITester {
  constructor() {
    this.results = {
      passed: 0,
      failed: 0,
      skipped: 0,
      tests: []
    };
  }

  log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
  }

  async request(method, path, body = null, expectStatus = 200) {
    return new Promise((resolve) => {
      const url = new URL(`${API_BASE}${path}`);
      const options = {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname + url.search,
        method,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        timeout: TIMEOUT
      };

      const client = url.protocol === 'https:' ? https : http;
      const req = client.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const parsed = data ? JSON.parse(data) : null;
            resolve({
              status: res.statusCode,
              headers: res.headers,
              body: parsed,
              rawBody: data
            });
          } catch (e) {
            resolve({
              status: res.statusCode,
              headers: res.headers,
              body: null,
              rawBody: data,
              error: e.message
            });
          }
        });
      });

      req.on('error', (error) => {
        resolve({
          status: 0,
          error: error.message
        });
      });

      req.on('timeout', () => {
        req.destroy();
        resolve({
          status: 0,
          error: 'Request timeout'
        });
      });

      if (body) {
        req.write(JSON.stringify(body));
      }
      req.end();
    });
  }

  async test(name, method, path, body = null, expectStatus = 200) {
    this.log(`  Testing: ${method} ${path}...`, 'cyan');
    
    try {
      const response = await this.request(method, path, body, expectStatus);
      
      if (response.error) {
        this.log(`    ✗ FAIL: ${response.error}`, 'red');
        this.results.failed++;
        this.results.tests.push({ name, status: 'FAIL', error: response.error });
        return null;
      }

      if (response.status !== expectStatus) {
        this.log(`    ✗ FAIL: Expected ${expectStatus}, got ${response.status}`, 'red');
        if (response.body?.error) {
          this.log(`      Error: ${response.body.error.message}`, 'red');
        }
        this.results.failed++;
        this.results.tests.push({ name, status: 'FAIL', statusCode: response.status });
        return null;
      }

      this.log(`    ✓ PASS (${response.status})`, 'green');
      this.results.passed++;
      this.results.tests.push({ name, status: 'PASS', statusCode: response.status });
      return response.body;
    } catch (error) {
      this.log(`    ✗ ERROR: ${error.message}`, 'red');
      this.results.failed++;
      this.results.tests.push({ name, status: 'ERROR', error: error.message });
      return null;
    }
  }

  async runTests() {
    this.log('\n╔═══════════════════════════════════════════════════════════════╗', 'blue');
    this.log('║           shp-mgmt-api - API Test Suite                      ║', 'blue');
    this.log('╚═══════════════════════════════════════════════════════════════╝\n', 'blue');

    // 1. Health Check
    this.log('1. Health and Configuration', 'yellow');
    const health = await this.test('Health Check', 'GET', '/../../health', null, 200);
    const config = await this.test('Get Configuration', 'GET', '/config', null, 200);

    // 2. SharePoint Sites
    this.log('\n2. SharePoint Sites', 'yellow');
    const sites = await this.test('List Sites', 'GET', '/sites', null, 200);
    const sitesTop = await this.test('List Sites (top=5)', 'GET', '/sites?top=5', null, 200);

    // 3. SharePoint Groups
    this.log('\n3. Microsoft 365 Groups', 'yellow');
    const groups = await this.test('List Groups', 'GET', '/groups', null, 200);

    // 4. Entra ID Users
    this.log('\n4. Entra ID Users', 'yellow');
    const users = await this.test('List Users', 'GET', '/users', null, 200);
    const usersSearch = await this.test('List Users (search=admin)', 'GET', '/users?search=admin', null, 200);

    // 5. Microsoft Teams
    this.log('\n5. Microsoft Teams', 'yellow');
    const teams = await this.test('List Teams', 'GET', '/teams', null, 200);

    // 6. Drives (if we have a site)
    if (sites?.data && sites.data.length > 0) {
      this.log('\n6. SharePoint Drives', 'yellow');
      const siteId = sites.data[0].id;
      this.log(`   Using site: ${siteId}`, 'cyan');
      const drives = await this.test('List Drives', 'GET', `/sites/${siteId}/drives`, null, 200);
      
      // 7. Libraries (if we have drives)
      this.log('\n7. SharePoint Libraries', 'yellow');
      const libraries = await this.test('List Libraries', 'GET', `/sites/${siteId}/libraries`, null, 200);

      // 8. Drive Items (if we have drives)
      if (drives?.data && drives.data.length > 0) {
        this.log('\n8. Drive Items', 'yellow');
        const driveId = drives.data[0].id;
        this.log(`   Using drive: ${driveId}`, 'cyan');
        const items = await this.test('List Drive Children', 'GET', `/drives/${driveId}/children`, null, 200);
        const metadata = await this.test('List Files Metadata', 'GET', `/drives/${driveId}/files-metadata`, null, 200);
      }
    }

    // 9. Sync Service
    this.log('\n9. Resource Sync Service', 'yellow');
    const syncStatus = await this.test('Get Sync Status', 'GET', '/sync/status', null, 200);

    // 10. Audit Trail
    this.log('\n10. Audit Trail', 'yellow');
    const auditEvents = await this.test('List Audit Events', 'GET', '/audit/events', null, 200);

    // 11. Frontend Commands
    this.log('\n11. Frontend Commands History', 'yellow');
    const commands = await this.test('List Frontend Commands', 'GET', '/frontend-commands', null, 200);

    // 12. Database Records
    this.log('\n12. Database Records', 'yellow');
    const dbSites = await this.test('Get Database Records (sites)', 'GET', '/database/records?table=sharepoint_sites&limit=5', null, 200);
    const dbUsers = await this.test('Get Database Records (users)', 'GET', '/database/records?table=sharepoint_users&limit=5', null, 200);
    const dbGroups = await this.test('Get Database Records (groups)', 'GET', '/database/records?table=sharepoint_groups&limit=5', null, 200);

    // Print Summary
    this.printSummary();
  }

  printSummary() {
    const total = this.results.passed + this.results.failed;
    const percentage = total > 0 ? Math.round((this.results.passed / total) * 100) : 0;

    this.log('\n╔═══════════════════════════════════════════════════════════════╗', 'blue');
    this.log('║                         Test Summary                          ║', 'blue');
    this.log('╚═══════════════════════════════════════════════════════════════╝\n', 'blue');

    this.log(`Total Tests: ${total}`);
    this.log(`✓ Passed: ${this.results.passed}`, 'green');
    this.log(`✗ Failed: ${this.results.failed}`, this.results.failed > 0 ? 'red' : 'green');
    this.log(`Success Rate: ${percentage}%\n`, percentage === 100 ? 'green' : 'yellow');

    if (this.results.failed > 0) {
      this.log('Failed Tests:', 'red');
      this.results.tests
        .filter(t => t.status !== 'PASS')
        .forEach(t => {
          this.log(`  - ${t.name}: ${t.error || `Status ${t.statusCode}`}`, 'red');
        });
    }
  }
}

// Run tests
const tester = new APITester();
tester.runTests().catch(console.error);
