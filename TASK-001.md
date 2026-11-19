# Autonomous qualification task 001 — slug normalization

Status: **Proposed only**. This file is an operator-readable task specification.
It does **not** create or approve a DAS task, authorize a provider, or grant release permission.

## Objective

Improve `toSlug(value)` in `src/slug.js` to normalize human-readable
ASCII labels for use in URLs, using only standard JavaScript/Node.js APIs.

## Exact acceptance criteria

1. Convert ASCII letters to lowercase.
2. Trim leading and trailing whitespace, including tabs and newlines.
3. Replace each nonempty run of ASCII whitespace and/or ASCII punctuation
   characters with a single hyphen; never start or end with a hyphen.
4. Keep letters `a-z` and digits `0-9` in order.
5. Return `""` when the input contains no ASCII letters or digits.
6. Throw `TypeError` for non-string inputs, preserving the baseline behavior.
7. Add deterministic Node built-in tests for cases including
   `"  Hello,\\tWorld!  "` → `"hello-world"`,
   `"Road   Map"` → `"road-map"`,
   `"A---B"` → `"a-b"`,
   `"Hi! 2026"` → `"hi-2026"`, and `"!!!"` → `""`.
8. `node --test` and `node --check src/slug.js` both pass.
9. Only `src/slug.js` and `tests/slug.test.js` may change for this task.

## Safety boundaries

Run against a disposable local clone of `DAS-Testing`, on a separate
branch with an isolated test database. No third-party packages, secrets,
shell downloads, deployments, production operations or customer data.
Provide an independent accepted-checkpoint/release receipt before
calling this a completed autonomous release.

A subsequent **separate** live recovery rehearsal should intentionally
interrupt the worker and verify unique execution/recovery without bypassing
any DAS approval, budget or release controls.
