#!/usr/bin/env bash
set -euo pipefail

# CI smoke for GitHub Actions (no baselines generated here)
# Purpose:
# - Ensure build succeeds
# - Ensure bench runs and outputs valid JSON
# - Ensure correctness gate passes (exit code 0)
#
# Policy:
# - DO NOT generate baseline in CI.
# - DO NOT treat CI numbers as truth source.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${BEDROCK_CI_OUT_DIR:-$ROOT/bench/out}"
TARGET_NAME="${BEDROCK_CI_TARGET_NAME:-linux_x86_64_avx2}"
VARIANT="${BEDROCK_CI_VARIANT:-scalar}"

mkdir -p "$OUT_DIR"

echo "[bedrock] CI smoke"
echo "[bedrock] target:  $TARGET_NAME"
echo "[bedrock] variant: $VARIANT"
echo "[bedrock] outdir:  $OUT_DIR"

# Build (stable, comparable defaults)
"$ROOT/scripts/build.sh" --release

OUT_JSON="$OUT_DIR/ci_smoke.${TARGET_NAME}.${VARIANT}.json"

# Run bench
"$ROOT/scripts/bench.sh" "$TARGET_NAME" --variant "$VARIANT" --out "$OUT_JSON"

if [[ ! -s "$OUT_JSON" ]]; then
  echo "[bedrock] ERROR: output JSON missing/empty: $OUT_JSON" >&2
  exit 10
fi

# Validate JSON quickly (python3 preferred)
if command -v python3 >/dev/null 2>&1; then
  python3 - <<PY
import json, sys
p = r"""$OUT_JSON"""
with open(p, "r", encoding="utf-8") as f:
    d = json.load(f)

assert d.get("suite_id") == "bench_spec_v1", "suite_id mismatch"
res = d.get("results", [])
assert isinstance(res, list) and len(res) > 0, "results missing/empty"

bad = [r for r in res if not r.get("correct", False)]
if bad:
    print("FAIL: correctness failed for some results", file=sys.stderr)
    for r in bad[:20]:
        print("  bad:", r.get("kernel"), r.get("variant"), r.get("n"),
              "abs=", r.get("error_abs"), "rel=", r.get("error_rel"), file=sys.stderr)
    sys.exit(2)

print("[bedrock] json ok, correctness ok")
PY
else
  # best-effort fallback: very shallow check
  if ! grep -q '"suite_id"[[:space:]]*:[[:space:]]*"bench_spec_v1"' "$OUT_JSON"; then
    echo "[bedrock] ERROR: suite_id not found in JSON (python3 missing for strong validation)" >&2
    exit 11
  fi
  echo "[bedrock] WARN: python3 missing; only shallow JSON validation performed." >&2
fi

echo "[bedrock] CI smoke OK"
