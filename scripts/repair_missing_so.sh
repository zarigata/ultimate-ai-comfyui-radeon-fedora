#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

declare -A SO_TO_PKG=(
    ["libMIOpen.so.1"]="miopen"
    ["libMIOpen.so"]="miopen"
    ["librocsolver.so.0"]="rocsolver"
    ["librocsolver.so"]="rocsolver"
    ["librocblas.so.0"]="rocblas"
    ["librocblas.so"]="rocblas"
    ["libhipblas.so.2"]="hipblas"
    ["libhipblas.so"]="hipblas"
    ["libamdhip64.so"]="rocm-hip"
    ["libhsa-runtime64.so"]="rocm-runtime"
    ["librocm_smi64.so"]="rocm-smi"
    ["librccl.so"]="rccl"
)

map_missing_so() {
    local lib_name="$1"

    if ldconfig -p 2>/dev/null | grep -q "$lib_name"; then
        local path
        path="$(ldconfig -p 2>/dev/null | grep "$lib_name" | head -1 | awk '{print $NF}')"
        echo "FOUND:$path"
        return 0
    fi

    local found
    found="$(find /usr/lib64 /usr/lib64/rocm /opt/rocm* /opt/amdgpu -name "$lib_name" 2>/dev/null | head -1 || true)"
    if [[ -n "$found" ]]; then
        echo "FOUND_NOT_IN_LDCONFIG:$found"
        return 0
    fi

    local pkg="${SO_TO_PKG[$lib_name]:-}"
    if [[ -n "$pkg" ]]; then
        echo "PACKAGE:$pkg"
        return 0
    fi

    # Try dnf repoquery
    if command -v dnf &>/dev/null; then
        local provider
        provider="$(dnf repoquery --whatprovides "*$lib_name" 2>/dev/null | head -1 || true)"
        if [[ -n "$provider" ]]; then
            echo "REPOQUERY:$provider"
            return 0
        fi
    fi

    echo "UNKNOWN"
    return 1
}

repair_missing_so() {
    local -a lib_list=("$@")

    if [[ ${#lib_list[@]} -eq 0 ]]; then
        lib_list=("libMIOpen.so.1" "librocsolver.so.0" "librocblas.so.0" "libhipblas.so.2" "libamdhip64.so" "libhsa-runtime64.so")
    fi

    local repaired=() remaining=()

    for lib in "${lib_list[@]}"; do
        info "Checking: $lib"
        local result
        result="$(map_missing_so "$lib")" || true

        case "$result" in
            FOUND:*)
                success "$lib: available at ${result#FOUND:}"
                continue
                ;;
            FOUND_NOT_IN_LDCONFIG:*)
                local lib_path="${result#FOUND_NOT_IN_LDCONFIG:}"
                warn "$lib: found at $lib_path but not in ldconfig"
                info "  Fix: add to LD_LIBRARY_PATH or run: sudo ldconfig $(dirname "$lib_path")"
                remaining+=("$lib (not in ldconfig)")
                continue
                ;;
            PACKAGE:*|REPOQUERY:*)
                local pkg="${result#*:}"
                if ask_yes_no "Install package '$pkg' for $lib?" "default_y"; then
                    if sudo dnf install -y "$pkg" --setopt=install_weak_deps=False 2>&1; then
                        sudo ldconfig 2>/dev/null || true
                        if ldconfig -p 2>/dev/null | grep -q "$lib"; then
                            success "$lib repaired via $pkg"
                            repaired+=("$lib")
                        else
                            remaining+=("$lib (installed but not in ldconfig)")
                        fi
                    else
                        error "Failed to install $pkg"
                        remaining+=("$lib (install failed)")
                    fi
                else
                    remaining+=("$lib (user declined)")
                fi
                ;;
            *)
                warn "$lib: no package mapping found"
                remaining+=("$lib (unknown)")
                ;;
        esac
    done

    if [[ ${#repaired[@]} -gt 0 ]]; then
        success "Repaired: ${repaired[*]}"
    fi
    if [[ ${#remaining[@]} -gt 0 ]]; then
        warn "Remaining: ${remaining[*]}"
        return 1
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    repair_missing_so "$@"
fi
