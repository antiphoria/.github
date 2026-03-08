# Antiphoria Quality Policy

This repository centralizes the default GitHub Actions quality policy for `antiphoria`.
The goal is an exhaustive baseline for fast-moving, AI-assisted, experimental code with strict-first defaults.

## Blocking Checks

- `preflight-reports`: required by default. Repositories must contain local preflight evidence files:
  - `.security/preflight/human-review.md`
  - `.security/preflight/llm-review.json`
- `trivy`: required for every repository. Runs `vuln`, `misconfig`, `secret`, and `license` scanners.
- `python-ruff`: required when Python is detected. Uses shared Ruff config with Bandit-compatible security rules.
- `python-test`: required when Python is detected. In strict mode, Python repositories must include a `tests/` directory.
- `python-codeaudit`: required when Python is detected. Generates HTML reports and applies blocking policy from the parsed findings summary.
- `node-quality`: required when `package.json` is present. Enforces lint/check/build outcomes, ESLint security checks, and dependency audit evaluation.
- `web-dast`: required when a web profile is detected. Runs OWASP ZAP baseline scan against preview URL or local preview server.
- `quality-gate`: the only status check that should be required in organization rulesets. It aggregates all blocking jobs.

## Strict Mode

- Default is `strict_mode: true` for exhaustive first-pass security review.
- Strict mode attempts to fail on any scanner findings where machine-parsable outputs are available.
- After baseline triage, teams can temporarily set `strict_mode: false` in caller workflows to use conservative thresholds (typically `HIGH/CRITICAL` for vulnerability-oriented checks).

## Detection Rules

- Python repository: any tracked `*.py` file
- Node or Astro repository: `package.json`
- Web profile: Astro config or preview/dev/start scripts
- Preferred package manager: `pnpm-lock.yaml`, then `yarn.lock`, otherwise `npm`

## Rollout

1. Add the caller workflow from `workflow-templates/org-quality.yml` to each repository.
2. Ensure each repository includes local preflight evidence files under `.security/preflight/`.
3. Require only `quality-gate` in organization rulesets.
4. Keep repositories private during initial hardening and publish only after findings are reviewed.
5. Once the workflow is stable, switch callers from `@main` to a pinned tag such as `@v1`.
