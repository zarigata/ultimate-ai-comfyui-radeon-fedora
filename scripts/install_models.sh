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
        if _download_file "$url" "$dest_dir/$filename" "$name"; then
            downloaded+=("$name")
        else
            warn "$name: download failed — will need manual download"
            info "  Visit: $url"
            info "  Place file as: $dest_dir/$filename"
            [[ "$needs_hf" == "true" ]] && info "  NOTE: Requires HuggingFace login/token"
            manual+=("$name")
        fi
    done

    info "Downloaded: ${#downloaded[@]} models"
    [[ ${#manual[@]} -gt 0 ]] && info "Manual download needed: ${manual[*]}"

    _prompt_ltx_models "$MODELS_ROOT"

    return 0
}

_prompt_ltx_models() {
    local MODELS_ROOT="$1"

    local -a ltx_models=(
        "LTX-2.3 main model (fp8)|https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-dev-fp8.safetensors|checkpoints|ltx-2.3-22b-dev-fp8.safetensors|22000"
        "LTX-2.3 spatial upscaler|https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.1.safetensors|upscale_models|ltx-2.3-spatial-upscaler-x2-1.1.safetensors|1500"
        "LTX-2.3 distilled LoRA|https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-22b-distilled-lora-384.safetensors|loras|ltx-2.3-22b-distilled-lora-384.safetensors|800"
        "Gemma 3 12B text encoder (fp4)|https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors|text_encoders|gemma_3_12B_it_fp4_mixed.safetensors|6000"
    )

    local all_present=1
    for entry in "${ltx_models[@]}"; do
        IFS='|' read -r _ _ subfolder filename _ <<< "$entry"
        if [[ ! -f "$MODELS_ROOT/$subfolder/$filename" ]]; then
            all_present=0
            break
        fi
    done

    if [[ "$all_present" -eq 1 ]]; then
        info "All LTX-2.3 models already present, skipping prompt."
        return 0
    fi

    echo ""
    section "LTX-2.3 Video Models"
    info "The following LTX-2.3 video generation models are available:"
    echo ""
    local total_size=0
    for entry in "${ltx_models[@]}"; do
        IFS='|' read -r label url subfolder filename size_mb <<< "$entry"
        local status_icon="⬜"
        if [[ -f "$MODELS_ROOT/$subfolder/$filename" ]]; then
            status_icon="✅"
        fi
        local size_gb=$((size_mb / 1000))
        printf "  %s %-42s (~%dGB)\n" "$status_icon" "$label" "$size_gb"
        total_size=$((total_size + size_mb))
    done
    local total_gb=$((total_size / 1000))
    echo ""
    info "Total download size: ~${total_gb}GB"
    echo ""

    if [[ "${CONFY_NONINTERACTIVE:-0}" -eq 1 ]]; then
        info "Non-interactive mode — skipping LTX-2.3 (re-run interactively to download)."
        return 0
    fi

    ask_yes_no "Download all LTX-2.3 models?" "default_n" || {
        info "Skipping LTX-2.3 models."
        return 0
    }

    for entry in "${ltx_models[@]}"; do
        IFS='|' read -r label url subfolder filename size_mb <<< "$entry"

        local dest_dir="$MODELS_ROOT/$subfolder"
        mkdir -p "$dest_dir"

        if [[ -f "$dest_dir/$filename" ]]; then
            success "$label: already present"
            continue
        fi

        info "Downloading $label (~${size_mb}MB)..."
        _download_file "$url" "$dest_dir/$filename" "$label"
    done
}

_download_file() {
    local url="$1" dest="$2" label="$3"
    local success=0

    if command -v wget &>/dev/null; then
        if wget --progress=bar:force:noscroll -O "$dest" "$url" 2>&1; then
            success=1
        fi
    fi

    if [[ "$success" -eq 0 ]] && command -v curl &>/dev/null; then
        if curl -fL --progress-bar -o "$dest" "$url" 2>&1; then
            success=1
        fi
    fi

    if [[ "$success" -eq 0 ]]; then
        rm -f "$dest" 2>/dev/null || true
        return 1
    fi

    if [[ -s "$dest" ]]; then
        success "$label downloaded"
        return 0
    else
        rm -f "$dest" 2>/dev/null || true
        warn "$label: download produced empty file"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_models "$@"
fi
