#!/usr/bin/env bash
set -euo pipefail

# ForgeLoop Orchestrator (plan -> tasks -> implement)
# Assumes constitution and spec already exist. Blitz through planning and implementation.
#
# Usage:
#   scripts/orchestrate.sh --agent codex --feature 001-demo [--from plan|tasks|implement] [--only step] [--dry-run] [--variant sh|ps]

AGENT=""
FEATURE=""
FROM_STEP=""
ONLY_STEP=""
DRY_RUN=0
SCRIPT_VARIANT="${SCRIPT_VARIANT:-sh}"

# Always treat project root as two directories up from this script
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$REPO_ROOT/.forgeloop/logs"
mkdir -p "$LOG_DIR"

ALL_STEPS=(plan tasks implement)

log()  { printf "%b\n" "$*" >&2; }
ok()   { log "\033[32m✔\033[0m $*"; }
warn() { log "\033[33m⚠\033[0m $*"; }
err()  { log "\033[31m✖ $*\033[0m"; }

usage() {
  cat >&2 <<EOF
ForgeLoop orchestrator (blitz mode)

Required:
  --agent <name>       Agent key (codex, claude, gemini, cursor-agent, qwen, opencode, windsurf, kilocode, auggie, roo, codebuddy, amp, shai, q)
  --feature <name>     Feature folder name (e.g., 001-photo-albums)

Optional:
  --from <step>        Start from: plan|tasks|implement (default: plan)
  --only <step>        Run only one step
  --dry-run            Print commands without running
  --variant <sh|ps>    Choose agent wrapper variant (default: sh)

Assumptions:
  - Constitution and spec are already created.
  - Agent wrappers exist in scripts/agents/<agent>/<step>.(sh|ps1)
EOF
}

is_valid_step() {
  local s="$1"; for x in "${ALL_STEPS[@]}"; do [[ "$s" == "$x" ]] && return 0; done; return 1;
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)   AGENT="${2:-}"; shift 2;;
    --feature) FEATURE="${2:-}"; shift 2;;
    --from)    FROM_STEP="${2:-}"; shift 2;;
    --only)    ONLY_STEP="${2:-}"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --variant) SCRIPT_VARIANT="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) err "Unknown arg: $1"; usage; exit 1;;
  esac
done

[[ -n "$AGENT" ]] || { err "--agent is required"; usage; exit 1; }
[[ -n "$FEATURE" ]] || { err "--feature is required"; usage; exit 1; }
[[ -z "$FROM_STEP" || $(is_valid_step "$FROM_STEP"; echo $?) -eq 0 ]] || { err "--from must be one of: ${ALL_STEPS[*]}"; exit 1; }
[[ -z "$ONLY_STEP" || $(is_valid_step "$ONLY_STEP"; echo $?) -eq 0 ]] || { err "--only must be one of: ${ALL_STEPS[*]}"; exit 1; }
[[ -z "$FROM_STEP" || -z "$ONLY_STEP" ]] || { err "Use either --from or --only, not both"; exit 1; }

feature_dir="$REPO_ROOT/$FEATURE"
[[ -d "$feature_dir" ]] || { err "Feature directory not found: $feature_dir"; exit 1; }
[[ -s "$REPO_ROOT/.forgeloop/memory/constitution.md" ]] || warn "No constitution found at .forgeloop/memory/constitution.md"
[[ -s "$feature_dir/spec.md" ]] || warn "No spec.md found in $FEATURE (continuing as requested)"

should_run_step() {
  local step="$1"
  if [[ -n "$ONLY_STEP" ]]; then [[ "$step" == "$ONLY_STEP" ]]; return; fi
  if [[ -z "$FROM_STEP" ]]; then return 0; fi
  local seen=0
  for s in "${ALL_STEPS[@]}"; do
    [[ "$s" == "$FROM_STEP" ]] && seen=1
    if [[ $seen -eq 1 && "$s" == "$step" ]]; then return 0; fi
  done
  return 1
}

agent_script() {
  local step="$1"; local base="$REPO_ROOT/scripts/agents/$AGENT";
  local sh="$base/${step}.sh"; local ps="$base/${step}.ps1";
  case "$SCRIPT_VARIANT" in
    ps) [[ -f "$ps" ]] && { echo "$ps"; return 0; } ;;
    *)  [[ -x "$sh" ]] && { echo "$sh"; return 0; } ;;
  esac
  # Fallback
  [[ -x "$sh" ]] && { echo "$sh"; return 0; }
  return 1
}

run_step() {
  local step="$1"; local script_path; script_path="$(agent_script "$step")" || { err "No wrapper for $AGENT/$step"; return 1; }
  local log_file="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-${AGENT}-${FEATURE}-${step}.log"

  log "→ $AGENT/$step (log: $log_file)"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "%q " "$script_path" --feature "$FEATURE" --repo-root "$REPO_ROOT"; echo
    return 0
  fi

  if [[ "$script_path" == *.ps1 ]]; then
    pwsh -NoProfile -File "$script_path" --feature "$FEATURE" --repo-root "$REPO_ROOT" 2>&1 | tee "$log_file"
  else
    "$script_path" --feature "$FEATURE" --repo-root "$REPO_ROOT" 2>&1 | tee "$log_file"
  fi

  local rc=${PIPESTATUS[0]}
  if [[ $rc -ne 0 ]]; then err "$AGENT/$step failed (exit $rc). See $log_file"; return $rc; fi
  ok "$step ok"
}

assert_file() { [[ -s "$1" ]] || { err "Missing/empty: $1"; return 1; }; }

validate_outputs() {
  local step="$1"; local d="$feature_dir"
  case "$step" in
    plan)  assert_file "$d/plan.md" ;;
    tasks) assert_file "$d/tasks.md" ;;
    implement) : ;;
  esac
}

main() {
  for step in "${ALL_STEPS[@]}"; do
    should_run_step "$step" || continue
    run_step "$step"
    validate_outputs "$step"
  done
  ok "Done. Feature: $FEATURE Agent: $AGENT"
}

main "$@"
