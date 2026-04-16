# Peakweb Task Tracking (GitHub Issues)

## Purpose

Manage tracked-task context in GitHub Issues while still allowing direct-brief intake when no issue is provided.

## Behavior

- Normalize issue references before reading or updating.
- Extract acceptance criteria and convert to execution checklist.
- Post milestone updates at start, review-ready, and completion points.
- Include PR link and validation evidence in completion update.
- If work began from direct brief only, do not fabricate issue updates.
