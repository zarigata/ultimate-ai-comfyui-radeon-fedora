#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_system_rocm_libs() {
    local required_pkgs=(git curl bzip2 ca-certificates)
    local detect_pkgs=(rocminfo)
    local rocm_pkgs=(rocm-runtime rocm-hip miopen rocsolver rocblas hipblas)
    local optional_pkgs=(rccl ffmpeg)
    local to_install=()

    if [[ "${CONFY_DRY_RUN:-0}" -eq 1 ]]; then
        info "DRY-RUN: Would check and install: ${required_pkgs[*]} ${detect_pkgs[*]} ${rocm_pkgs[*]} ${optional_pkgs[*]}"
        return 0
    fi

    # Check required packages
    for p in "${required_pkgs[@]}" "${detect_pkgs[@]}"; do
        if rpm -q "$p" &>/dev/null; then
            step "$p: already installed"
        else
            to_install+=("$p")
        fi
    done

    # Check ffmpeg
    if rpm -q ffmpeg &>/dev/null; then
        step "ffmpeg: already installed"
    else
        to_install+=("ffmpeg")
    fi

    # Check ROCm packages — ask per-package unless aggressive/noninteractive
    for p in "${rocm_pkgs[@]}"; do
        if rpm -q "$p" &>/dev/null; then
            step "$p: already installed"
        else
            if [[ "${CONFY_AGGRESSIVE:-0}" -eq 1 || "${CONFY_NONINTERACTIVE:-0}" -eq 1 ]]; then
                to_install+=("$p")
            else
                if ask_yes_no "Install ROCm library '$p'?" "default_y"; then
                    to_install+=("$p")
                fi
            fi
        fi
    done

    # Optional packages
    for p in "${optional_pkgs[@]}"; do
        if rpm -q "$p" &>/dev/null; then
            step "$p: already installed"
        else
            if [[ "${CONFY_AGGRESSIVE:-0}" -eq 1 ]]; then
                to_install+=("$p")
            fi
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        success "All required packages already installed"
        return 0
    fi

    info "Packages to install: ${to_install[*]}"

    # DO NOT install full rocm meta-package
    if [[ "${CONFY_AGGRESSIVE:-0}" -eq 1 ]]; then
        warn "Note: --aggressive does NOT auto-install the full 'rocm' meta-package."
        warn "Full ROCm install can trigger Mesa/FFmpeg/repo conflicts on Nobara."
        if ask_yes_no "Install full 'rocm' meta-package? (risky on Nobara)" "default_n"; then
            to_install+=(rocm)
        fi
    fi

    # Install
    local dnf_args=(sudo dnf install -y "${to_install[@]}" --setopt=install_weak_deps=False)

    info "Running: ${dnf_args[*]}"

    if ! "${dnf_args[@]}"; then
        error "dnf install failed — likely repo conflicts."
        error "Full error output is above."

        if [[ "${CONFY_DISABLE_PROBLEM_REPOS:-0}" -eq 1 ]]; then
            warn "Retrying with --disablerepo='nobara-pikaos-additional'..."
            if ! sudo dnf install -y "${to_install[@]}" --disablerepo='nobara-pikaos-additional' --setopt=install_weak_deps=False; then
                error "Retry also failed. You may need to resolve conflicts manually."
                return 1
            fi
        elif ask_yes_no "Retry with --disablerepo='nobara-pikaos-additional'?" "default_n"; then
            if ! sudo dnf install -y "${to_install[@]}" --disablerepo='nobara-pikaos-additional' --setopt=install_weak_deps=False; then
                error "Retry failed. Check the error output above."
                return 1
            fi
        else
            return 1
        fi
    fi

    # Reload ldconfig
    sudo ldconfig 2>/dev/null || true

    # Verify key libraries
    info "Verifying ROCm libraries..."
    local missing_libs=0
    for lib in libamdhip64 libMIOpen librocsolver librocblas libhipblas; do
        if ldconfig -p 2>/dev/null | grep -q "$lib"; then
            step "$lib: found"
        else
            warn "$lib: NOT found in ldconfig"
            missing_libs=1
        fi
    done

    if [[ "$missing_libs" -eq 1 ]]; then
        warn "Some libraries not in ldconfig — may need LD_LIBRARY_PATH or repair_missing_so.sh"
    fi

    success "System ROCm libraries installation complete"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_system_rocm_libs "$@"
fi
