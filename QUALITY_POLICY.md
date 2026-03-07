# Antiphoria Quality Policy

This repository centralizes the default GitHub Actions quality policy for `antiphoria`.
The goal is a strong baseline for fast-moving, AI-assisted, experimental code without forcing irrelevant tools into every repository.

## Blocking Checks

- `trivy`: required for every repository. It blocks on `HIGH` and `CRITICAL` vulnerability, misconfiguration, and secret findings.
- `python-ruff`: required when Python is detected. It uses the shared `ruff.toml`, including `flake8-bandit` security rules.
- `node-quality`: required when `package.json` is present. It installs dependencies and runs `lint`, `check`, and `build` scripts when they exist.
- `quality-gate`: the only check that should be required in organization rulesets. It aggregates the blocking jobs above.

## Advisory Checks

- `python-codeaudit`: runs only for Python repositories and uploads HTML reports. It is intentionally non-blocking until the tool exposes a stable machine-readable pass/fail signal.

## Detection Rules

- Python repository: any tracked `*.py` file
- Node or Astro repository: `package.json`
- Preferred package manager: `pnpm-lock.yaml`, then `yarn.lock`, otherwise `npm`

## Rollout

1. Add the caller workflow from `workflow-templates/org-quality.yml` to each repository.
2. Require only the `quality-gate` check in organization rulesets.
3. Once the workflow is stable, switch callers from `@main` to a pinned tag such as `@v1`.
