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
    expect(data.web.admin).to.equal('/web/admin.html');
    expect(data.endpoints.adminAppRegistration).to.equal('/api/v1/sharepoint/admin/app-registration');
  });
});
