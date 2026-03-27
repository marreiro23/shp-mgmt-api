# Operations data store

This folder stores asynchronous operation state snapshots.

## Operation lifecycle

- queued
- running
- succeeded
- partial
- failed

## Stored fields

- operation metadata (type, featureFlag, actor)
- request payload
- execution result summary
- error details when applicable
- timestamps for created/started/finished

## Purpose

This data powers operation polling endpoints and compare/import export flows.
