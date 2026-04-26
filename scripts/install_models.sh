#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_models() {
    if [[ "${CONFY_SKIP_MODELS:-0}" -eq 1 ]]; then
        info "Skipping model downloads (CONFY_SKIP_MODELS=1)"
        return 0
    fi

    local MODELS_ROOT="$REPO_ROOT/ComfyUI/models"

    # Determine tier
    local tier=""
    if [[ -n "${CONFY_MODEL_TIER:-}" ]]; then
        tier="$CONFY_MODEL_TIER"
    elif [[ -n "${GPU_VRAM_TIER:-}" && "$GPU_VRAM_TIER" != "unknown" ]]; then
        tier="$GPU_VRAM_TIER"
    else
        if [[ "${CONFY_NONINTERACTIVE:-0}" -eq 1 ]]; then
            tier="low-vram"
        else
            info "Choose model tier:"
            info "  1) low-vram  — GPUs with < 8GB VRAM"
            info "  2) mid-vram  — GPUs with 8-16GB VRAM"
            info "  3) high-vram — GPUs with 16GB+ VRAM"
            echo -n "Enter choice [1-3]: "
            read -r choice
            case "$choice" in
                1) tier="low-vram" ;;
                2) tier="mid-vram" ;;
                3) tier="high-vram" ;;
                *) tier="low-vram" ;;
            esac
        fi
    fi
    info "Model tier: $tier"

    # Model definitions: name|source_url|ComfyUI_subfolder|filename|approx_size_mb|auto_download|needs_hf_token
    local -a models_low=(
        "stable-diffusion-v1-5|https://huggingface.co/CompVis/stable-diffusion-v1-5|checkpoints|v1-5-pruned-emaonly.safetensors|4000|true|false"
        "vae-ft-mse-840000|https://huggingface.co/stabilityai/sd-vae-ft-mse|vae|vae-ft-mse-840000-ema-pruned.safetensors|335|true|false"
    )
    local -a models_mid=(
        "dreamshaper_8|https://huggingface.co/Lykon/dreamshaper-v8|checkpoints|dreamshaper_8.safetensors|6900|true|false"
        "sd_xl_base_1.0|https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0|checkpoints|sd_xl_base_1.0.safetensors|6500|true|false"
        "sdxl_vae|https://huggingface.co/stabilityai/sdxl-vae|vae|sdxl_vae.safetensors|335|true|false"
    )
    local -a models_high=(
        "flux1-dev-fp8|https://huggingface.co/FLUX.1-dev|diffusion_models|flux1-dev-fp8.safetensors|12000|false|true"
    )

    local -a tier_models=()
    case "$tier" in
        low-vram)  tier_models=("${models_low[@]}") ;;
        mid-vram)  tier_models=("${models_low[@]}" "${models_mid[@]}") ;;
        high-vram) tier_models=("${models_low[@]}" "${models_mid[@]}" "${models_high[@]}") ;;
        *)         tier_models=("${models_low[@]}") ;;
    esac

    local -a downloaded=() manual=()

    for entry in "${tier_models[@]}"; do
        IFS='|' read -r name url subfolder filename size_mb auto_dl needs_hf <<< "$entry"
        [[ -z "$name" ]] && continue

        local dest_dir="$MODELS_ROOT/$subfolder"
        mkdir -p "$dest_dir"

        if [[ -f "$dest_dir/$filename" ]]; then
            info "$name: already present, skipping"
            continue
        fi

        if [[ "$auto_dl" != "true" ]]; then
            info "$name: requires manual download"
            info "  Visit: $url"
            info "  Place file as: $dest_dir/$filename"
            [[ "$needs_hf" == "true" ]] && info "  NOTE: Requires HuggingFace login/token"
            manual+=("$name")
            continue
        fi

        info "Downloading $name (~${size_mb}MB)..."
        local success=0

        if command -v huggingface-cli &>/dev/null; then
            if huggingface-cli download --local-dir "$dest_dir" "$url" 2>/dev/null; then
                success=1
            fi
        fi

        if [[ "$success" -eq 0 ]] && command -v wget &>/dev/null; then
            if wget -q -O "$dest_dir/$filename" "$url" 2>/dev/null; then
                success=1
            fi
        fi

        if [[ "$success" -eq 0 ]] && command -v curl &>/dev/null; then
            if curl -fsSL -o "$dest_dir/$filename" "$url" 2>/dev/null; then
                success=1
            fi
        fi

        if [[ -s "$dest_dir/$filename" ]]; then
            downloaded+=("$name")
            success "$name downloaded"
        else
            rm -f "$dest_dir/$filename" 2>/dev/null || true
            warn "$name: download failed — will need manual download"
            manual+=("$name")
        fi
    done

    info "Downloaded: ${#downloaded[@]} models"
    [[ ${#manual[@]} -gt 0 ]] && info "Manual download needed: ${manual[*]}"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_models "$@"
fi
