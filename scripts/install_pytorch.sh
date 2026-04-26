#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_pytorch() {
    local env_path="$REPO_ROOT/.conda/envs/comfyui-radeon"
    local py_bin="$env_path/bin/python"
    local ROCM_VER="${CONFY_ROCM_VERSION:-6.3}"

    if [[ "${CONFY_DRY_RUN:-0}" -eq 1 ]]; then
        info "DRY-RUN: Would install PyTorch ROCm $ROCM_VER"
        info "DRY-RUN: Strategy order based on CONFY_TORCH_SOURCE=${CONFY_TORCH_SOURCE:-auto}"
        return 0
    fi

    if [[ "${CONFY_BACKEND:-}" == "container" ]]; then
        info "Container backend selected — skipping bare-metal PyTorch install."
        info "Use the ROCm PyTorch container as documented."
        return 2
    fi

    if [[ ! -x "$py_bin" ]]; then
        error "Python not found at $py_bin — run install_conda first"
        return 1
    fi

    # Activate env for pip
    export PYTHONNOUSERSITE=1
    unset PYTHONPATH

    local torch_source="${CONFY_TORCH_SOURCE:-}"

    # Determine strategy order
    local try_amd=0 try_pytorch=0
    if [[ "$torch_source" == "amd" ]]; then
        try_amd=1; try_pytorch=1
    elif [[ "$torch_source" == "pytorch" ]]; then
        try_pytorch=1; try_amd=1
    else
        try_amd=1; try_pytorch=1
    fi

    _verify_torch() {
        local hip_ver
        hip_ver="$("$py_bin" -c "import torch; print(torch.version.hip or '')" 2>/dev/null || true)"
        if [[ -n "$hip_ver" && "$hip_ver" != "None" ]]; then
            local torch_ver
            torch_ver="$("$py_bin" -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")"
            success "PyTorch $torch_ver with HIP $hip_ver installed"
            printf "TORCH_VERSION=%s\nTORCH_SOURCE=%s\nTORCH_ROCM_VERSION=%s\n" \
                "$torch_ver" "$1" "$ROCM_VER" > "$REPO_ROOT/.torch-version"
            return 0
        fi
        return 1
    }

    _reinstall_torch_from() {
        local index_url="$1"
        local label="$2"
        info "Installing PyTorch from $label..."
        if "$py_bin" -m pip install --force-reinstall torch torchvision torchaudio --index-url "$index_url" 2>&1 | tail -5; then
            if _verify_torch "$label"; then
                return 0
            fi
        fi
        return 1
    }

    # Strategy A: AMD Radeon wheels
    if [[ "$try_amd" -eq 1 ]]; then
        info "Strategy A: Trying AMD wheels from repo.radeon.com (rocm-rel-${ROCM_VER})..."
        local amd_url="https://repo.radeon.com/rocm/manylinux/rocm-rel-${ROCM_VER}/"
        if "$py_bin" -m pip install torch torchvision torchaudio --find-links "$amd_url" 2>&1 | tail -5; then
            if _verify_torch "amd"; then
                return 0
            fi
        fi
        warn "Strategy A (AMD wheels) did not produce a working ROCm PyTorch."
    fi

    # Strategy B: PyTorch official ROCm wheels
    if [[ "$try_pytorch" -eq 1 ]]; then
        info "Strategy B: Trying PyTorch official ROCm wheels (rocm${ROCM_VER})..."
        local pt_url="https://download.pytorch.org/whl/rocm${ROCM_VER}"

        if _reinstall_torch_from "$pt_url" "pytorch-rocm${ROCM_VER}"; then
            return 0
        fi

        # Fallback: try rocm6.2.4
        if [[ "$ROCM_VER" != "6.2.4" ]]; then
            warn "Trying fallback: rocm6.2.4 wheels..."
            local pt_fallback="https://download.pytorch.org/whl/rocm6.2.4"
            if _reinstall_torch_from "$pt_fallback" "pytorch-rocm6.2.4"; then
                return 0
            fi
        fi
        warn "Strategy B (PyTorch official ROCm) also failed."
    fi

    # Strategy C: Container fallback
    error "Both PyTorch install strategies failed."
    info ""
    info "Container fallback (Strategy C):"
    info "  Use Podman/Docker with the official ROCm PyTorch image."
    info "  podman run -it --device=/dev/kfd --device=/dev/dri \\"
    info "    rocm/pytorch:latest"
    info ""
    info "Or re-run with: ./install.sh --backend container"
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_pytorch "$@"
fi
