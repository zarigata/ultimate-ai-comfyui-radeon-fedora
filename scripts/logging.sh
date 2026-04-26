#!/usr/bin/env bash
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Placeholder logging.sh — full implementation lives in common.sh init_logging().
# This file exists for source compatibility and provides extra log utilities.

init_logging() {
    local logs_dir="$REPO_ROOT/logs"
    mkdir -p "$logs_dir"
    local ts
    ts="$(date '+%Y%m%d-%H%M%S')"
    LOG_FILE="$logs_dir/install-${ts}.log"
    ln -sf "$LOG_FILE" "$logs_dir/latest.log" 2>/dev/null || true
    touch "$LOG_FILE"
    info "Logging initialised → $LOG_FILE"
}

log_debug()  { [[ "${CONFY_VERBOSE:-0}" -eq 1 ]] && info "[DEBUG] $*"; _log_msg "DEBUG" "$@"; }
log_cmd()    { _log_msg "CMD" "$1 => exit=$2"; }
log_section(){ _log_msg "SECTION" "$*"; }
tail_log()   { local n="${1:-20}"; [[ -f "$LOG_FILE" ]] && tail -n "$n" "$LOG_FILE" || echo "No log file."; }
dump_log()   { [[ -f "$LOG_FILE" ]] && cat "$LOG_FILE" || echo "No log file."; }
