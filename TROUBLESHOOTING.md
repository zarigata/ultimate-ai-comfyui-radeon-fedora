# TROUBLESHOOTING: ULTIMATE AI COMFY RADEON EDITION

A comprehensive guide to fix common issues when running ComfyUI on ROCm-enabled Fedora/Nobara setups.

## Common errors and fixes
- Common errors and fixes (TOC):
- torch.cuda.is_available() returns False
- ImportError: libMIOpen.so.1 not found
- ImportError: librocsolver.so.0 not found
- rocminfo not found
- ComfyUI won't start
- Black images / NaN errors
- Out of VRAM
- dnf conflicts on Nobara
- Permission denied on /dev/kfd
- Container won't access GPU

## Error-by-error diagnostics
- torch.cuda.is_available() returns False
  - Symptom: PyTorch reports no CUDA (ROCm) device.
  - Likely causes: ROCm not installed or not loaded, kernel modules missing, user not in video group.
  - Fix: Ensure ROCm is installed and loaded, verify /dev/roc/* devices exist, add user to video and render groups, reboot if needed.

- ImportError: libMIOpen.so.1 not found
  - Symptom: Shared library missing.
  - Fix: Install ROCm runtime libraries that provide libMIOpen; verify ROCR, ROCm path, and LD_LIBRARY_PATH.

- ImportError: librocsolver.so.0 not found
  - Symptom: librocsolver missing for certain linear algebra kernels.
  - Fix: Install hipSOLVER / rocSOLVER packages matching your ROCm version.

- rocminfo not found
  - Symptom: rocminfo tool missing; ROCm not fully installed.
  - Fix: Install ROCm-tools or roctoolkit package; ensure /opt/rocm/bin is on PATH.

- ComfyUI won't start
  - Symptom: Crashes during startup; logs show import errors or missing models.
  - Fix: Validate Python env, dependencies, proper permissions for logs, and GPU access. Run doctor script.

- Black images / NaN errors
  - Symptom: Generated images are blank or contain NaNs.
  - Fix: Check model compatibility, ensure correct normalization settings, update to compatible PyTorch/ROCm versions.

- Out of VRAM
  - Symptom: GPU memory exhausted.
  - Fix: Reduce image size, use lower-resolution models, free caches, swap to CPU when needed.

- dnf conflicts on Nobara
  - Symptom: Package manager blocks installs due to conflicting repos.
  - Fix: Temporarily disable conflicting repositories or use --disable-problem-repos flag.

- Permission denied on /dev/kfd
  - Symptom: Access to /dev/kfd is blocked.
  - Fix: Reboot after kernel module load; ensure user is in video group; checkSELinux policies.

- Container won't access GPU
  - Symptom: Docker/Podman can't see ROCm devices inside container.
  - Fix: Run with --device /dev/kfd:/dev/kfd and --device /dev/roc*, and ensure container has access to IPC.

## Diagnostic tools
- ./doctor.sh
- ./run.sh verify

## Log location
- logs/latest.log

## When to ask for help
- If you hit issues that aren’t covered above, open an issue on GitHub and include logs from logs/latest.log, your ROCm version, kernel, and GPU model.

## Nobara-specific notes
- Known Nobara quirks include newer kernels and SELinux policies affecting ROCm modules. A quick reboot after install often helps.

## Fedora version notes
- Differences between Fedora versions may affect kernel headers and ROCm compatibility. Check the version-specific ROCm docs before reporting issues.
