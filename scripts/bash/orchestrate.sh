#!/usr/bin/env bash
  set -euo pipefail

  # Orchestrate ForgeLoop steps across agents.

  # Usage:

  # scripts/orchestrate.sh --agent codex --feature 001-demo [--from plan|tasks|implement] [--only step] [--dry-run]

  # Steps: constitution -> specify -> plan -> tasks -> implement

  # Defaults

  AGENT="codex"
  FEATURE=""
  FROM_STEP=""
  ONLY_STEP=""
  DRY_RUN=0
  SCRIPT_VARIANT="${SCRIPT_VARIANT:-sh}"  # sh|ps (for agent wrappers that support both)

  # Resolve repo root (assumes script lives under scripts/)

  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  LOG_DIR="$REPO_ROOT/.forgeloop/logs"
  mkdir -p "$LOG_DIR"

  # Colored log helpers

  log()  { printf "%b\n" "$*" >&2; }
  ok()   { log "\033[32m✔\033[0m $"; }
  warn() { log "\033[33m⚠\033[0m $*"; }
  err()  { log "\033[31m✖ $\033[0m"; }

  usage() {
  cat >&2 <<EOF
  Orchestrate ForgeLoop steps

  Required:
  --agent <name>       One of: codex, claude, gemini, cursor-agent, qwen, opencode, windsurf, kilocode, auggie, roo, codebuddy, amp, shai, q
  --feature <name>     Feature folder name (e.g., 001-photo-albums)

  Optional:
  --from <step>        Start from step (constitution|specify|plan|tasks|implement)
  --only <step>        Run only a single step
  --dry-run            Print what would run without executing
  --variant <sh|ps>    Script variant for agent wrappers (default: sh)

  Examples:
  scripts/orchestrate.sh --agent codex --feature 001-demo
  scripts/orchestrate.sh --agent codex --feature 001-demo --from plan
  scripts/orchestrate.sh --agent codex --feature 001-demo --only tasks
  EOF
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

  # Validate steps

  ALL_STEPS=(constitution specify plan tasks implement)
  is_valid_step() {
  local s="$1"
  for x in "${ALL_STEPS[@]}"; do [[ "$s" == "$x" ]] && return 0; done
  return 1
  }
  if [[ -n "$FROM_STEP" ]] && ! is_valid_step "$FROM_STEP"; then
  err "--from must be one of: ${ALL_STEPS[*]}"; exit 1
  fi
  if [[ -n "$ONLY_STEP" ]] && ! is_valid_step "$ONLY_STEP"; then
  err "--only must be one of: ${ALL_STEPS[]}"; exit 1
  fi
  if [[ -n "$FROM_STEP" && -n "$ONLY_STEP" ]]; then
  err "Use either --from or --only, not both"; exit 1
  fi

  # Step ordering and gating

  should_run_step() {
  local step="$1"
  if [[ -n "$ONLY_STEP" ]]; then
  [[ "$step" == "$ONLY_STEP" ]]; return
  fi
  if [[ -z "$FROM_STEP" ]]; then
  return 0
  fi

  # Allow running from FROM_STEP forward

  local seen=0
  for s in "${ALL_STEPS[@]}"; do
  [[ "$s" == "$FROM_STEP" ]] && seen=1
  if [[ $seen -eq 1 && "$s" == "$step" ]]; then return 0; fi
  done
  return 1
  }

  # Resolve agent wrapper for a given step

  agent_script() {
  local step="$1"
  local base="$REPO_ROOT/scripts/agents/$AGENT"
  local sh="$base/${step}.sh"
  local ps="$base/${step}.ps1"
  case "$SCRIPT_VARIANT" in
  sh)  [[ -x "$sh" ]] && { echo "$sh"; return 0; } ;;
  ps)  [[ -f "$ps" ]] && { echo "$ps"; return 0; } ;;
  esac

  # Fallback: try sh script if ps not present

  [[ -x "$sh" ]] && { echo "$sh"; return 0; }
  return 1
  }

  # Validate environment for selected agent (example for Codex)

  prepare_env() {
  case "$AGENT" in
  codex)
  # Require CODEX_HOME or derive from project root
  if [[ -z "${CODEX_HOME:-}" ]]; then
  local codex_dir="$REPO_ROOT/.codex"
  export CODEX_HOME="$codex_dir"
  warn "CODEX_HOME not set; using $CODEX_HOME"
  fi
  ;;
  *) ;;
  esac
  }

  # Execute a single step

  run_step() {
  local step="$1"
  local script_path
  script_path="$(agent_script "$step")" || { err "No wrapper for $AGENT/$step"; return 1; }

  local log_file="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-${AGENT}-${FEATURE}-${step}.log"
  local cmd=("$script_path" "--feature" "$FEATURE" "--repo-root" "$REPO_ROOT")

  log "→ Running $AGENT/$step (log: $log_file)"
  if [[ $DRY_RUN -eq 1 ]]; then
  printf "%q " "${cmd[@]}"; echo
  return 0
  fi

  if [[ "$script_path" == *.ps1 ]]; then
  # Execute PowerShell wrapper
  pwsh -NoProfile -File "$script_path" --feature "$FEATURE" --repo-root "$REPO_ROOT" 2>&1 | tee "$log_file"
  else
  # Execute shell wrapper
  "${cmd[@]}" 2>&1 | tee "$log_file"
  fi

  local rc=${PIPESTATUS[0]}
  if [[ $rc -ne 0 ]]; then
  err "$AGENT/$step failed (exit $rc). See $log_file"
  return $rc
  fi

  ok "$AGENT/$step ok"
  return 0
  }

  # Preconditions for files (basic contract)

  assert_file() {
  local f="$1"; [[ -s "$f" ]] || { err "Missing/empty: $f"; return 1; }
  }

  validate_outputs() {
  local step="$1"
  local feature_dir="$REPO_ROOT/$FEATURE"
  case "$step" in
  constitution) assert_file "$REPO_ROOT/.forgeloop/memory/constitution.md" ;;
  specify)      assert_file "$feature_dir/spec.md" ;;
  plan)         assert_file "$feature_dir/plan.md" ;;
  tasks)        assert_file "$feature_dir/tasks.md" ;;
  implement)    : ;; # optional: check a build, test, or summary file
  esac
  }

  main() {
  prepare_env

  for step in "${ALL_STEPS[@]}"; do
  should_run_step "$step" || continue
  run_step "$step"
  validate_outputs "$step"
  done

  ok "Done. Feature: $FEATURE Agent: $AGENT"
  }

  main "$@"

  Agent wrappers (example stub)

  - scripts/agents/codex/specify.sh

  #!/usr/bin/env bash
  set -euo pipefail

  # Args: --feature <name> --repo-root <path>

  FEATURE=""; REPO_ROOT=""
  while [[ $# -gt 0 ]]; do
  case "$1" in
  --feature) FEATURE="$2"; shift 2;;
  --repo-root) REPO_ROOT="$2"; shift 2;;
  *) shift;;
  esac
  done
  : "${FEATURE:?feature required}" "${REPO_ROOT:?repo root required}"

  PROMPT="$REPO_ROOT/.codex/prompts/forgeloop.specify.md"
  OUT_DIR="$REPO_ROOT/$FEATURE"
  mkdir -p "$OUT_DIR"

  # Example: replace this with your Codex CLI invocation

  # codex run --prompt "$PROMPT" --out "$OUT_DIR/spec.md" --context "$REPO_ROOT/.forgeloop"

  echo "# Spec for $FEATURE" > "$OUT_DIR/spec.md"

  echo "specify done"