#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DEFAULT_CUSTOM_NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git"
    "https://github.com/Kosinkadink/ComfyUI-Frame-Interpolation.git"
    "https://github.com/kijai/ComfyUI-KJNodes.git"
)

install_custom_nodes() {
    local CUSTOM_NODES_ROOT="$REPO_ROOT/ComfyUI/custom_nodes"
    mkdir -p "$CUSTOM_NODES_ROOT"

    # Build node list (allow CUSTOM_NODES env var to extend)
    local -a nodes=("${DEFAULT_CUSTOM_NODES[@]}")
    if [[ -n "${CUSTOM_NODES:-}" ]]; then
        local extra
        while IFS= read -r extra; do
            [[ -n "$extra" ]] && nodes+=("$extra")
        done <<< "$CUSTOM_NODES"
    fi

    local installed=0 updated=0

    for url in "${nodes[@]}"; do
        [[ -z "$url" ]] && continue
        local repo_name="${url##*/}"
        local name="${repo_name%.git}"
        local dest="$CUSTOM_NODES_ROOT/$name"

        info "Processing: $name"

        if [[ -d "$dest/.git" ]]; then
            if git -C "$dest" pull --ff-only 2>&1; then
                updated=$((updated+1))
            else
                warn "Failed to update $name"
            fi
            continue
        fi

        if [[ -d "$dest" ]]; then
            warn "$name exists but is not a git repo — skipping"
            continue
        fi

        if git clone "$url" "$dest" 2>&1; then
            installed=$((installed+1))
            success "Cloned $name"
        else
            warn "Failed to clone $name"
        fi
    done

    # Install requirements for each node
    local py_bin="$REPO_ROOT/.conda/envs/comfyui-radeon/bin/python"
    if [[ -x "$py_bin" ]]; then
        for dir in "$CUSTOM_NODES_ROOT"/*/; do
            [[ -d "$dir" && -f "$dir/requirements.txt" ]] || continue
            local node_name="${dir%/}"
            node_name="${node_name##*/}"
            info "Installing requirements for $node_name"
            "$py_bin" -m pip install -r "$dir/requirements.txt" 2>&1 || warn "Failed: $node_name requirements"

            # Verify torch still has HIP
            local torch_hip
            torch_hip="$("$py_bin" -c "import torch; print(torch.version.hip or '')" 2>/dev/null || true)"
            if [[ -z "$torch_hip" || "$torch_hip" == "None" ]]; then
                warn "PyTorch was replaced with CPU version after installing $node_name requirements!"
                if [[ -f "$REPO_ROOT/scripts/install_pytorch.sh" ]]; then
                    source "$REPO_ROOT/scripts/install_pytorch.sh"
                    install_pytorch
                fi
            fi
        done
    fi

    info "Custom nodes: $installed installed, $updated updated"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_custom_nodes "$@"
fi
