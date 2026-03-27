import { expect } from 'chai';
import app from '../server.js';

describe('Web pages smoke tests', () => {
  let server;
  let baseUrl;

  before((done) => {
    server = app.listen(0, '127.0.0.1', () => {
      const address = server.address();
      baseUrl = `http://127.0.0.1:${address.port}`;
      done();
    });
  });

  after((done) => {
    server.close(done);
  });

  async function fetchText(path) {
    const response = await fetch(`${baseUrl}${path}`);
    const text = await response.text();
    return { response, text };
  }

  it('serves collaboration page with active buttons', async () => {
    const { response, text } = await fetchText('/web/collaboration.html');

    expect(response.status).to.equal(200);
    expect(text).to.contain('id="btnExport"');
    expect(text).to.contain('id="btnPreviewExport"');
    expect(text).to.contain('id="btnListLibraries"');
    expect(text).to.contain('id="btnCreateLibrary"');
    expect(text).to.contain('id="btnUpdateDrive"');
    expect(text).to.contain('id="btnListGroups"');
    expect(text).to.contain('id="btnListUsers"');
    expect(text).to.contain('id="btnAssignUserLicenses"');
    expect(text).to.contain('id="btnListItemPermissions"');
    expect(text).to.contain('id="btnAddChannelMember"');
    expect(text).to.contain('id="btnListChannelMembers"');
    expect(text).to.contain('id="btnAddGroupMember"');
  });

  it('serves index page with default redirect to operations center', async () => {
    const { response, text } = await fetchText('/web/index.html');

    expect(response.status).to.equal(200);
    expect(text).to.contain("window.location.replace('operations-center.html')");
    expect(text).to.contain("params.has('legacy')");
  });

  it('serves operations center page with governance controls', async () => {
    const { response, text } = await fetchText('/web/operations-center.html');

    expect(response.status).to.equal(200);
    expect(text).to.contain('id="btnImpExecute"');
    expect(text).to.contain('id="btnCmpExecute"');
    expect(text).to.contain('id="btnOpsGet"');
    expect(text).to.contain('id="btnAudList"');
    expect(text).to.contain('id="btnExpCompareDownload"');
  });

  it('serves operations center with client navigation structure', async () => {
    const { response, text } = await fetchText('/web/operations-center.html');

    expect(response.status).to.equal(200);
    expect(text).to.contain('class="nav-item active"');
    expect(text).to.contain('data-page="importPage"');
    expect(text).to.contain('data-page="comparePage"');
    expect(text).to.contain('data-tab="homeStatus"');
    expect(text).to.contain("querySelectorAll('.nav-item')");
    expect(text).to.contain('function bindNavigation()');
  });

  it('serves admin page with command and execution controls', async () => {
    const { response, text } = await fetchText('/web/admin.html');

    expect(response.status).to.equal(200);
    expect(text).to.contain('id="btnLoadAdminConfig"');
    expect(text).to.contain('id="btnGenerateCommand"');
    expect(text).to.contain('id="btnRunUpdateScopes"');
    expect(text).to.contain("const API = '/api/v1/sharepoint/admin'");
  });

  it('includes admin page in the root metadata', async () => {
    const response = await fetch(`${baseUrl}/`);
    const data = await response.json();

    expect(response.status).to.equal(200);
    expect(data.web.home).to.equal('/web/operations-center.html');
    expect(data.web.legacyHome).to.equal('/web/index.html');
    expect(data.web.operationsCenter).to.equal('/web/operations-center.html');
    expect(data.web.admin).to.equal('/web/admin.html');
    expect(data.endpoints.adminAppRegistration).to.equal('/api/v1/sharepoint/admin/app-registration');
  });
});
