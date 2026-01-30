#!/usr/bin/env bash
# PatchGate — PP1 validator (Frozen v1)
# Goals:
# - minimal dependencies
# - fail-fast
# - safe-by-default
# - validates a git-style unified diff and that it applies cleanly

set -euo pipefail

die() { echo "[patch_gate] FAIL: $*" >&2; exit 1; }
info() { echo "[patch_gate] $*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

need_cmd git
need_cmd grep
need_cmd awk
need_cmd mktemp

TMP_PATCH="$(mktemp -t patchgate.XXXXXX.diff)"
cleanup() { rm -f "$TMP_PATCH" "$TMP_PATCH.__markercheck" 2>/dev/null || true; }
trap cleanup EXIT

if [[ "${1-}" == "" ]]; then
  cat > "$TMP_PATCH"
else
  [[ -f "$1" ]] || die "patch file not found: $1"
  cat "$1" > "$TMP_PATCH"
fi

[[ -s "$TMP_PATCH" ]] || die "empty patch"

# Must look like git unified diff (strictly requires a/ and b/ prefixes)
grep -qE '^diff --git a/[^ ]+ b/[^ ]+' "$TMP_PATCH" \
  || die "missing 'diff --git a/... b/...' header"

# Disallow binary patches
if grep -qE '^(GIT binary patch|Binary files )' "$TMP_PATCH"; then
  die "binary patch not allowed"
fi

# Disallow rename/copy operations (auditable minimal protocol)
if grep -qE '^(rename from|rename to|copy from|copy to) ' "$TMP_PATCH"; then
  die "rename/copy operations are not allowed"
fi

# Disallow symlinks/submodules by mode
if grep -qE '^(new file mode|deleted file mode|old mode|new mode) (120000|160000)\b' "$TMP_PATCH"; then
  die "symlinks (120000) and submodules (160000) are not allowed"
fi

# If any mode lines exist, ALL must be 100644 or 100755
if grep -qE '^(new file mode|deleted file mode|old mode|new mode) ' "$TMP_PATCH"; then
  if grep -E '^(new file mode|deleted file mode|old mode|new mode) ' "$TMP_PATCH" \
    | grep -vE '^(new file mode|deleted file mode|old mode|new mode) (100644|100755)\b' \
    | grep -q .; then
    die "file mode must be 100644 or 100755 only"
  fi
fi

# Path safety checks on diff headers
awk '
  $1=="diff" && $2=="--git" {
    a=$3; b=$4;
    sub(/^a\//,"",a); sub(/^b\//,"",b);
    if (a!=b) { print "mismatch paths in diff header: " a " vs " b; exit 2; }
    if (a ~ /^\// || a ~ /^\.$/ || a ~ /^$/) { print "invalid path: " a; exit 2; }
    if (a ~ /\.\.\// || a ~ /\/\.\./ || a ~ /^\.\./) { print "unsafe path: " a; exit 2; }
    if (a ~ /\\\\/) { print "backslash path not allowed: " a; exit 2; }
    if (a ~ /^\.git\//) { print "touching .git/ is not allowed: " a; exit 2; }
  }
' "$TMP_PATCH" || die "path safety check failed"

# Disallow absolute paths in ---/+++ lines (except /dev/null)
if grep -E '^(---|\+\+\+) /' "$TMP_PATCH" | grep -vE '^(---|\+\+\+) /dev/null$' | grep -q .; then
  die "absolute paths not allowed in ---/+++ markers (except /dev/null)"
fi
if grep -qE '^(---|\+\+\+) [A-Za-z]:\\\\' "$TMP_PATCH"; then
  die "absolute paths not allowed in ---/+++ markers"
fi

# Per-file marker validation (---/+++ must match diff header, with /dev/null rules for add/delete)
# Also detects whether any section is a pure modification (neither new nor deleted).
awk '
function reset_section() { path=""; is_new=0; is_del=0; old=""; new=""; }
function validate_section() {
  if (path=="") return;
  if (is_new) {
    if (old != "/dev/null") { print "new file must use --- /dev/null for " path; exit 2 }
    if (new != "b/" path)   { print "new file must use +++ b/" path " for " path; exit 2 }
  } else if (is_del) {
    if (old != "a/" path)   { print "deleted file must use --- a/" path " for " path; exit 2 }
    if (new != "/dev/null") { print "deleted file must use +++ /dev/null for " path; exit 2 }
  } else {
    any_modified=1;
    if (old != "a/" path)   { print "modified file must use --- a/" path " for " path; exit 2 }
    if (new != "b/" path)   { print "modified file must use +++ b/" path " for " path; exit 2 }
  }
}
BEGIN { any_modified=0; reset_section(); }
$1=="diff" && $2=="--git" {
  validate_section();
  a=$3; b=$4; sub(/^a\//,"",a); sub(/^b\//,"",b);
  if (a!=b) { print "mismatch paths in diff header: " a " vs " b; exit 2 }
  path=a; is_new=0; is_del=0; old=""; new=""; next;
}
/^new file mode /      { is_new=1; next }
/^deleted file mode /  { is_del=1; next }
/^--- /                { old=substr($0,5); next }
/^\+\+\+ /             { new=substr($0,5); next }
END {
  validate_section();
  if (any_modified) print "ANY_MODIFIED=1"; else print "ANY_MODIFIED=0";
}
' "$TMP_PATCH" >"$TMP_PATCH.__markercheck" || die "---/+++ marker validation failed"

ANY_MODIFIED="$(tail -n 1 "$TMP_PATCH.__markercheck" | awk -F= '{print $2}')"

HAS_HUNK=0
if grep -qE '^@@ ' "$TMP_PATCH"; then
  HAS_HUNK=1
fi

# Allow no-hunk patches ONLY when they consist solely of add/delete empty files.
# If there are any modified sections (neither new nor deleted), require hunks.
if [[ "$HAS_HUNK" -eq 0 ]]; then
  if [[ "$ANY_MODIFIED" == "1" ]]; then
    die "no hunks found (modifications without hunks are not allowed)"
  fi
fi

info "running: git apply --check --whitespace=error"
git apply --check --whitespace=error "$TMP_PATCH" >/dev/null 2>&1 \
  || die "git apply --check failed"

info "PASS"
exit 0
