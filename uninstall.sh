#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

cat <<'WARN'

  ╔═══════════════════════════════════════════════════════════════╗
  ║                    ⚠️  UNINSTALL  ⚠️                        ║
  ║                                                             ║
  ║  This will remove:                                          ║
  ║    • Conda environment (.conda/)                            ║
  ║    • Miniforge (.miniforge/)                                ║
  ║    • ComfyUI (optional)                                     ║
  ║    • Install logs (optional)                                ║
  ║                                                             ║
  ║  System packages will NOT be removed.                       ║
  ║  The installer scripts will be kept.                        ║
  ╚═══════════════════════════════════════════════════════════════╝

WARN

printf "Type UNINSTALL to confirm: "
read -r CONFIRM
if [[ "$CONFIRM" != "UNINSTALL" ]]; then
    echo "Cancelled."
    exit 0
fi

# Deactivate conda if active
if command -v conda &>/dev/null; then
    conda deactivate 2>/dev/null || true
fi

# Remove conda env and miniforge
info "Removing conda environment..."
rm -rf "$SCRIPT_DIR/.conda"
info "Removing Miniforge..."
rm -rf "$SCRIPT_DIR/.miniforge"

# Ask about ComfyUI
if [[ -d "$SCRIPT_DIR/ComfyUI" ]]; then
    if ask_yes_no "Remove ComfyUI directory? (includes downloaded models)" "default_n"; then
        rm -rf "$SCRIPT_DIR/ComfyUI"
        info "ComfyUI removed."
    else
        info "ComfyUI directory kept."
    fi
fi

# Ask about logs
if [[ -d "$SCRIPT_DIR/logs" ]]; then
    if ask_yes_no "Remove logs?" "default_n"; then
        rm -rf "$SCRIPT_DIR/logs"
        info "Logs removed."
    else
        info "Logs kept."
    fi
fi

# Clean up state files
rm -f "$SCRIPT_DIR/.comfyui-installed"
rm -f "$SCRIPT_DIR/.torch-version"
rm -f "$SCRIPT_DIR/.hsa-override"

echo ""
success "Uninstall complete."
echo "  Kept: install.sh, scripts/, docs, .gitignore, LICENSE"
echo "  Removed: .conda/, .miniforge/"
echo ""
echo "  To reinstall: ./install.sh"
