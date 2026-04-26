# Installer Flags Reference

Complete reference for all `install.sh` command-line flags.

| Flag | Default | What It Does | Safety | Example |
|------|---------|--------------|--------|---------|
| `--yes` | off | Non-interactive mode: auto-accept safe prompts | 🟢 Safe | `./install.sh --yes` |
| `--aggressive` | off | Enable advanced diagnostics, offer more repair options | 🟡 Caution | `./install.sh --aggressive` |
| `--allow-erasing` | off | Allow `dnf --allowerasing` during package install | 🔴 Expert | `./install.sh --allow-erasing` |
| `--disable-problem-repos` | off | Disable known conflicting repos (e.g. nobara-pikaos) | 🟡 Caution | `./install.sh --disable-problem-repos` |
| `--dry-run` | off | Show what would happen without doing anything | 🟢 Safe | `./install.sh --dry-run` |
| `--verbose` | off | Enable debug-level log output | 🟢 Safe | `./install.sh --verbose` |
| `--doctor` | off | Run diagnostics only, then exit | 🟢 Safe | `./install.sh --doctor` |
| `--repair` | off | Run repair workflow only, then exit | 🟡 Caution | `./install.sh --repair` |
| `--backend` | `bare-metal` | Backend type: `bare-metal` or `container` | 🟢 Safe | `./install.sh --backend container` |
| `--torch-source` | auto | PyTorch source: `amd`, `pytorch`, or auto-detect | 🟡 Caution | `./install.sh --torch-source amd` |
| `--python` | `3.12` | Python version for conda env | 🟢 Safe | `./install.sh --python 3.11` |
| `--skip-models` | off | Skip model downloads entirely | 🟢 Safe | `./install.sh --skip-models` |
| `--model-tier` | auto | Model tier: `low-vram`, `mid-vram`, or `high-vram` | 🟡 Caution | `./install.sh --model-tier high-vram` |
| `--help` | off | Show usage information | 🟢 Safe | `./install.sh --help` |

## Safety Legend

- 🟢 **Safe**: Can be used by anyone. No destructive actions.
- 🟡 **Caution**: May change system state. Read prompts carefully.
- 🔴 **Expert Only**: Can overwrite/remove system packages. Only use if you understand the implications.

## Flag Interactions

- `--yes --dry-run` — Safe test run: shows what would happen, accepts all defaults, does nothing.
- `--aggressive --repair` — Powerful repair mode: offers more aggressive fixes. Read every prompt.
- `--skip-models --model-tier high-vram` — Sets tier preference for docs/guidance but doesn't download.
- `--backend bare-metal --torch-source pytorch` — Force bare-metal with PyTorch official ROCm wheels.
- `--backend container` — Skip bare-metal PyTorch entirely, use Podman/Docker.

## Common Usage Patterns

**Beginner (interactive):**
```bash
./install.sh
```

**Non-interactive safe install:**
```bash
./install.sh --yes
```

**Preview everything:**
```bash
./install.sh --dry-run --verbose
```

**High-VRAM GPU, skip models:**
```bash
./install.sh --yes --model-tier high-vram --skip-models
```

**Container fallback (if bare-metal fails):**
```bash
./install.sh --yes --backend container
```

**Just run diagnostics:**
```bash
./install.sh --doctor
```

**Fix a broken install:**
```bash
./install.sh --repair
```

## What `--aggressive` Does (and Doesn't)

**Does:**
- Run more diagnostics
- Offer to disable conflicting repos temporarily
- Offer to install missing ROCm libraries without per-package confirmation
- Offer to run `distro-sync` after explaining risk
- Offer to use `--allowerasing` only after explicit scary confirmation

**Does NOT:**
- Automatically erase packages
- Run `dnf --allowerasing` without `--allow-erasing` also being set
- Delete user data
- Modify boot configuration
- Flash firmware
- Skip confirmation for dangerous operations
