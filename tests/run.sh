#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tests/run.sh --integration [--new-only <manifest>] [--component <name>]
  tests/run.sh --unit        [--new-only <manifest>] [--component <name>]
  tests/run.sh --smoke       [--new-only <manifest>] [--component <name>]
EOF
}

SUITE=""
NEW_ONLY_MANIFEST=""
COMPONENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke|--unit|--integration)
      SUITE="${1#--}"
      shift
      ;;
    --new-only)
      NEW_ONLY_MANIFEST="${2:-}"
      shift 2
      ;;
    --component)
      COMPONENT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$SUITE" ]]; then
  echo "Missing suite flag (--smoke|--unit|--integration)" >&2
  usage >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="${ROOT_DIR}/tests"
MANIFESTS_DIR="${TESTS_DIR}/manifests"

_run_entry() {
  local suite="$1"
  local script="$2"
  local fn="${3:-}"
  local script_path="${TESTS_DIR}/${suite}/${script}"

  if [[ ! -f "$script_path" ]]; then
    echo "Missing test script: ${script_path}" >&2
    return 1
  fi

  if [[ -z "$fn" ]]; then
    bash "$script_path"
    return $?
  fi

  # shellcheck disable=SC1090
  source "$script_path"
  if ! declare -F "$fn" >/dev/null; then
    echo "Missing test function '${fn}' in ${script_path}" >&2
    return 1
  fi
  "$fn"
}

entries=()

if [[ -n "$NEW_ONLY_MANIFEST" ]]; then
  if [[ ! -f "$NEW_ONLY_MANIFEST" ]]; then
    echo "Missing manifest: ${NEW_ONLY_MANIFEST}" >&2
    exit 2
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    entries+=("$line")
  done <"$NEW_ONLY_MANIFEST"
elif [[ -n "$COMPONENT" ]]; then
  manifest="${MANIFESTS_DIR}/component_${COMPONENT}.manifest"
  if [[ ! -f "$manifest" ]]; then
    echo "Missing component manifest: ${manifest}" >&2
    exit 2
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    entries+=("$line")
  done <"$manifest"
else
  while IFS= read -r -d '' f; do
    entries+=("${SUITE}:$(basename "$f")")
  done < <(find "${TESTS_DIR}/${SUITE}" -maxdepth 1 -type f -name "test_*.sh" -print0 | sort -z)
fi

rc=0
fails=0
passes=0

for e in "${entries[@]}"; do
  IFS=: read -r e_suite e_script e_fn <<<"$e"
  [[ "$e_suite" != "$SUITE" ]] && continue

  echo "=== RUN ${e_suite}:${e_script}${e_fn:+:${e_fn}} ==="
  if _run_entry "$e_suite" "$e_script" "${e_fn:-}"; then
    echo "=== PASS ${e_suite}:${e_script}${e_fn:+:${e_fn}} ==="
    passes=$((passes + 1))
  else
    echo "=== FAIL ${e_suite}:${e_script}${e_fn:+:${e_fn}} ==="
    fails=$((fails + 1))
    rc=1
  fi
done

echo "=== SUMMARY suite=${SUITE} pass=${passes} fail=${fails} ==="
exit "$rc"

