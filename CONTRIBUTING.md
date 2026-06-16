Contributing and interaction policy

This file documents contribution workflow and an interaction policy for using the automated assistant (Copilot resources) so we keep changes small and predictable.

Interaction policy (manage Copilot / assistant usage)

1. Keep requests focused
   - One change, bug, or feature per request. Large tasks should be split into small steps.
   - Provide the minimal context needed (file paths, short snippets). Avoid dumping entire repositories.

2. Batch small edits
   - Group related small edits into a single request (e.g., normalize multiple JSON fields at once).

3. Run local validators before asking
   - Validate JSON syntax and run unit tests locally to reduce back-and-forth.
   - Example commands:
     ```bash
     # validate JSON syntax
      jq --exit-status . Sources/MeCore/Resources/seed_data.json

      # list duplicate figure names (example)
      jq -r '.figures[].name' Sources/MeCore/Resources/seed_data.json | sort | uniq -d

     # build and test
     swift build
     swift test
     ```

4. Use CI for repeated checks
   - Add JSON Schema or unit tests to CI to catch regressions before review.

5. Migration strategy
   - For dataset schema changes (IDs, field renames), request a single migration patch and apply it in one PR.

Repository workflow

- Branching: create a topic branch per change (feature/bugfix/migration). Example:
  ```bash
  git checkout -b feat/add-ids-to-seed
  ```
- Commit messages: short imperative summary, optional longer body.
  - Example: `git commit -m "Add stable id fields to figures"`
- Pull requests: explain the change, include before/after examples if data changes.

Code review and CI

- PRs should include:
  - Tests or validation steps (if applicable)
  - JSON schema or referential-integrity checks for data changes

Sensitive files & secrets

- Do not commit secrets, keys, or provisioning profiles. `.gitignore` already excludes common files. If a secret was accidentally committed, open an issue and follow the repository's secret-removal steps.

Contact & help

- If you need the assistant to perform automated edits, scope the task and request an explicit run (e.g., "Run migration: add id fields to figures and update relationships").
