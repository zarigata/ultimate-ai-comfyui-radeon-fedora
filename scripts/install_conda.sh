#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_conda() {
    local miniforge_dir="$REPO_ROOT/.miniforge"
    local installer="$REPO_ROOT/.miniforge-installer.sh"
    local env_path="$REPO_ROOT/.conda/envs/comfyui-radeon"
    local py_ver="${CONFY_PYTHON_VERSION:-3.12}"
    local installer_url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"

    if [[ "${CONFY_DRY_RUN:-0}" -eq 1 ]]; then
        info "DRY-RUN: Would download Miniforge from $installer_url"
        info "DRY-RUN: Would install to $miniforge_dir"
        info "DRY-RUN: Would create env at $env_path with python=$py_ver"
        return 0
    fi

    # Already installed?
    if [[ -x "$miniforge_dir/bin/conda" ]]; then
        success "Miniforge already installed at $miniforge_dir"
        # Ensure env exists
        if [[ -d "$env_path" ]]; then
            success "Conda env already exists at $env_path"
            return 0
        fi
    fi

    # Download
    if [[ ! -x "$miniforge_dir/bin/conda" ]]; then
        info "Downloading Miniforge installer..."
        if ! curl -fsSL -o "$installer" "$installer_url"; then
            error "Failed to download Miniforge installer from $installer_url"
            return 1
        fi
        if [[ ! -s "$installer" ]]; then
            error "Downloaded installer is empty"
            return 1
        fi
        success "Miniforge installer downloaded ($(du -h "$installer" | cut -f1))"

        info "Running Miniforge installer (batch mode)..."
        if ! bash "$installer" -b -p "$miniforge_dir"; then
            error "Miniforge installer failed"
            rm -f "$installer"
            return 1
        fi
        rm -f "$installer"
        success "Miniforge installed at $miniforge_dir"

        info "NOT modifying your ~/.bashrc — scripts use inline activation."
    fi

    # Create env
    if [[ ! -d "$env_path" ]]; then
        info "Creating conda env: comfyui-radeon (python=$py_ver)..."
        if ! "$miniforge_dir/bin/conda" create -y -p "$env_path" "python=$py_ver"; then
            warn "Failed with python=$py_ver, trying without pinned version..."
            if ! "$miniforge_dir/bin/conda" create -y -p "$env_path" python; then
                error "Failed to create conda environment"
                return 1
            fi
        fi
        success "Conda env created at $env_path"
    fi

    # Verify
    local py_bin="$env_path/bin/python"
    if [[ -x "$py_bin" ]]; then
        local actual_ver
        actual_ver="$("$py_bin" --version 2>&1 || echo "unknown")"
        success "Python in env: $actual_ver"
        info "Python path: $py_bin"
    else
        error "Python binary not found at $py_bin"
        return 1
    fi

    # Configure conda channels
    "$miniforge_dir/bin/conda" config --add channels conda-forge 2>/dev/null || true
    "$miniforge_dir/bin/conda" config --set channel_priority strict 2>/dev/null || true

    success "Conda setup complete"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_conda "$@"
fi
