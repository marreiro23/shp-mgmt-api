# Certificates

This folder is the expected location for certificate material referenced by the
API runtime.

## Purpose

- host PEM certificate file used by app-only Graph authentication
- keep certificate path stable for local and scripted execution

## Security guidance

- never commit active private keys
- store real secrets securely outside version control
- keep only templates, examples or local non-tracked files when possible
