#!/usr/bin/env python3
"""GPU verification script for ComfyUI Radeon setup."""

import argparse
import importlib
import os
import sys
import subprocess


def dyn_import(module):
    try:
        return importlib.import_module(module)
    except Exception:
        return None


def main():
    parser = argparse.ArgumentParser(description="Verify AMD ROCm GPU availability for ComfyUI Radeon setup.")
    parser.add_argument("--comfyui", action="store_true", help="Try to import ComfyUI modules for quick sanity check.")
    parser.add_argument("--http", action="store_true", help="Attempt to start ComfyUI and test HTTP endpoint, then stop.")
    args = parser.parse_args()

    failures = []
    passes = 0
    total = 0

    def record_pass(desc=""):
        nonlocal passes, total
        total += 1
        passes += 1
        print(f"PASS: {desc}".rstrip())

    def record_fail(desc="", hint=""):
        nonlocal total
        total += 1
        failures.append((desc, hint))
        print(f"FAIL: {desc}".rstrip())

    # 1) Python location
    py = sys.executable
    if py and "comfyui-radeon" in py:
        record_pass("Python location compliant: {}".format(py))
    else:
        record_fail("Python location not compliant: {}".format(py))
    # 2) User site disabled
    try:
        import site
        enable = getattr(site, "ENABLE_USER_SITE", False)
        user_site_in_path = any("site-packages" in p for p in sys.path)
        if enable is False or not user_site_in_path:
            record_pass("User site package usage is disabled as expected.")
        else:
            record_fail("User site package is enabled; may affect isolation.", "Disable user site or adjust PYTHONNOUSERSITE if needed.")
    except Exception as e:
        record_fail("Could not inspect user site settings: {}".format(e))

    # 3) Torch import
    torch = dyn_import("torch")
    if torch is None:
        record_fail("Python can import torch (module not found)", "Install PyTorch into the active environment.")
    else:
        record_pass("torch import succeeded.")
        # 4) torch version
        try:
            ver = getattr(torch, "__version__", None)
            if ver:
                print(f"INFO: torch version: {ver}")
                record_pass("torch version reported.")
            else:
                record_fail("torch version not reported.")
        except Exception as e:
            record_fail("Reading torch version failed: {}".format(e))
        # 5) torch HIP
        hip = None
        try:
            hip = getattr(torch.version, "hip", None)
        except Exception:
            hip = None
        if hip is not None:
            record_pass("torch.version.hip is available.")
        else:
            record_fail("torch.version.hip is not available.", "ROCm build not detected for torch.")

        # 6) CUDA available
        try:
            cuda_avail = bool(torch.cuda.is_available())
            if cuda_avail:
                record_pass("CUDA is available via torch.cuda.is_available().")
            else:
                record_fail("CUDA not available via torch.cuda.is_available().")
        except Exception as e:
            record_fail("CUDA availability check failed: {}".format(e))

        # 7) Device name
        try:
            if torch.cuda.is_available():
                name = torch.cuda.get_device_name(0)
                if name:
                    print(f"INFO: CUDA device name: {name}")
                    record_pass("Device name retrieved.")
                else:
                    record_fail("Device name is empty.")
            else:
                record_fail("CUDA not available (no device name).")
        except Exception as e:
            record_fail("Retrieving device name failed: {}".format(e))

        # 8) Device count
        try:
            count = int(torch.cuda.device_count())
            if count >= 1:
                record_pass(f"Device count: {count}.")
            else:
                record_fail("No CUDA devices detected.")
        except Exception as e:
            record_fail("Device count check failed: {}".format(e))

        # 9) GPU matmul test
        try:
            x = torch.randn((1024, 1024), device="cuda")
            y = x @ x
            torch.cuda.synchronize()
            if y.sum().item() != 0:
                record_pass("GPU matrix multiply produced non-zero results.")
            else:
                record_fail("GPU matmul produced zero results.")
        except Exception as e:
            record_fail("GPU matmul test failed: {}".format(e))

        # 10) Memory test
        try:
            mem = torch.cuda.memory_allocated()
            if mem is not None:
                record_pass(f"Memory allocated reported: {mem} bytes.")
            else:
                record_fail("Memory allocation query returned None.")
        except Exception as e:
            record_fail("Memory test failed: {}".format(e))

    # Optional ComfyUI import check
    if args.comfyui:
        try:
            import importlib
            importlib.import_module("ComfyUI")
            record_pass("ComfyUI imports succeed.")
        except Exception as e:
            record_fail("ComfyUI import failed: {}".format(e))

    # Optional HTTP smoke test
    if args.http:
        # Best-effort start and test HTTP endpoint
        try:
            proc = subprocess.Popen([sys.executable, "-m", "comfyui", "--host", "127.0.0.1", "--port", "8188"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            import time
            time.sleep(5)
            resp = None
            try:
                import urllib.request
                with urllib.request.urlopen("http://127.0.0.1:8188/health", timeout=5) as r:
                    resp = r.status
            except Exception:
                resp = None
            if resp in (200,):
                record_pass("HTTP health check passed.")
            else:
                record_fail("HTTP health check failed (no 200).", "Ensure ComfyUI starts correctly or skip with --http.")
        finally:
            try:
                proc.terminate()
            except Exception:
                pass

    # Final summary
    total_checks = total
    failures_count = len(failures)
    passes_count = passes
    print("\nSummary:")
    print(f"Total checks: {total}")
    print(f"Passed: {passes_count}")
    print(f"Failed: {failures_count}")
    if failures:
        print("Failures:")
        for desc, hint in failures:
            print(f"- {desc} | Suggest: {hint}")
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
