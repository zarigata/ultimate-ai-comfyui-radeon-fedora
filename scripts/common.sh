#!/usr/bin/env bash
# ==============================================================================
# common.sh — Shared utilities for CONFY installer scripts
# ==============================================================================
# All scripts source this file for REPO_ROOT, color output, logging, prompts,
# conda helpers, and global flag defaults.
#
# This file defines functions ONLY. It does NOT execute anything on source.
# ==============================================================================
set -o pipefail

# ---------------------------------------------------------------------------
# REPO_ROOT detection
# ---------------------------------------------------------------------------
compute_repo_root() {
    local caller="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    local dir
    dir="$(cd "$(dirname "$caller")" && pwd)"
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        if [[ -f "$dir/install.sh" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    # Fallback
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

REPO_ROOT="$(compute_repo_root)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Color support
# ---------------------------------------------------------------------------
_COLOR_SUPPORTED=0
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    _ncol="$(tput colors 2>/dev/null || echo 0)"
    [[ "$_ncol" -ge 8 ]] && _COLOR_SUPPORTED=1
fi
unset _ncol

if [[ "$_COLOR_SUPPORTED" -eq 1 ]]; then
    C_BLUE='\033[34m'  C_GREEN='\033[32m'  C_YELLOW='\033[33m'
    C_RED='\033[31m'   C_BOLD='\033[1m'    C_RESET='\033[0m'
else
    C_BLUE=''  C_GREEN=''  C_YELLOW=''  C_RED=''  C_BOLD=''  C_RESET=''
fi

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
info()    { printf "${C_BLUE}[INFO]${C_RESET}  %s\n" "$*" >&2; }
warn()    { printf "${C_YELLOW}[WARN]${C_RESET}  %s\n" "$*" >&2; }
error()   { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*" >&2; }
success() { printf "${C_GREEN}[OK]${C_RESET}    %s\n" "$*" >&2; }
step()    { printf "${C_BLUE}  → %s${C_RESET}\n" "$*" >&2; }

section() {
    local title="$*"
    if [[ "$_COLOR_SUPPORTED" -eq 1 ]]; then
        printf "\n${C_BOLD}${C_BLUE}══════════════════════════════════════════════════\n"
        printf "  %s\n" "$title"
        printf "══════════════════════════════════════════════════${C_RESET}\n"
    else
        printf "\n====== %s ======\n" "$title"
    fi
}

# ---------------------------------------------------------------------------
# Global flags (defaults — overridden by install.sh flag parser)
# ---------------------------------------------------------------------------
CONFY_NONINTERACTIVE="${CONFY_NONINTERACTIVE:-0}"
CONFY_AGGRESSIVE="${CONFY_AGGRESSIVE:-0}"
CONFY_ALLOW_ERASING="${CONFY_ALLOW_ERASING:-0}"
CONFY_DRY_RUN="${CONFY_DRY_RUN:-0}"
CONFY_VERBOSE="${CONFY_VERBOSE:-0}"
CONFY_BACKEND="${CONFY_BACKEND:-bare-metal}"       # bare-metal | container
CONFY_TORCH_SOURCE="${CONFY_TORCH_SOURCE:-}"        # amd | pytorch | ""
CONFY_PYTHON_VERSION="${CONFY_PYTHON_VERSION:-3.12}"
CONFY_MODEL_TIER="${CONFY_MODEL_TIER:-}"            # low-vram | mid-vram | high-vram
CONFY_SKIP_MODELS="${CONFY_SKIP_MODELS:-0}"
CONFY_DISABLE_PROBLEM_REPOS="${CONFY_DISABLE_PROBLEM_REPOS:-0}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_FILE="${LOG_FILE:-}"

init_logging() {
    local logs_dir="$REPO_ROOT/logs"
    mkdir -p "$logs_dir"
    local ts
    ts="$(date '+%Y%m%d-%H%M%S')"
    LOG_FILE="$logs_dir/install-${ts}.log"
    ln -sf "$LOG_FILE" "$logs_dir/latest.log" 2>/dev/null || true
    touch "$LOG_FILE"
    _log_msg "INFO" "Logging initialised → $LOG_FILE"
}

_log_msg() {
    local level="$1"; shift
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$LOG_FILE" ]] && printf "[%s] [%s] %s\n" "$ts" "$level" "$*" >> "$LOG_FILE"
}

log_debug() { [[ "${CONFY_VERBOSE:-0}" -eq 1 ]] && info "[DEBUG] $*"; _log_msg "DEBUG" "$@"; }
log_cmd()   { local ec="$2"; _log_msg "CMD" "$1 => exit=$ec"; }
log_section() { _log_msg "SECTION" "$*"; }

tail_log() { local n="${1:-20}"; [[ -f "$LOG_FILE" ]] && tail -n "$n" "$LOG_FILE" || echo "No log file."; }
dump_log()  { [[ -f "$LOG_FILE" ]] && cat "$LOG_FILE" || echo "No log file."; }

# ---------------------------------------------------------------------------
# Prompt helpers
# ---------------------------------------------------------------------------
ask_yes_no() {
    local question="$1"
    local default="${2:-default_y}"
    if [[ "${CONFY_NONINTERACTIVE:-0}" -eq 1 ]]; then
        [[ "$default" == "default_y" ]] && return 0 || return 1
    fi
    local prompt_hint
    if [[ "$default" == "default_y" ]]; then prompt_hint="[Y/n]"; else prompt_hint="[y/N]"; fi
    while true; do
        printf "%s %s " "$question" "$prompt_hint" >&2
        local ans=""
        read -r ans
        ans="${ans:-}"
        case "$ans" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo])     return 1 ;;
            "")
                [[ "$default" == "default_y" ]] && return 0 || return 1
                ;;
            *) echo "Please answer yes or no." >&2 ;;
        esac
    done
}

