# API test suite

This folder contains automated tests covering configuration, routes, governance
engines and web smoke behavior.

## Test files

- admin.routes.test.js: admin scope endpoints
- compare.service.test.js: compare engine logic
- import-export.service.test.js: import engine logic
- requirements.validation.test.js: requirement matrix tracking
- sharepoint.governance.routes.test.js: governance endpoints integration
- sharepoint.routes.test.js: API route integrations
- web.pages.test.js: static web smoke checks

## Execution

Run from api/ directory:

- npm run test
- npm run test:lts

## Goal

Protect backward compatibility while enabling incremental feature evolution.
