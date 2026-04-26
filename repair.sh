#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

if [[ -f "$SCRIPT_DIR/scripts/repair_missing_so.sh" ]]; then
    source "$SCRIPT_DIR/scripts/repair_missing_so.sh"
fi

section "Repair"

# Run diagnostics first
info "Running diagnostics to identify issues..."
ISSUES_BEFORE=0

if [[ -x "$SCRIPT_DIR/doctor.sh" ]]; then
    "$SCRIPT_DIR/doctor.sh" 2>&1 | tee /tmp/confy-doctor-output.txt || true
    ISSUES_BEFORE="$(grep -c 'NOT\|missing\|WARNING\|ERROR' /tmp/confy-doctor-output.txt 2>/dev/null || echo "0")"
fi

REPAIRED=0

# Repair missing shared libraries
if declare -f repair_missing_so &>/dev/null; then
    info "Checking for missing shared libraries..."
    if repair_missing_so; then
        success "Shared library repair completed"
        REPAIRED=$((REPAIRED+1))
    else
        warn "Some shared libraries could not be repaired"
    fi
else
    warn "repair_missing_so function not available"
fi

# Check conda env
if [[ ! -d "$SCRIPT_DIR/.conda/envs/comfyui-radeon" ]]; then
    warn "Conda env missing"
    if ask_yes_no "Recreate conda environment?" "default_y"; then
        source "$SCRIPT_DIR/scripts/install_conda.sh"
        install_conda
        REPAIRED=$((REPAIRED+1))
    fi
fi

# Check PyTorch
py_bin="$SCRIPT_DIR/.conda/envs/comfyui-radeon/bin/python"
if [[ -x "$py_bin" ]]; then
    torch_hip="$("$py_bin" -c "import torch; print(torch.version.hip or '')" 2>/dev/null || true)"
    if [[ -z "$torch_hip" || "$torch_hip" == "None" ]]; then
        warn "PyTorch has no HIP/ROCm support"
        if ask_yes_no "Reinstall PyTorch with ROCm?" "default_y"; then
            source "$SCRIPT_DIR/scripts/install_pytorch.sh"
            install_pytorch
            REPAIRED=$((REPAIRED+1))
        fi
    fi
fi

# Check ComfyUI
if [[ ! -d "$SCRIPT_DIR/ComfyUI" ]]; then
    warn "ComfyUI directory missing"
    if ask_yes_no "Clone ComfyUI?" "default_y"; then
        source "$SCRIPT_DIR/scripts/install_comfyui.sh"
        install_comfyui
        REPAIRED=$((REPAIRED+1))
    fi
fi

# Re-run diagnostics
section "Post-Repair Check"
if [[ -x "$SCRIPT_DIR/doctor.sh" ]]; then
    if "$SCRIPT_DIR/doctor.sh"; then
        success "All issues resolved"
    else
        warn "Some issues remain — check the output above"
    fi
fi

echo ""
info "Repaired $REPAIRED issue(s)"
rm -f /tmp/confy-doctor-output.txt
