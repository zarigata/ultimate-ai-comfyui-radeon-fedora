#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

detect_os() {
    parse_os_release

    section "OS Detection"
    info "Detected OS: ${OS_PRETTY_NAME} (${OS_ID} ${OS_VERSION_ID})"

    local os_supported=0

    case "$OS_ID" in
        fedora|nobara)
            os_supported=1
            ;;
        bazzite)
            os_supported=1
            warn "Bazzite is immutable/ostree-based — container backend recommended."
            warn "Bare-metal install may fail due to read-only filesystem."
            ;;
        ubuntu|debian|linuxmint|pop)
            error "Unsupported OS: $OS_ID — this installer requires dnf/Fedora family."
            error "Ubuntu/Debian users should use AMD's .deb installer instead."
            ;;
        arch|manjaro|endeavouros)
            error "Unsupported OS: $OS_ID — this installer requires dnf/Fedora family."
            ;;
        *)
            os_supported=0
            warn "Unknown OS: $OS_ID — proceeding with caution."
            ;;
    esac

    if [[ "$OS_ID" == "fedora" || "$OS_ID" == "nobara" ]]; then
        local ver="${OS_VERSION_ID:-0}"
        if version_gte "$ver" "44"; then
            warn "Version $ver is newer than tested range. Proceed with caution."
        elif version_gte "$ver" "43"; then
            success "Version $ver — optimal (tested range)."
        elif version_gte "$ver" "41"; then
            warn "Version $ver — older but generally supported."
        else
            warn "Version $ver is quite old. Unexpected issues are likely."
        fi
    fi

    if [[ "$OS_ID" == "nobara" ]]; then
        info "Nobara detected — gaming-focused Fedora spin with custom kernels."
        info "This is an excellent platform for AMD ROCm + ComfyUI."
    fi

    local is_immutable=0
    if [[ -f /run/ostree-booted ]] || grep -q "ostree" /etc/os-release 2>/dev/null; then
        is_immutable=1
        warn "System is immutable (ostree). Consider container backend."
    fi

    DETECTED_OS="$OS_ID"
    DETECTED_OS_VERSION="${OS_VERSION_ID:-0}"
    DETECTED_OS_NAME="$OS_PRETTY_NAME"
    OS_SUPPORTED="$os_supported"
    OS_IS_IMMUTABLE="$is_immutable"

    export DETECTED_OS DETECTED_OS_VERSION DETECTED_OS_NAME OS_SUPPORTED OS_IS_IMMUTABLE

    info "OS Summary: id=$DETECTED_OS ver=$DETECTED_OS_VERSION supported=$OS_SUPPORTED immutable=$OS_IS_IMMUTABLE"

    [[ "$OS_SUPPORTED" -eq 1 ]]
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_os
fi
