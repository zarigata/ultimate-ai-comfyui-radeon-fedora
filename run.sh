#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$SCRIPT_DIR"

_setup_env() {
    export PYTHONNOUSERSITE=1
    unset PYTHONPATH
    export LD_LIBRARY_PATH="/usr/lib64:/usr/lib64/rocm:/opt/rocm/lib:${LD_LIBRARY_PATH:-}"

    if [[ -f "$SCRIPT_DIR/.miniforge/etc/profile.d/conda.sh" ]]; then
        # shellcheck disable=SC1090
        source "$SCRIPT_DIR/.miniforge/etc/profile.d/conda.sh" 2>/dev/null || true
    fi

    if [[ -d "$SCRIPT_DIR/.conda/envs/comfyui-radeon" ]]; then
        conda activate "$SCRIPT_DIR/.conda/envs/comfyui-radeon" 2>/dev/null || true
    fi

    if [[ -f "$SCRIPT_DIR/.hsa-override" ]]; then
        # shellcheck disable=SC1090
        source "$SCRIPT_DIR/.hsa-override" 2>/dev/null || true
    fi
}

cmd_launch() {
    _setup_env
    if [[ -d "$SCRIPT_DIR/ComfyUI" ]]; then
        cd "$SCRIPT_DIR/ComfyUI"
        exec python main.py --listen 0.0.0.0 --port 8188
    else
        echo "ERROR: ComfyUI directory not found. Run ./install.sh first." >&2
        exit 1
    fi
}

cmd_verify() {
    _setup_env
    local py="$SCRIPT_DIR/.conda/envs/comfyui-radeon/bin/python"
    if [[ -x "$py" ]]; then
        exec "$py" "$SCRIPT_DIR/scripts/verify_gpu.py" "$@"
    else
        echo "ERROR: Python not found in conda env. Run ./install.sh first." >&2
        exit 1
    fi
}

cmd_doctor() {
    if [[ -x "$SCRIPT_DIR/doctor.sh" ]]; then
        exec "$SCRIPT_DIR/doctor.sh"
    else
        echo "ERROR: doctor.sh not found." >&2
        exit 1
    fi
}

cmd_repair() {
    if [[ -x "$SCRIPT_DIR/repair.sh" ]]; then
        exec "$SCRIPT_DIR/repair.sh"
    else
        echo "ERROR: repair.sh not found." >&2
        exit 1
    fi
}

cmd_update() {
    _setup_env
    if [[ -d "$SCRIPT_DIR/ComfyUI/.git" ]]; then
        echo "Updating ComfyUI..."
        git -C "$SCRIPT_DIR/ComfyUI" pull --ff-only || echo "WARNING: Update failed."
        echo "Updating custom nodes..."
        for d in "$SCRIPT_DIR/ComfyUI/custom_nodes"/*/; do
            if [[ -d "$d/.git" ]]; then
                echo "  → $(basename "$d")"
                git -C "$d" pull --ff-only 2>/dev/null || echo "    (update failed)"
            fi
        done
        echo "Done."
    else
        echo "ERROR: ComfyUI not found or not a git repo." >&2
        exit 1
    fi
}

cmd_edit() {
    echo "FFmpeg Editing Helper"
    echo "====================="
    echo "Input folder:  $SCRIPT_DIR/input/"
    echo "Output folder: $SCRIPT_DIR/output/"
    echo ""
    echo "Common commands:"
    echo "  # Extract frames from video"
    echo "  ffmpeg -i input/video.mp4 -vf fps=12 output/frames/frame_%04d.png"
    echo ""
    echo "  # Combine frames to video"
    echo "  ffmpeg -framerate 12 -i output/frames/frame_%04d.png -c:v libx264 -pix_fmt yuv420p output/video.mp4"
    echo ""
    echo "  # Add audio"
    echo "  ffmpeg -i output/video.mp4 -i audio.aac -c copy output/with_audio.mp4"
    echo ""
    echo "  # Resize"
    echo "  ffmpeg -i input/video.mp4 -vf scale=1280:720 output/resized.mp4"
    mkdir -p "$SCRIPT_DIR/input" "$SCRIPT_DIR/output"
}

cmd_env() {
    _setup_env
    echo "═══ Environment Info ═══"
    echo ""
    echo "Python:"
    which python 2>/dev/null && python --version 2>&1 || echo "  not found"
    echo ""
    echo "PyTorch:"
    python -c "import torch; print(f'  version: {torch.__version__}'); print(f'  HIP: {torch.version.hip}'); print(f'  CUDA available: {torch.cuda.is_available()}')" 2>/dev/null || echo "  not available"
    echo ""
    echo "GPU:"
    lspci 2>/dev/null | grep -iE 'vga|3d|amd|radeon' || echo "  no GPU info"
    echo ""
    echo "ROCm:"
    rocminfo 2>/dev/null | head -5 || echo "  rocminfo not available"
    echo ""
    echo "Conda env: $SCRIPT_DIR/.conda/envs/comfyui-radeon"
    echo "ComfyUI:   $SCRIPT_DIR/ComfyUI"
}

cmd_models() {
    _setup_env
    if [[ -f "$SCRIPT_DIR/scripts/install_models.sh" ]]; then
        source "$SCRIPT_DIR/scripts/common.sh"
        source "$SCRIPT_DIR/scripts/install_models.sh"
        install_models
    else
        echo "ERROR: install_models.sh not found." >&2
        exit 1
    fi
}

cmd_reset_python() {
    echo "WARNING: This will delete the conda environment."
    read -r -p "Type RESET to confirm: " confirm
    if [[ "$confirm" != "RESET" ]]; then
        echo "Cancelled."
        return
    fi
    rm -rf "$SCRIPT_DIR/.conda/envs/comfyui-radeon"
    echo "Conda env removed. Run ./install.sh to recreate."
}

cmd_logs() {
    if [[ -f "$SCRIPT_DIR/logs/latest.log" ]]; then
        tail -n 50 "$SCRIPT_DIR/logs/latest.log"
    else
        echo "No logs found at $SCRIPT_DIR/logs/latest.log"
    fi
}

usage() {
    cat <<'USAGE'
Usage: ./run.sh [command]

Commands:
  launch        Start ComfyUI server (default)
  verify        Run GPU verification
  doctor        Run full diagnostics
  repair        Run repair workflow
  update        Update ComfyUI and custom nodes
  edit          FFmpeg editing helper
  env           Print environment info
  models        Run model download script
  reset-python  Delete and recreate conda env
  logs          Tail latest install log
USAGE
}

case "${1:-launch}" in
    launch|"")   cmd_launch "$@" ;;
    verify)      cmd_verify "$@" ;;
    doctor)      cmd_doctor ;;
    repair)      cmd_repair ;;
    update)      cmd_update ;;
    edit)        cmd_edit ;;
    env)         cmd_env ;;
    models)      cmd_models ;;
    reset-python) cmd_reset_python ;;
    logs)        cmd_logs ;;
    -h|--help)   usage ;;
    *)           echo "Unknown command: $1"; usage; exit 1 ;;
esac