ask_continue() {
    local message="$1"
    [[ "${CONFY_NONINTERACTIVE:-0}" -eq 1 ]] && return 0
    echo "$message"
    echo "Press Enter to continue or Ctrl+C to abort..."
    read -r
}

ask_scary() {
    local message="$1"
    if [[ "${CONFY_NONINTERACTIVE:-0}" -eq 1 ]]; then
        [[ "${CONFY_AGGRESSIVE:-0}" -eq 1 ]] && return 0 || return 1
    fi
    echo ""
    echo "⚠️  ${C_RED}${C_BOLD}WARNING: ${message}${C_RESET}"
    echo ""
    printf 'Type "YES I UNDERSTAND" to proceed: '
    local ans=""
    read -r ans
    [[ "$ans" == "YES I UNDERSTAND" ]] && return 0
    return 1
}

require_confirmation() {
    local action_desc="$1"
    info "About to perform: $action_desc"
    ask_yes_no "Proceed?" default_n
}

# ---------------------------------------------------------------------------
# Command wrappers
# ---------------------------------------------------------------------------
run_cmd() {
    local cmd_str="$*"
    info "Executing: $cmd_str"
    _log_msg "CMD" "$cmd_str"
    "$@"
    local ec=$?
    log_cmd "$cmd_str" "$ec"
    return "$ec"
}

run_sudo() {
    local cmd_str="sudo $*"
    warn "Executing with sudo: $cmd_str"
    _log_msg "SUDO" "$cmd_str"
    sudo "$@"
    local ec=$?
    log_cmd "$cmd_str" "$ec"
    return "$ec"
}

safe_rm() {
    local target="$1"
    if [[ -e "$target" ]]; then
        local backup_dir="$REPO_ROOT/.backup"
        mkdir -p "$backup_dir"
        local ts
        ts="$(date '+%Y%m%d-%H%M%S')"
        local dest="$backup_dir/$(basename "$target").${ts}"
        mv -- "$target" "$dest"
        info "Moved $target → $dest"
    else
        warn "safe_rm: path does not exist: $target"
    fi
}

# ---------------------------------------------------------------------------
# Conda helpers
# ---------------------------------------------------------------------------
CONDA_SH="$REPO_ROOT/.miniforge/etc/profile.d/conda.sh"
CONDA_ENV_PATH="$REPO_ROOT/.conda/envs/comfyui-radeon"

conda_activate() {
    if [[ ! -f "$CONDA_SH" ]]; then
        error "conda.sh not found at $CONDA_SH"
        return 1
    fi
    # shellcheck disable=SC1090
    source "$CONDA_SH"
    conda activate "$CONDA_ENV_PATH"
    export PYTHONNOUSERSITE=1
    unset PYTHONPATH
    return 0
}

conda_bin() { echo "$CONDA_ENV_PATH/bin"; }

is_conda_ready() {
    [[ -f "$REPO_ROOT/.miniforge/bin/conda" ]] && [[ -d "$CONDA_ENV_PATH" ]]
}

# ---------------------------------------------------------------------------
# Version helpers
# ---------------------------------------------------------------------------
version_gte() {
    # version_gte "1.2.3" "1.1.0" → true (1.2.3 >= 1.1.0)
    local a="${1#v}" b="${2#v}"
    [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n1)" == "$b" ]]
}

parse_os_release() {
    if [[ -f /etc/os-release ]]; then
        # Parse safely without sourcing (avoid variable injection)
        OS_ID="$(grep '^ID=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')"
        OS_VERSION_ID="$(grep '^VERSION_ID=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')"
        OS_NAME="$(grep '^NAME=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')"
        OS_PRETTY_NAME="$(grep '^PRETTY_NAME=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')"
        OS_ID_LIKE="$(grep '^ID_LIKE=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')"
    else
        OS_ID="" OS_VERSION_ID="" OS_NAME="" OS_PRETTY_NAME="" OS_ID_LIKE=""
    fi
    export OS_ID OS_VERSION_ID OS_NAME OS_PRETTY_NAME OS_ID_LIKE
}
