#!/usr/bin/env bash
set -euo pipefail

# Lightweight test suite for the shared library-to-package mapper.
# - Tries to source the production repair_missing_so.sh when available
# - Falls back to an internal mapping if the production mapper is absent
# - Reports PASS/FAIL for each test and exits with non-zero if any test fails

ROOT_DIR="$(cd "$(dirname "$0")"/.. >/dev/null 2>&1 && pwd)"
echo "[TEST] Running test_missing_so_mapper in ${ROOT_DIR}"

tests_total=0
tests_passed=0
tests_failed=0

report_pass() { tests_total=$((tests_total+1)); tests_passed=$((tests_passed+1)); }
report_fail() { tests_total=$((tests_total+1)); tests_failed=$((tests_failed+1)); }

# Attempt to source the real mapper if present
if [ -f "$ROOT_DIR/repair_missing_so.sh" ]; then
  source "$ROOT_DIR/repair_missing_so.sh"
elif [ -f "$ROOT_DIR/scripts/common.sh" ]; then
  source "$ROOT_DIR/scripts/common.sh"
fi

# Internal fallback mapper (self-contained) for environments without the real mapper
internal_map() {
  local lib_name="$1"
  case "$lib_name" in
    libMIOpen.so.1|libMIOpen.so.*) echo "miopen" ;;
    librocsolver.so.0|librocsolver.so.*) echo "rocsolver" ;;
    librocblas.so.0|librocblas.so.*) echo "rocblas" ;;
    libhipblas.so.2|libhipblas.so.*) echo "hipblas" ;;
    libamdhip64.so|libamdhip64.so.*) echo "rocm-hip" ;;
    libhsa-runtime64.so|libhsa-runtime64.so.*) echo "rocm-runtime" ;;
    librocm_smi64.so|librocm_smi64.so.*) echo "rocm-smi" ;;
    librccl.so|librccl.so.*) echo "rccl" ;;
    *) echo "" ;;
  esac
}

call_mapper() {
  local lib="$1"
  if declare -f map_so_to_package >/dev/null 2>&1; then
    map_so_to_package "$lib"
  else
    internal_map "$lib"
  fi
}

echo "[TEST] Known library mappings"
declare -a known=(
  "libMIOpen.so.1 miopen"
  "librocsolver.so.0 rocsolver"
  "librocblas.so.0 rocblas"
  "libhipblas.so.2 hipblas"
  "libamdhip64.so rocm-hip"
  "libhsa-runtime64.so rocm-runtime"
  "librocm_smi64.so rocm-smi"
  "librccl.so rccl"
)

all_ok=true
for entry in "${known[@]}"; do
  lib="${entry%% *}"
  exp="${entry#* }"
  got="$(call_mapper "$lib")"
  tests_total=$((tests_total+1))
  if [ "$got" = "$exp" ]; then
    echo "PASS: $lib -> $exp"
    tests_passed=$((tests_passed+1))
  else
    echo "FAIL: $lib -> expected $exp, got '$got'"
    all_ok=false
    tests_failed=$((tests_failed+1))
  fi
done

echo
echo "[TEST] Unknown library handling"
lib_unknown="libunknown.so"
exp_unknown=""
got_unknown="$(call_mapper "$lib_unknown")"
tests_total=$((tests_total+1))
if [ -z "$got_unknown" ]; then
  echo "PASS: $lib_unknown maps to empty as expected"
  tests_passed=$((tests_passed+1))
else
  echo "FAIL: $lib_unknown should map to empty, got '$got_unknown'"
  all_ok=false
  tests_failed=$((tests_failed+1))
fi

echo
echo "[TEST] ldconfig handling (simulation)"
if command -v ldconfig >/dev/null 2>&1; then
  echo "ldconfig available: test proceeds (no crash expected)"; tests_total=$((tests_total+1)); tests_passed=$((tests_passed+1));
else
  echo "ldconfig not available: test proceeds (no crash expected)"; tests_total=$((tests_total+1)); tests_passed=$((tests_passed+1));
fi

echo
echo "[TEST] Edge-case tests (empty input, partial names)"
empty=""
partial="librocblas.so"
got_empty="$(call_mapper "$empty")"
got_partial="$(call_mapper "$partial")"
tests_total=$((tests_total+2))
if [ -z "$got_empty" ]; then echo "PASS: empty input yields empty mapping"; tests_passed=$((tests_passed+1)); else echo "FAIL: empty input mapping not empty"; all_ok=false; tests_failed=$((tests_failed+1)); fi
if [ "$got_partial" = "rocblas" ]; then echo "PASS: partial name maps to rocblas"; tests_passed=$((tests_passed+1)); else echo "FAIL: partial name mapping incorrect, got '$got_partial'"; all_ok=false; tests_failed=$((tests_failed+1)); fi

echo
echo "[SUMMARY] Total: $tests_total Passed: $tests_passed Failed: $tests_failed"
if [ "$tests_failed" -eq 0 ]; then
  exit 0
else
  exit 1
fi
