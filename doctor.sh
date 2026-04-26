#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"
source "$SCRIPT_DIR/scripts/detect_os.sh" 2>/dev/null || true
source "$SCRIPT_DIR/scripts/detect_gpu.sh" 2>/dev/null || true
source "$SCRIPT_DIR/scripts/repair_missing_so.sh" 2>/dev/null || true

ISSUES=0

_check() {
    local label="$1"; shift
    echo ""
    echo "[$label]"
    "$@" 2>&1 || true
}

section "═══ Doctor Diagnostics ═══"

_check "OS"
if [[ -f /etc/os-release ]]; then
    grep -E '^(ID|VERSION_ID|NAME|PRETTY_NAME)=' /etc/os-release
else
    warn "Cannot read /etc/os-release"; ISSUES=$((ISSUES+1))
fi

_check "GPU — rocminfo"
if command -v rocminfo &>/dev/null; then
    rocminfo 2>&1 | grep -E 'gfx|Name:|Device' | head -10
else
    warn "rocminfo not installed"; ISSUES=$((ISSUES+1))
fi

_check "GPU — lspci"
lspci 2>/dev/null | grep -iE 'vga|3d|display|amd|radeon' | head -5 || { warn "lspci not available"; ISSUES=$((ISSUES+1)); }

_check "Device Permissions"
if [[ -r /dev/kfd ]]; then echo "  /dev/kfd: readable ✓"; else warn "  /dev/kfd: NOT readable"; ISSUES=$((ISSUES+1)); fi
if [[ -d /dev/dri ]]; then echo "  /dev/dri: exists ✓"; ls /dev/dri/renderD* 2>/dev/null || warn "  No render nodes"; else warn "  /dev/dri: NOT found"; ISSUES=$((ISSUES+1)); fi

_check "User Groups"
echo "  $(groups "$USER" 2>/dev/null || echo "unknown")"
if ! groups "$USER" 2>/dev/null | grep -qw "render"; then warn "  Missing 'render' group"; ISSUES=$((ISSUES+1)); fi
if ! groups "$USER" 2>/dev/null | grep -qw "video"; then warn "  Missing 'video' group"; ISSUES=$((ISSUES+1)); fi

_check "Conda"
if [[ -x "$SCRIPT_DIR/.miniforge/bin/conda" ]]; then
    echo "  Miniforge: installed ✓"
    if [[ -d "$SCRIPT_DIR/.conda/envs/comfyui-radeon" ]]; then
        echo "  Env comfyui-radeon: exists ✓"
        local py="$SCRIPT_DIR/.conda/envs/comfyui-radeon/bin/python"
        if [[ -x "$py" ]]; then
            echo "  Python: $($py --version 2>&1)"
        else
            warn "  Python binary missing in env"; ISSUES=$((ISSUES+1))
        fi
    else
        warn "  Conda env missing"; ISSUES=$((ISSUES+1))
    fi
else
    warn "  Miniforge not installed"; ISSUES=$((ISSUES+1))
fi

_check "PyTorch"
py_bin="$SCRIPT_DIR/.conda/envs/comfyui-radeon/bin/python"
if [[ -x "$py_bin" ]]; then
    torch_info="$("$py_bin" -c "
import torch
print(f'  version: {torch.__version__}')
print(f'  HIP: {torch.version.hip}')
print(f'  CUDA: {torch.cuda.is_available()}')
" 2>&1)" || true
    echo "$torch_info"
    if echo "$torch_info" | grep -q "CUDA: True"; then
        echo "  ROCm GPU: ✓"
    else
        warn "  CUDA not available — PyTorch may not see GPU"; ISSUES=$((ISSUES+1))
    fi
else
    warn "  Cannot check PyTorch — python not in env"; ISSUES=$((ISSUES+1))
fi

_check "ComfyUI"
if [[ -d "$SCRIPT_DIR/ComfyUI" ]]; then
    echo "  ComfyUI: present ✓"
    if [[ -d "$SCRIPT_DIR/ComfyUI/.git" ]]; then
        echo "  git hash: $(git -C "$SCRIPT_DIR/ComfyUI" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    fi
else
    warn "  ComfyUI directory missing"; ISSUES=$((ISSUES+1))
fi

_check "Models"
models_dir="$SCRIPT_DIR/ComfyUI/models"
if [[ -d "$models_dir" ]]; then
    for d in checkpoints vae loras clip diffusion_models controlnet upscale_models animatediff_models text_encoders; do
        if [[ -d "$models_dir/$d" ]]; then
            count="$(find "$models_dir/$d" -type f 2>/dev/null | wc -l)"
            echo "  $d: $count files"
        fi
    done
else
    warn "  Models directory missing"; ISSUES=$((ISSUES+1))
fi

_check "Shared Libraries"
for lib in libamdhip64 libMIOpen librocsolver librocblas libhipblas libhsa-runtime64; do
    if ldconfig -p 2>/dev/null | grep -q "$lib"; then
        echo "  $lib: found ✓"
    else
        warn "  $lib: NOT in ldconfig"
        ISSUES=$((ISSUES+1))
    fi
done

_check "Disk Space"
df -h / | tail -1

_check "Memory"
free -h | head -2

echo ""
if [[ "$ISSUES" -eq 0 ]]; then
    success "All checks passed — system is HEALTHY"
    exit 0
else
    warn "Found $ISSUES issue(s). Run ./repair.sh or check TROUBLESHOOTING.md"
    exit 1
fi
