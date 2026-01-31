#!/usr/bin/env bash
set -euo pipefail

# PatchGate regression runner (Frozen v1)
# - Creates a minimal base git repo state required by PASS samples
# - Extracts all ```diff blocks from tests/patch_samples.md
# - Runs PatchGate and checks PASS/FAIL expectations deterministically

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "[patch_gate][run] missing cmd: $1" >&2; exit 1; }; }
need_cmd git
need_cmd awk
need_cmd grep
need_cmd mktemp

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "[patch_gate][run] repo root: $ROOT"
echo "[patch_gate][run] workdir:   $WORKDIR"

# -------------------------------------------------------------------
# 1) Initialize a clean git repo as base state
# -------------------------------------------------------------------
git init -q "$WORKDIR"
cd "$WORKDIR"

git config user.email "patchgate@test"
git config user.name "patchgate-test"

mkdir -p docs empty

# Base files required by PASS samples:
# - README.md exists and starts with "# PatchGate"
# - docs/to_delete.txt exists with "delete-me"
# - empty/old_empty.txt exists
echo "# PatchGate" > README.md
echo "delete-me" > docs/to_delete.txt
: > empty/old_empty.txt

git add .
git commit -qm "base state for PatchGate regression"

# -------------------------------------------------------------------
# 2) Extract all samples from tests/patch_samples.md
# -------------------------------------------------------------------
SAMPLES_DIR="$WORKDIR/samples"
CASES_LIST="$SAMPLES_DIR/cases.list"
mkdir -p "$SAMPLES_DIR"
: > "$CASES_LIST"

# Parser rules:
# - Section header: "## PASS-XX:" or "## FAIL-XX:"
# - Expect line: "Expected: PASS|FAIL" (optional; inferred from name if missing)
# - Code block: ```diff ... ```
awk -v outdir="$SAMPLES_DIR" '
  function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s; }
  BEGIN { name=""; expect=""; inside=0; file=""; }

  /^## (PASS|FAIL)-[0-9]+:/ {
    # Example: "## PASS-01: ..."
    header=substr($0,4)
    split(header, a, ":")
    name=trim(a[1])
    expect=""
    next
  }

  /^Expected:[ \t]+(PASS|FAIL)[ \t]*$/ {
    split($0, b, ":")
    expect=trim(b[2])
    next
  }

  /^```diff[ \t]*$/ {
    if (name=="") { name="UNNAMED"; }
    if (expect=="") { expect = (name ~ /^PASS-/ ? "PASS" : "FAIL"); }
    file=outdir "/" name ".diff"
    # truncate
    printf "" > file
    inside=1
    next
  }

  inside==1 && /^```[ \t]*$/ {
    inside=0
    # record case only if file has something (allow empty-file add/delete with no hunks is still a diff header, so non-empty)
    print name " " expect " " file >> (outdir "/cases.list")
    next
  }

  inside==1 {
    print $0 >> file
    next
  }
' "$ROOT/tests/patch_samples.md"

# Basic sanity: ensure we extracted at least one case
if ! test -s "$CASES_LIST"; then
  echo "[patch_gate][run] FAIL: no cases extracted from tests/patch_samples.md" >&2
  exit 1
fi

# -------------------------------------------------------------------
# 3) Run cases
# -------------------------------------------------------------------
run_case() {
  local name="$1"
  local expect="$2"
  local diff_file="$3"

  local tmpout
  tmpout="$(mktemp -t patchgate.run.XXXXXX)"
  # Always run gate in THIS workdir so git apply --check uses the base repo state.
  if "$ROOT/patch_gate.sh" "$diff_file" >/dev/null 2>"$tmpout"; then
    if [[ "$expect" == "PASS" ]]; then
      echo "[patch_gate][ok]  $name (PASS)"
      rm -f "$tmpout"
      return 0
    fi
    echo "[patch_gate][fail] $name unexpectedly PASSED" >&2
    echo "--- gate output ---" >&2
    cat "$tmpout" >&2
    rm -f "$tmpout"
    return 1
  else
    if [[ "$expect" == "FAIL" ]]; then
      # Enforce FAIL message contract
      if ! grep -q '\[patch_gate\] FAIL:' "$tmpout"; then
        echo "[patch_gate][fail] $name failed but missing '[patch_gate] FAIL:' marker" >&2
        echo "--- gate output ---" >&2
        cat "$tmpout" >&2
        rm -f "$tmpout"
        return 1
      fi
      echo "[patch_gate][ok]  $name (rejected as expected)"
      rm -f "$tmpout"
      return 0
    fi
    echo "[patch_gate][fail] $name unexpectedly FAILED" >&2
    echo "--- gate output ---" >&2
    cat "$tmpout" >&2
    rm -f "$tmpout"
    return 1
  fi
}

echo "[patch_gate][run] running cases..."
while read -r name expect path; do
  [[ -n "${name:-}" ]] || continue
  run_case "$name" "$expect" "$path"
done < "$CASES_LIST"

echo "[patch_gate][run] ALL REGRESSIONS OK"
