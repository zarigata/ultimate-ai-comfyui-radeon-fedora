#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

verify_runtime() {
    local conda_env_path="$REPO_ROOT/.conda/envs/comfyui-radeon"
    local py_bin="$conda_env_path/bin/python"
    local all_ok=1

    # Check conda env
    if [[ -d "$conda_env_path" && -x "$py_bin" ]]; then
        success "Conda env exists: $conda_env_path"
    else
        error "Conda env missing or broken at $conda_env_path"
        all_ok=0
    fi

    # Check PYTHONNOUSERSITE
    if [[ "${PYTHONNOUSERSITE:-}" == "1" ]]; then
        success "PYTHONNOUSERSITE=1 (isolated)"
    else
        warn "PYTHONNOUSERSITE not set — Python may pick up system packages"
        all_ok=0
    fi

    # Check PYTHONPATH
    if [[ -z "${PYTHONPATH:-}" ]]; then
        success "PYTHONPATH is unset (clean)"
    else
        warn "PYTHONPATH is set: $PYTHONPATH"
        all_ok=0
    fi

    # Set LD_LIBRARY_PATH for torch libs
    local torch_lib="$conda_env_path/lib/python3.12/site-packages/torch/lib"
    if [[ -d "$torch_lib" ]]; then
        export LD_LIBRARY_PATH="$torch_lib:${LD_LIBRARY_PATH:-}"
    fi

    # Run GPU verification
    if [[ -x "$py_bin" ]]; then
        info "Running GPU verification..."
        if "$py_bin" "$REPO_ROOT/scripts/verify_gpu.py"; then
            success "All GPU checks passed"
        else
            warn "GPU verification had failures"
            if ask_yes_no "Run repair for missing libraries?" "default_y"; then
                source "$REPO_ROOT/scripts/repair_missing_so.sh"
                repair_missing_so
            fi
            all_ok=0
        fi
    else
        warn "Cannot run GPU verification — python not in conda env"
        all_ok=0
    fi

    # Check ComfyUI
    if [[ -d "$REPO_ROOT/ComfyUI" ]]; then
        success "ComfyUI directory present"
    else
        error "ComfyUI directory missing"
        all_ok=0
    fi

    # Check model dirs
    local models_ok=1
    for d in checkpoints vae loras; do
        if [[ -d "$REPO_ROOT/ComfyUI/models/$d" ]]; then
            success "Model dir exists: $d/"
        else
            warn "Model dir missing: $d/"
            models_ok=0
        fi
    done
    [[ "$models_ok" -eq 1 ]] || all_ok=0

    # Check run.sh
    if [[ -x "$REPO_ROOT/run.sh" ]]; then
        success "run.sh is executable"
    else
        error "run.sh missing or not executable"
        all_ok=0
    fi

    # Final verdict
    if [[ "$all_ok" -eq 1 ]]; then
        success "System is READY"
        return 0
    else
        warn "System has ISSUES — run ./doctor.sh for details"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_runtime "$@"
fi
