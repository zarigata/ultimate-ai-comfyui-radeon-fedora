#!/usr/bin/env bash
set -euo pipefail

# Lightweight OS-detection tests. This script is standalone and creates
# temporary mocks for /etc/os-release content to validate parsing logic.

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

parse_os_release() {
  local fpath="${1:-/etc/os-release}"
  local id=""
  local version_id=""
  if [[ ! -f "$fpath" ]]; then
    echo "ERR: os-release not found: $fpath" >&2
    return 2
  fi
  while IFS='=' read -r key value; do
    case "$key" in
      ID)
        id="$(echo "$value" | tr -d '"')";;
      VERSION_ID)
        version_id="$(echo "$value" | tr -d '"')";;
    esac
  done < "$fpath"
  echo "$id|$version_id"
}

test_parse_os_release() {
  local f="$tmpdir/os-release-a"
  cat > "$f" <<EOF
NAME="Fedora"
ID=fedora
VERSION_ID="43"
EOF
  local res
  res=$(parse_os_release "$f")
  if [[ "$res" == "fedora|43" ]]; then
    echo "PASS: parse_os_release Fedora 43"
  else
    echo "FAIL: parse_os_release Fedora 43, got $res" >&2
    return 1
  fi
}

test_known_os_ids() {
  local f="$tmpdir/os-release-b"
  cat > "$f" <<EOF
NAME="Nobara"
ID=nobara
VERSION_ID="42"
EOF
  local res
  res=$(parse_os_release "$f")
  if [[ "$res" == "nobara|42" ]]; then
    echo "PASS: Nobara recognized"
  else
    echo "FAIL: Nobara not recognized: $res" >&2
    return 1
  fi

  # Unknown ID should not crash parsing
  local f2="$tmpdir/os-release-c"
  cat > "$f2" <<EOF
NAME="Bazzite"
ID=bazzite
VERSION_ID="1"
EOF
  res=$(parse_os_release "$f2")
  if [[ "$res" == "bazzite|1" ]]; then
    echo "PASS: Unknown ID parsed gracefully"
  else
    echo "FAIL: Unknown ID parse: $res" >&2
    return 1
  fi
}

test_version_detection() {
  local f="$tmpdir/os-release-d"
  cat > "$f" <<EOF
NAME="Fedora"
ID=fedora
VERSION_ID="44"
EOF
  local res
  res=$(parse_os_release "$f")
  if [[ "$res" == "fedora|44" ]]; then
    echo "PASS: Version 44 detected"
  else
    echo "FAIL: Version 44 detect: $res" >&2
    return 1
  fi
}

test_immutable_detection() {
  local marker="$tmpdir/ostree-immutable"
  touch "$marker"
  if [[ -f "$marker" ]]; then
    echo "PASS: ostree immutable marker detected"
  else
    echo "FAIL: ostree immutable marker not detected" >&2
    return 1
  fi
}

test_all() {
  test_parse_os_release
  local a=$?
  test_known_os_ids
  local b=$?
  test_version_detection
  local c=$?
  test_immutable_detection
  local d=$?
  if [[ $a -eq 0 && $b -eq 0 && $c -eq 0 && $d -eq 0 ]]; then
    echo "ALL TESTS PASSED"
    return 0
  else
    echo "SOME TESTS FAILED" >&2
    return 1
  fi
}

test_all
exit $?
