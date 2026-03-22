#!/usr/bin/env bash
# Build CURSOR_CI_REPORT.md and a flat bundle for upload from downloaded workflow artifacts.
set -euo pipefail

INPUT_DIR="${1:-handoff-raw}"
OUT_DIR="${2:-handoff-bundle}"

mkdir -p "$OUT_DIR"
REPORT="$OUT_DIR/CURSOR_CI_REPORT.md"

{
  echo "# CI handoff for Cursor"
  echo
  echo "- **Workflow run**: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-unknown}/actions/runs/${GITHUB_RUN_ID:-unknown}"
  echo "- **Repository**: \`${GITHUB_REPOSITORY:-unknown}\`"
  echo "- **SHA**: \`${GITHUB_SHA:-unknown}\`"
  echo "- **Ref**: \`${GITHUB_REF_NAME:-unknown}\`"
  echo
} >"$REPORT"

JOB_RESULTS="${INPUT_DIR}/_job_results.json"
if [[ -f "$JOB_RESULTS" ]]; then
  {
    echo "## Job results"
    echo
    echo '```json'
    cat "$JOB_RESULTS"
    echo '```'
    echo
  } >>"$REPORT"
fi

TRIVY_JSON=""
RUFF_JSON=""
TRIVY_HTML=""
while IFS= read -r -d '' f; do
  case "$(basename "$f")" in
    trivy-results.json) TRIVY_JSON="$f" ;;
    ruff-results.json) RUFF_JSON="$f" ;;
    trivy-report.html) TRIVY_HTML="$f" ;;
  esac
done < <(find "$INPUT_DIR" -type f \( -name 'trivy-results.json' -o -name 'ruff-results.json' -o -name 'trivy-report.html' \) -print0 2>/dev/null || true)

if [[ -n "$TRIVY_JSON" && -f "$TRIVY_JSON" ]]; then
  cp "$TRIVY_JSON" "$OUT_DIR/trivy-results.json"
  [[ -n "$TRIVY_HTML" && -f "$TRIVY_HTML" ]] && cp "$TRIVY_HTML" "$OUT_DIR/trivy-report.html"
  {
    echo "## Trivy (summary)"
    echo
    if command -v jq >/dev/null 2>&1; then
      vuln="$(
        jq '[.Results[]? | (.Vulnerabilities // []) | length] | add // 0' "$TRIVY_JSON" 2>/dev/null || echo "?"
      )"
      secret="$(
        jq '[.Results[]? | (.Secrets // []) | length] | add // 0' "$TRIVY_JSON" 2>/dev/null || echo "?"
      )"
      misconf="$(
        jq '[.Results[]? | (.Misconfigurations // []) | length] | add // 0' "$TRIVY_JSON" 2>/dev/null || echo "?"
      )"
      lic="$(
        jq '[.Results[]? | (.Licenses // []) | length] | add // 0' "$TRIVY_JSON" 2>/dev/null || echo "?"
      )"
      echo "| Category | Count |"
      echo "|----------|-------|"
      echo "| Vulnerabilities | ${vuln} |"
      echo "| Secrets | ${secret} |"
      echo "| Misconfigurations | ${misconf} |"
      echo "| Licenses | ${lic} |"
      echo
      echo "### Sample findings (first 15)"
      echo
      echo '```text'
      jq -r '
        [.Results[]? | . as $r |
          ($r.Vulnerabilities // [])[] | "[vuln] \($r.Target // "?"): \(.VulnerabilityID // .PkgName // "?") \(.Severity // "")"
        ] + [.Results[]? | . as $r |
          ($r.Secrets // [])[] | "[secret] \($r.Target // "?"): \(.Title // .RuleID // "?")"
        ] + [.Results[]? | . as $r |
          ($r.Misconfigurations // [])[] | "[misconfig] \($r.Target // "?"): \(.AVDID // .ID // .Title // "?")"
        ]
        | .[0:15][]' "$TRIVY_JSON" 2>/dev/null || echo "(could not parse Trivy JSON)"
      echo '```'
    else
      echo "Install jq for Trivy tables; full JSON copied to \`trivy-results.json\` in this bundle."
    fi
    echo
  } >>"$REPORT"
fi

if [[ -n "$RUFF_JSON" && -f "$RUFF_JSON" ]]; then
  cp "$RUFF_JSON" "$OUT_DIR/ruff-results.json"
  {
    echo "## Ruff (summary)"
    echo
    if command -v jq >/dev/null 2>&1; then
      total="$(jq 'length' "$RUFF_JSON" 2>/dev/null || echo "0")"
      echo "Total diagnostics: **${total}**"
      echo
      echo "### By rule (top 15)"
      echo
      echo '```text'
      jq -r 'group_by(.code) | map({code: .[0].code, n: length}) | sort_by(-.n) | .[:15] | .[] | "\(.n)\t\(.code)"' "$RUFF_JSON" 2>/dev/null || true
      echo '```'
      echo
      echo "### Sample (first 20)"
      echo
      echo '```text'
      jq -r '.[:20][] | "\(.filename // "?"):\(.location.row // "?"):\(.location.column // "?")\t\(.code // "?")\t\(.message // "")"' "$RUFF_JSON" 2>/dev/null || true
      echo '```'
    else
      echo "Full JSON copied to \`ruff-results.json\` in this bundle."
    fi
    echo
  } >>"$REPORT"
fi

# Copy CodeAudit HTML (artifact paths contain "codeaudit")
while IFS= read -r f; do
  cp "$f" "$OUT_DIR/codeaudit-$(basename "$f")" 2>/dev/null || true
done < <(find "$INPUT_DIR" -type f -name '*.html' 2>/dev/null | grep -i codeaudit || true)

{
  echo "## Files in this bundle"
  echo
  (cd "$OUT_DIR" && ls -la)
  echo
  echo "---"
  echo
  echo "Attach **CURSOR_CI_REPORT.md** plus any JSON files to Cursor, or paste this file contents. Fix issues until the \`quality-gate\` job is green."
} >>"$REPORT"

echo "Wrote $REPORT"
