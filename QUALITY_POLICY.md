# Antiphoria Quality Policy

This repository centralizes the default GitHub Actions quality policy for `antiphoria`.
The goal is a strict baseline for fast-moving, AI-assisted, experimental code, with **clear reports** so you can iterate locally (including with Cursor) until checks pass.

## Blocking checks (enforced today)

The reusable workflow [.github/workflows/quality-gate.yml](.github/workflows/quality-gate.yml) aggregates these **blocking** jobs into the final `quality-gate` job:

| Job | When it runs | What it enforces |
|-----|----------------|------------------|
| `detect` | Always | Detects Python (`*.py` tracked) and Node (`package.json`). |
| `trivy` | Always | Filesystem scan: **vuln**, **misconfig**, **secret**, **license** (see [trivy.yaml](trivy.yaml)). |
| `python-ruff` | If Python detected | Shared [ruff.toml](ruff.toml): lint (incl. Bandit-style rules) + format check. |
| `python-test` | If Python detected | `unittest` under `tests/` if that directory exists; otherwise skipped (does not fail). |
| `node-quality` | If `package.json` exists | Runs `lint`, `check`, and `build` scripts **only when** each script is defined in `package.json`. |

**Advisory only (does not fail the gate):**

- **`python-codeaudit`**: HTML reports are produced and uploaded as artifacts; steps use `continue-on-error` so noise does not block merges. Treat as extra signal during hardening.

**Not implemented in this workflow (ignore older bullets elsewhere):**

- Organization-wide preflight file requirements
- `web-dast` (OWASP ZAP)
- Automatic `npm audit` / dependency policy in the Node job
- Mandatory `tests/` for all Python repos

## Required status check in GitHub

In branch protection or rulesets, require the check named **`quality-gate`** (the final aggregating job). Confirm the exact label in **Actions** on a sample run; GitHub shows the job name from the reusable workflow.

## Cursor green-loop (reports)

After each push or `workflow_dispatch`:

1. Open the workflow run in GitHub Actions.
2. Read the **job summaries** (Trivy, Ruff, Python tests, Node) on the run summary page.
3. Download the **`ci-handoff-<run_id>`** artifact (zip). Inside you will find **`CURSOR_CI_REPORT.md`** plus copies of **`trivy-results.json`**, **`ruff-results.json`**, and CodeAudit HTML when present.
4. Attach `CURSOR_CI_REPORT.md` and any JSON files to Cursor (or paste the markdown) and fix issues until **`quality-gate`** is green.

Other artifacts (retention 30 days unless noted):

- `trivy-scan-*`: JSON + HTML
- `ruff-scan-*`: Ruff diagnostics JSON
- `codeaudit-reports-*`: CodeAudit HTML
- `node-quality-logs-*`: Captured lint/check/build output (on failure, 14 days)

## Triage and suppressions

After manual review, you may narrow findings **per repository**:

- **Trivy:** `.trivyignore`, or paths / rules in a repo-level `trivy.yaml`, or shared policy tweaks in this org repo (affects everyone).
- **Ruff:** `[tool.ruff.lint.per-file-ignores]` or `# noqa: CODE` in the target repo’s `pyproject.toml` / `ruff.toml`.
- **Document** durable suppressions with a short note (PR comment or README) so future triage knows why.

## Caller workflow (member repositories)

Use [workflow-templates/org-quality.yml](workflow-templates/org-quality.yml) as the starting point. It must call the reusable workflow with valid inputs, for example:

- `policy-ref: main` (must match the `policy-ref` input name).

Optional manual runs: the template includes **`workflow_dispatch`**.

### Trivy SARIF and GitHub code scanning

To upload Trivy results to GitHub **code scanning** (SARIF):

1. Set `upload-trivy-sarif: true` in the caller’s `with:` block.
2. Add **`security-events: write`** to the caller workflow `permissions` (alongside `contents: read`).

**Note:** For **private** repositories, the code scanning UI usually requires **GitHub Advanced Security**. Public repositories can use code scanning without GHAS. If you do not use SARIF, leave `upload-trivy-sarif: false` and omit `security-events: write`.

The SARIF upload runs in a separate job **`trivy-sarif`** so default callers are not forced to grant `security-events: write`.

## Rollout

1. Copy or generate the caller workflow from `workflow-templates/org-quality.yml` into each repository as `.github/workflows/<name>.yml`.
2. Require **`quality-gate`** in rulesets or branch protection.
3. Keep repositories private during initial triage; use **`ci-handoff`** artifacts and job summaries to drive fixes.
4. Once stable, pin callers to a tag (e.g. `@v1`) instead of `@main`.

## Strict mode (historical)

Earlier drafts described a `strict_mode` input and preflight gates; those are **not** wired in the current reusable workflow. Any future strict mode should be implemented in `quality-gate.yml` and documented here in the same commit.
