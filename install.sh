#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFY_NONINTERACTIVE=0
CONFY_AGGRESSIVE=0
CONFY_ALLOW_ERASING=0
CONFY_DISABLE_PROBLEM_REPOS=0
CONFY_DRY_RUN=0
CONFY_VERBOSE=0
CONFY_BACKEND=""
CONFY_TORCH_SOURCE=""
CONFY_PYTHON_VERSION="3.12"
CONFY_SKIP_MODELS=0
CONFY_MODEL_TIER=""
MODE_DOCTOR=0
MODE_REPAIR=0

show_help() {
    cat <<'HELP'
Usage: ./install.sh [OPTIONS]

One-click ComfyUI + AMD Radeon + Fedora/Nobara installer.

Options:
  --yes                  Non-interactive mode (auto-accept safe prompts)
  --aggressive           Enable advanced diagnostics and repair options
  --allow-erasing        Allow dnf --allowerasing (DANGEROUS)
  --disable-problem-repos  Disable known conflicting repos
  --dry-run              Show what would be done without doing it
  --verbose              Enable debug-level output
  --doctor               Run diagnostics only, then exit
  --repair               Run repair only, then exit
  --backend TYPE         Backend: bare-metal (default) or container
  --torch-source SRC     PyTorch source: amd, pytorch, or auto
  --python VERSION       Python version (default: 3.12)
  --skip-models          Skip model downloads
  --model-tier TIER      Model tier: low-vram, mid-vram, high-vram
  --help                 Show this help message

Examples:
  ./install.sh                          Interactive beginner install
  ./install.sh --yes                    Non-interactive, safe defaults
  ./install.sh --doctor                 Run diagnostics only
  ./install.sh --backend container      Use container fallback
  ./install.sh --model-tier high-vram   Download high-VRAM models
  ./install.sh --dry-run --verbose      Preview everything
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)                CONFY_NONINTERACTIVE=1; shift ;;
        --aggressive)         CONFY_AGGRESSIVE=1; shift ;;
        --allow-erasing)      CONFY_ALLOW_ERASING=1; shift ;;
        --disable-problem-repos) CONFY_DISABLE_PROBLEM_REPOS=1; shift ;;
        --dry-run)            CONFY_DRY_RUN=1; shift ;;
        --verbose)            CONFY_VERBOSE=1; shift ;;
        --doctor)             MODE_DOCTOR=1; shift ;;
        --repair)             MODE_REPAIR=1; shift ;;
        --backend)            CONFY_BACKEND="$2"; shift 2 ;;
        --torch-source)       CONFY_TORCH_SOURCE="$2"; shift 2 ;;
        --python)             CONFY_PYTHON_VERSION="$2"; shift 2 ;;
        --skip-models)        CONFY_SKIP_MODELS=1; shift ;;
        --model-tier)         CONFY_MODEL_TIER="$2"; shift 2 ;;
        --help|-h)            show_help; exit 0 ;;
        *)                    echo "Unknown flag: $1. Use --help for usage."; exit 1 ;;
    esac
done

export CONFY_NONINTERACTIVE CONFY_AGGRESSIVE CONFY_ALLOW_ERASING \
       CONFY_DISABLE_PROBLEM_REPOS CONFY_DRY_RUN CONFY_VERBOSE \
       CONFY_BACKEND CONFY_TORCH_SOURCE CONFY_PYTHON_VERSION \
       CONFY_SKIP_MODELS CONFY_MODEL_TIER MODE_DOCTOR MODE_REPAIR

source "$SCRIPT_DIR/scripts/common.sh"
source "$SCRIPT_DIR/scripts/logging.sh"
init_logging

trap 'error "Installer failed at line $LINENO. Check logs/latest.log for details."' ERR

cat <<'BANNER'

  ╔═══════════════════════════════════════════════════════════════════╗
  ║  THE ULTIMATE REPO OF AI COMFY RADEON                           ║
  ║  BECAUSE NVIDIA IS A MOBSTER                                    ║
  ║  One-click ComfyUI + AMD Radeon + Fedora/Nobara Installer       ║
  ╚═══════════════════════════════════════════════════════════════════╝

BANNER

REQUIRED_SCRIPTS=(
    detect_os.sh detect_gpu.sh install_conda.sh install_system_rocm_libs.sh
    install_pytorch.sh install_comfyui.sh install_custom_nodes.sh
    install_models.sh verify_runtime.sh repair_missing_so.sh generate_run_sh.sh
)

for f in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ -f "$SCRIPT_DIR/scripts/$f" ]]; then
        source "$SCRIPT_DIR/scripts/$f"
    else
        error "Missing required script: scripts/$f"
        exit 1
    fi
done

if [[ "$MODE_DOCTOR" -eq 1 ]]; then
    if [[ -f "$SCRIPT_DIR/doctor.sh" ]]; then
        exec "$SCRIPT_DIR/doctor.sh"
    else
        error "doctor.sh not found"; exit 1
    fi
fi

if [[ "$MODE_REPAIR" -eq 1 ]]; then
    if [[ -f "$SCRIPT_DIR/repair.sh" ]]; then
        exec "$SCRIPT_DIR/repair.sh"
    else
        error "repair.sh not found"; exit 1
    fi
fi

section "[1/12] Detect OS"
detect_os || warn "OS detection had issues, continuing..."

section "[2/12] Detect GPU"
detect_gpu || error "No AMD GPU detected. Cannot continue."

if [[ "${NEEDS_REBOOT:-0}" == "1" ]]; then
    warn "Your user groups were changed. You MUST reboot or re-login."
    if [[ "$CONFY_NONINTERACTIVE" -eq 0 ]]; then
        ask_yes_no "Continue anyway? (GPU tests will fail until reboot)" "default_n" || exit 1
    fi
fi

section "[3/12] Install Conda/Miniforge"
install_conda || error "Conda install failed. Check logs/latest.log"

section "[4/12] Install System ROCm Libraries"
install_system_rocm_libs || warn "Some system libraries may be missing"

section "[5/12] Activate Conda Environment"
conda_activate || error "Failed to activate conda env"

section "[6/12] Install PyTorch (ROCm)"
install_pytorch || error "PyTorch install failed. Try: ./install.sh --backend container"

section "[7/12] Install ComfyUI"
install_comfyui || error "ComfyUI install failed"

section "[8/12] Install Custom Nodes"
install_custom_nodes || warn "Some custom nodes had issues"

section "[9/12] Download Models"
install_models || warn "Model downloads had issues — see MODELS.md for manual instructions"

section "[10/12] Verify GPU Runtime"
verify_runtime || warn "GPU verification had issues — run ./doctor.sh"

section "[11/12] Generate run.sh"
generate_run_sh || error "Failed to generate run.sh"

section "[12/12] Final Summary"

echo ""
if [[ -f "$REPO_ROOT/.comfyui-installed" ]]; then
    success "ComfyUI installed: $(cat "$REPO_ROOT/.comfyui-installed")"
fi
if [[ -f "$REPO_ROOT/.torch-version" ]]; then
    success "PyTorch: $(cat "$REPO_ROOT/.torch-version")"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅  INSTALLATION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Next steps:"
echo "    ./run.sh launch       Start ComfyUI server"
echo "    ./run.sh verify       Run GPU verification"
echo "    ./run.sh doctor       Run full diagnostics"
echo "    ./run.sh env          Show environment info"
echo ""
echo "  ComfyUI web UI:  http://127.0.0.1:8188/"
echo "  Logs:            logs/latest.log"
echo "  Troubleshooting: TROUBLESHOOTING.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
