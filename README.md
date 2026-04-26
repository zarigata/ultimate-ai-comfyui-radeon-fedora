# THE ULTIMATE REPO OF AI COMFY RADEON BECAUSE NVIDIA IS A MOBSTER AND HOLDS THE MARKET BUT NOT FOR LONGER GET FUKKET NVIDIA

"REBEL WITH A CAUSE" AMD + ROCm + Fedora/Nobara installation, for AI workloads that actually respect your hardware.

Badge your spirit:

- [![Stars](https://img.shields.io/github/stars/YOUR_USERNAME/ultimate-ai-comfyui-radeon-fedora?style=social)](#)
- [![License](https://img.shields.io/badge/License-MIT-blue.svg)](#)
- [![ROCm](https://img.shields.io/badge/ROCm-supported-brightgreen)](#)

One-liner, in case you missed the banner:

One-click ComfyUI + AMD Radeon + Fedora/Nobara installer. Stick it to NVIDIA.

## Quick start
```bash
git clone https://github.com/YOUR_USERNAME/ultimate-ai-comfyui-radeon-fedora.git
cd ultimate-ai-comfyui-radeon-fedora
chmod +x install.sh
./install.sh
```

## What this does
1) Detects your AMD ROCm-capable GPU and bootstraps a ROCm-enabled Python environment.
2) Installs PyTorch with ROCm support (where available) or provides alternatives with CPU fallback.
3) Downloads and configures ComfyUI, plus optional model folders, ready-to-run.
4) Creates user-friendly launchers and a local web UI to generate images/videos.
5) Provides safety checks for temperatures, power, and compatibility with Fedora/Nobara kernels.

All steps are automated but transparent: the installer prints what it changes and why.

## Requirements
- AMD Radeon GPU with ROCm support (see GPUs table below)
- Fedora or Nobara (or compatible ROCm-capable distro)
- Disk space: at least 40 GB free for models and caches
- Internet access for downloads

## Supported GPUs
| GPU name | GFX architecture | VRAM tier | Status |
|---|---|---|---|
| RX 6500 XT | RDNA 2 | 4-8 GB | Supported (8GB+ recommended) |
| RX 6600 | RDNA 2 | 8-12 GB | Supported |
| RX 6700 XT | RDNA 2 | 12-16 GB | Supported |
| RX 6800 | RDNA 2 | 16-20 GB | Supported |
| RX 7900 XT | RDNA 3 | 20+ GB | Experimental |

Note: VRAM requirements are approximate and depend on models and workloads. Always monitor GPU temps during first runs.

## Installer modes
- Beginner: defaults and guided prompts
- Non-interactive: silent install with flags (see FLAGS.md)
- Doctor: run diagnostics and report issues
- Repair: fix broken install state and re-run
- Expert: advanced options with fine-grained controls (using flags in FLAGS.md)

Example usage (non-interactive):
./install.sh --yes --backend rocm --doctor

## After install
- Run ComfyUI: python -m comfyui or use the provided launcher
- Web UI: http://localhost:8188/
- Generate images/videos with ROCm-enabled PyTorch backend
- Model management through the MODELS.md guide

## Troubleshooting
See TROUBLESHOOTING.md for common issues and fixes.

## Screenshots
- Placeholder: ComfyUI dashboard, sample outputs, and model selectors.

## Contributing
We welcome pull requests, issue reports, and documentation improvements. See CONTRIBUTING.md (not included here yet) for guidelines.

## Credits
- AMD ROCm team
- ComfyUI project maintainers
- PyTorch ROCm integration teams
- ROCm community

## License
MIT License
See NO-WARRANTY.md for warranty disclaimers.

## Disclaimer
This project is for educational and recreational purposes. It aims to be user-friendly and open-source. Hardware temps can soar; proceed at your own risk. 
