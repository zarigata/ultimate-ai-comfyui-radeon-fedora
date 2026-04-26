#!/usr/bin/env bash
set -euo pipefail

# Comprehensive smoke test for the repository
# - Runs non-destructively; only checks presence, syntax, and basic structure
# - Shellcheck tests are tolerant: failures are counted but do not abort the suite

ROOT_DIR="$(cd "$(dirname "$0")"/.. >/dev/null 2>&1 && pwd)"
echo "[SMOKE] Repo root: ${ROOT_DIR}"

TOTAL=0
PASS=0
FAIL=0
WARN=0

report_pass() { TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); }
report_fail() { TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); }
report_warn() { TOTAL=$((TOTAL+1)); WARN=$((WARN+1)); }

###########################################
# 1. Repo structure checks
###########################################
MISSING=false
REQUIRED_FILES=(
  install.sh run.sh doctor.sh repair.sh uninstall.sh
  README.md FLAGS.md MODELS.md TROUBLESHOOTING.md SAFETY.md NO-WARRANTY.md LICENSE
  scripts/verify_gpu.py
  prompts/video_prompt.txt prompts/shot_list_template.md
)

for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -e "$ROOT_DIR/$f" ]; then
    echo "MISSING: $f" >&2
    MISSING=true
  fi
done
if [ "$MISSING" = false ]; then
  echo "OK: All required top-level files present"; report_pass
else
  echo "ERROR: Missing required top-level files"; report_fail
fi

# Directories/files under scripts, tests, workflows, prompts
REQUIRED_DIRS=( scripts tests workflows prompts )
for d in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "$ROOT_DIR/$d" ]; then
    echo "MISSING_DIR: $d" >&2
    MISSING=true
  fi
done
if [ "$MISSING" = false ]; then
  report_pass
else
  report_fail
fi

###########################################
# 2. Shellcheck (if available)
###########################################
SH_FILES=()
while IFS= read -r -d '' f; do
  SH_FILES+=("$f")
done < <(find "$ROOT_DIR" -type f -name "*.sh" -print0 2>/dev/null)

if command -v shellcheck >/dev/null 2>&1; then
  echo "[SMOKE] Running shellcheck on ${#SH_FILES[@]} shell script(s)"
  for f in "${SH_FILES[@]}"; do
    if shellcheck -x -s bash "$f"; then
      :
    else
      echo "SHELLCHECK FAILED: $f" >&2
      report_fail
    fi
  done
else
  echo "WARNING: shellcheck not installed; skipping shellcheck checks" >&2
  report_warn
fi

###########################################
# 3. Script executable check
###########################################
UNEXECUTABLE=()
for f in "${SH_FILES[@]}"; do
  if [ ! -x "$f" ]; then
    UNEXECUTABLE+=("$f")
  fi
done
if [ ${#UNEXECUTABLE[@]} -eq 0 ]; then
  echo "OK: All .sh scripts have +x permission"; report_pass
else
  for f in "${UNEXECUTABLE[@]}"; do echo "NOT_EXECUTABLE: $f"; done 1>&2; report_fail
fi

###########################################
# 4. Bash syntax check (-n)
###########################################
SYNTAX_FAIL=()
for f in "${SH_FILES[@]}"; do
  if ! bash -n "$f" 2>&1; then
    SYNTAX_FAIL+=("$f")
  fi
done
if [ ${#SYNTAX_FAIL[@]} -eq 0 ]; then
  echo "OK: All shells syntax-checked with bash -n"; report_pass
else
  for f in "${SYNTAX_FAIL[@]}"; do echo "BASH-NO: $f"; done 1>&2; report_fail
fi

###########################################
# 5. Python syntax check for verify_gpu.py
###########################################
PY_FILE="$ROOT_DIR/scripts/verify_gpu.py"
if [ -f "$PY_FILE" ]; then
  if python3 -m py_compile "$PY_FILE"; then
    echo "OK: Python syntax for $PY_FILE"; report_pass
  else
    echo "PYTHON_SYNTAX_ERROR: $PY_FILE" >&2; report_fail
  fi
else
  echo "WARN: Python file not found: $PY_FILE" >&2; report_warn
fi

###########################################
# 6. Documentation checks (non-empty with a title)
###########################################
MD_FILES=( $(find "$ROOT_DIR" -iname "*.md" -type f 2>/dev/null) )
MD_FAIL=()
for f in "${MD_FILES[@]}"; do
  if [ ! -s "$f" ]; then
    MD_FAIL+=("$f (empty)")
  elif ! grep -qE '^# ' "$f"; then
    MD_FAIL+=("$f (no title)")
  fi
done
if [ ${#MD_FAIL[@]} -eq 0 ]; then
  echo "OK: All markdown docs are non-empty with a title"; report_pass
else
  for m in "${MD_FAIL[@]}"; do echo "DOC_FAIL: $m"; done 1>&2; report_fail
fi

###########################################
# 7. install.sh content check
###########################################
if [ -f "$ROOT_DIR/install.sh" ]; then
  if grep -qE 'set\s+-e|pipefail' "$ROOT_DIR/install.sh"; then
    echo "OK: install.sh contains set -e and pipefail"; report_pass
  else
    echo "INSTALL_CHECK: missing set -e/pipefail in install.sh"; report_fail
  fi
  if grep -E '/scripts/.*\.sh' "$ROOT_DIR/install.sh" >/dev/null 2>&1; then
    echo "OK: install.sh sources scripts/*.sh"; report_pass
  else
    echo "INSTALL_CHECK: install.sh does not source scripts/*.sh"; report_fail
  fi
else
  echo "WARN: install.sh not found"; report_warn
fi

###########################################
# 8. run.sh content check (subcommand handling)
###########################################
if [ -f "$ROOT_DIR/run.sh" ]; then
  if grep -Eqi 'case[[:space:]]+.*in|getopt' "$ROOT_DIR/run.sh"; then
    echo "OK: run.sh contains subcommand handling (case/getopt)"; report_pass
  else
    echo "RUN_CHECK: run.sh may not have proper subcommand handling"; report_fail
  fi
else
  echo "WARN: run.sh not found"; report_warn
fi

###########################################
# Summary
###########################################
echo "\nSMOKE TEST SUMMARY:"
echo "Total tests: ${TOTAL} | Passed: ${PASS} | Failed: ${FAIL} | Warnings: ${WARN}"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
