#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

generate_run_sh() {
    # Ensure run.sh exists and is executable (don't overwrite our good one)
    if [[ -f "$REPO_ROOT/run.sh" ]]; then
        chmod +x "$REPO_ROOT/run.sh"
        success "run.sh is present and executable"
    else
        error "run.sh not found at $REPO_ROOT/run.sh"
        return 1
    fi

    # Ensure doctor.sh and repair.sh are executable
    chmod +x "$REPO_ROOT/doctor.sh" "$REPO_ROOT/repair.sh" "$REPO_ROOT/uninstall.sh" 2>/dev/null || true

    # Write HSA override if detected during install
    if [[ -n "${HSA_OVERRIDE_GFX_VERSION:-}" ]]; then
        echo "$HSA_OVERRIDE_GFX_VERSION" > "$REPO_ROOT/.hsa-override"
        info "Wrote HSA_OVERRIDE_GFX_VERSION=$HSA_OVERRIDE_GFX_VERSION to .hsa-override"
    fi

    # Create input/output directories
    mkdir -p "$REPO_ROOT/input" "$REPO_ROOT/output"

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_run_sh "$@"
fi
