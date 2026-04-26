#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_comfyui() {
    local COMFYUI_DIR="$REPO_ROOT/ComfyUI"
    local git_url="https://github.com/comfyanonymous/ComfyUI.git"
    local env_path="$REPO_ROOT/.conda/envs/comfyui-radeon"
    local py_bin="$env_path/bin/python"
    local pip_bin="$env_path/bin/pip"

    if [[ "${CONFY_DRY_RUN:-0}" -eq 1 ]]; then
        info "DRY-RUN: Would clone ComfyUI from $git_url"
        info "DRY-RUN: Would install requirements via $pip_bin"
        info "DRY-RUN: Would verify PyTorch ROCm still active after requirements"
        return 0
    fi

    # --- Handle existing directory ---
    if [[ -d "$COMFYUI_DIR" ]]; then
        if [[ -d "$COMFYUI_DIR/.git" ]]; then
            info "ComfyUI directory exists and is a git repo — updating..."
            if git -C "$COMFYUI_DIR" pull --ff-only 2>&1; then
                success "ComfyUI updated"
            else
                warn "git pull failed (maybe diverged). Continuing with current state."
            fi
        else
            local ts
            ts="$(date '+%Y%m%d-%H%M%S')"
            local backup="ComfyUI.preclone.${ts}"
            warn "ComfyUI/ exists but is NOT a git repo — backing up to $backup"
            mv "$COMFYUI_DIR" "$REPO_ROOT/$backup"

            info "Cloning fresh ComfyUI..."
            if ! git clone "$git_url" "$COMFYUI_DIR"; then
                error "Failed to clone ComfyUI"
                return 1
            fi

            # Preserve models from backup
            if [[ -d "$REPO_ROOT/$backup/models" ]]; then
                info "Preserving your models from backup..."
                mkdir -p "$COMFYUI_DIR/models"
                cp -a "$REPO_ROOT/$backup/models/." "$COMFYUI_DIR/models/" 2>/dev/null || true
                success "Models preserved from backup"
            fi
        fi
    else
        info "Cloning ComfyUI..."
        if ! git clone "$git_url" "$COMFYUI_DIR"; then
            error "Failed to clone ComfyUI"
            return 1
        fi
        success "ComfyUI cloned"
    fi

    # --- Install requirements ---
    info "Installing ComfyUI requirements..."
    export PYTHONNOUSERSITE=1
    unset PYTHONPATH

    if [[ -x "$pip_bin" ]]; then
        if ! "$pip_bin" install -r "$COMFYUI_DIR/requirements.txt"; then
            error "Failed to install ComfyUI requirements"
            return 1
        fi
    else
        error "pip not found at $pip_bin — conda env may be broken"
        return 1
    fi
    success "ComfyUI requirements installed"

    # --- Re-verify PyTorch after requirements ---
    info "Checking if ComfyUI requirements replaced PyTorch with CPU version..."
    local torch_hip
    torch_hip="$("$py_bin" -c 'import torch; print(getattr(torch.version, "hip", "") or "")' 2>/dev/null || true)"

    if [[ -z "$torch_hip" || "$torch_hip" == "None" ]]; then
        warn "PyTorch was replaced with CPU version! Reinstalling ROCm PyTorch..."
        if [[ -f "$REPO_ROOT/scripts/install_pytorch.sh" ]]; then
            # shellcheck disable=SC1090
            source "$REPO_ROOT/scripts/install_pytorch.sh"
            install_pytorch
        else
            error "install_pytorch.sh not found — cannot auto-reinstall"
            return 1
        fi
    else
        success "PyTorch ROCm still intact (HIP=$torch_hip)"
    fi

    # --- Create model directories ---
    info "Ensuring model directories exist..."
    local models_base="$COMFYUI_DIR/models"
    local model_dirs=(
        checkpoints vae loras clip clip_vision diffusion_models
        unet controlnet upscale_models animatediff_models text_encoders
    )
    for d in "${model_dirs[@]}"; do
        mkdir -p "$models_base/$d"
    done
    success "Model directories ready"

    # --- Write installed marker ---
    local git_hash
    git_hash="$(git -C "$COMFYUI_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    cat > "$REPO_ROOT/.comfyui-installed" <<EOF
installed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
comfyui_git_hash=$git_hash
comfyui_dir=$COMFYUI_DIR
EOF
    success "ComfyUI install complete (hash: $git_hash)"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_comfyui "$@"
fi
