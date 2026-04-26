#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

detect_gpu() {
    section "GPU Detection"

    GPU_NAME="Unknown"
    GPU_ARCH="UNKNOWN"
    GPU_GFX=""
    GPU_PCI_ID=""
    GPU_VRAM_TIER="unknown"
    GPU_ROCM_SUPPORTED=0
    NEEDS_REBOOT=0
    HSA_OVERRIDE_GFX_VERSION=""

    # --- /dev/kfd ---
    if [[ ! -e /dev/kfd ]]; then
        warn "No /dev/kfd found — AMD kernel driver may not be loaded or no AMD GPU present."
    else
        success "/dev/kfd present"
    fi

    # --- render nodes ---
    local render_nodes=()
    if ls /dev/dri/renderD* &>/dev/null; then
        render_nodes=(/dev/dri/renderD*)
        success "Render nodes: ${render_nodes[*]}"
    else
        warn "No /dev/dri/renderD* nodes found — GPU rendering may fail."
    fi

    # --- rocminfo ---
    if command -v rocminfo &>/dev/null; then
        local rocminfo_out
        rocminfo_out="$(rocminfo 2>/dev/null || true)"
        if [[ -n "$rocminfo_out" ]]; then
            local gfx_line
            gfx_line="$(echo "$rocminfo_out" | grep -oE 'gfx[0-9]+' | head -1 || true)"
            if [[ -n "$gfx_line" ]]; then
                GPU_GFX="$gfx_line"
                GPU_ARCH="$gfx_line"
                success "rocminfo reports architecture: $GPU_GFX"
            fi
            local dev_name
            dev_name="$(echo "$rocminfo_out" | grep -A1 'Device Type:' | grep 'Name:' | head -1 | sed 's/.*Name: *//' || true)"
            [[ -n "$dev_name" ]] && GPU_NAME="$dev_name"
        fi
    else
        warn "rocminfo not found — install it for better GPU detection."
    fi

    # --- lspci ---
    if command -v lspci &>/dev/null; then
        local lspci_line
        lspci_line="$(lspci -nn 2>/dev/null | grep -iE 'vga|display|3d|amd|radeon' | head -1 || true)"
        if [[ -n "$lspci_line" ]]; then
            info "lspci: $lspci_line"
            GPU_PCI_ID="$(echo "$lspci_line" | grep -oE '\[([0-9a-f]{4}:[0-9a-f]{4})\]' | tr -d '[]' || true)"
            if [[ "$GPU_NAME" == "Unknown" ]]; then
                GPU_NAME="$(echo "$lspci_line" | sed 's/.*: *//' | sed 's/ \[.*//')"
            fi
        fi
    fi

    # --- /sys/class/drm ---
    for card in /sys/class/drm/card*/device/uevent; do
        if [[ -f "$card" ]]; then
            local pci_line
            pci_line="$(grep 'PCI_ID=' "$card" 2>/dev/null | cut -d= -f2 || true)"
            if [[ -n "$pci_line" && -z "$GPU_PCI_ID" ]]; then
                GPU_PCI_ID="$pci_line"
            fi
        fi
    done

    # --- vulkaninfo ---
    if command -v vulkaninfo &>/dev/null; then
        if vulkaninfo --summary 2>/dev/null | grep -qi "amd"; then
            info "vulkaninfo confirms AMD GPU present"
        fi
    fi

    # --- Classify GPU into VRAM tier ---
    case "$GPU_GFX" in
        gfx1100) GPU_VRAM_TIER="high-vram"; GPU_NAME="${GPU_NAME/Radeon/Radeon} RX 7900 XTX/XT" ;;
        gfx1101) GPU_VRAM_TIER="mid-vram" ;;
        gfx1102) GPU_VRAM_TIER="mid-vram" ;;
        gfx1150) GPU_VRAM_TIER="high-vram" ;;
        gfx1200) GPU_VRAM_TIER="high-vram" ;;
        gfx1201) GPU_VRAM_TIER="high-vram" ;;
        gfx1030) GPU_VRAM_TIER="high-vram" ;;
        gfx1031) GPU_VRAM_TIER="mid-vram" ;;
        gfx1032) GPU_VRAM_TIER="low-vram" ;;
        *)
            if [[ "$GPU_GFX" == gfx* ]]; then
                warn "Unrecognised GFX architecture: $GPU_GFX"
                warn "You may need HSA_OVERRIDE_GFX_VERSION or a container fallback."
            fi
            ;;
    esac

    # --- ROCm compatibility ---
    case "$GPU_GFX" in
        gfx1030|gfx1031|gfx1032|gfx1100|gfx1101|gfx1102|gfx1150|gfx1200|gfx1201)
            GPU_ROCM_SUPPORTED=1
            ;;
        *)
            if [[ "$GPU_GFX" == gfx* ]]; then
                GPU_ROCM_SUPPORTED=0
                warn "Architecture $GPU_GFX is NOT officially ROCm-supported."
                info "Options:"
                info "  1) Try with HSA_OVERRIDE_GFX_VERSION (may work for similar arch)"
                info "  2) Use CPU-only mode"
                info "  3) Use container fallback"
                if ask_yes_no "Try with HSA_OVERRIDE_GFX_VERSION?" "default_n"; then
                    info "You can set HSA_OVERRIDE_GFX_VERSION manually later."
                    info "Common values: gfx1030 for RDNA2, gfx1100 for RDNA3"
                fi
            fi
            ;;
    esac

    # --- User groups ---
    local need_render=0 need_video=0
    if ! groups "$(whoami)" 2>/dev/null | grep -qw "render"; then need_render=1; fi
    if ! groups "$(whoami)" 2>/dev/null | grep -qw "video"; then need_video=1; fi

    if [[ "$need_render" -eq 1 || "$need_video" -eq 1 ]]; then
        warn "User '$(whoami)' is missing groups: $( (( need_render )) && echo -n "render " ) $( (( need_video )) && echo -n "video" )"
        if ask_yes_no "Add user to render,video groups? (requires sudo)" "default_y"; then
            run_sudo usermod -a -G render,video "$(whoami)"
            NEEDS_REBOOT=1
            warn "Groups changed — you MUST reboot or re-login for this to take effect."
        else
            warn "GPU access may fail without correct groups."
        fi
    else
        success "User groups OK (render, video present)"
    fi

    export GPU_NAME GPU_ARCH GPU_GFX GPU_PCI_ID GPU_VRAM_TIER GPU_ROCM_SUPPORTED NEEDS_REBOOT HSA_OVERRIDE_GFX_VERSION

    # --- Summary ---
    section "GPU Summary"
    printf "  %-20s %s\n" "GPU Name:" "${GPU_NAME}"
    printf "  %-20s %s\n" "Architecture:" "${GPU_GFX:-N/A}"
    printf "  %-20s %s\n" "PCI ID:" "${GPU_PCI_ID:-N/A}"
    printf "  %-20s %s\n" "VRAM Tier:" "${GPU_VRAM_TIER}"
    printf "  %-20s %s\n" "ROCm Supported:" "$([ "$GPU_ROCM_SUPPORTED" -eq 1 ] && echo "Yes" || echo "No")"
    printf "  %-20s %s\n" "Needs Reboot:" "$([ "$NEEDS_REBOOT" -eq 1 ] && echo "Yes" || echo "No")"
    echo ""

    [[ "$GPU_ARCH" != "UNKNOWN" ]]
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_gpu
fi
