---
applyTo: '**/*.js, **/*.mjs, **/*.cjs'
description: 'Guidelines for building secure and maintainable JavaScript APIs (Node.js)'
---

# JavaScript API Guidelines

## Scope

Use these rules for Node.js API code in JavaScript.

## Core Rules

- Prefer async and non-blocking I/O in all request paths.
- Keep route handlers thin and move business logic to services.
- Validate all external input at API boundaries.
- Return structured errors with stable internal error codes.
- Never hardcode secrets; load credentials from environment variables.

## API Design

- Use explicit route versioning, such as `/api/v1`.
- Use consistent response envelopes for success and failure.
- Use pagination for list endpoints.
- Enforce request timeouts for outbound HTTP calls.

## Security

- Sanitize user input and encode outputs to reduce injection risk.
- Enforce least privilege for external API permissions.
- Do not log access tokens, certificates, private keys, or raw secrets.
- Add correlation IDs to request context and logs.

## Performance and Reliability

- Implement retries with exponential backoff only for transient errors.
- Handle `429` and `5xx` responses with bounded retry policies.
- Avoid blocking calls in hot paths.
- Use streaming for large file operations when possible.

## Code Quality

- Use clear module boundaries: routes, services, clients, models, utils.
- Keep functions small and focused on one responsibility.
- Prefer descriptive names over abbreviations.
- Add unit tests for service logic and integration tests for routes.

## SharePoint Integration Notes

- Prefer Microsoft Graph where supported.
- Use SharePoint REST API only when Graph does not cover the scenario.
- Normalize folder paths and file names before remote operations.
- Map downstream Graph/SharePoint errors to stable API errors.
