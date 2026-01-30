# AGENTS.md — Agent Constitution (Frozen v1)

Status: **FROZEN v1**  
Rule: Any change that modifies meaning (allow/deny rules, output contract, safety model) MUST bump major version (v2/v3). No silent mutations.

This repository is **agent-first**. All automated changes MUST follow PatchGate.

---

## 0) Mission

Your job is to produce repository changes that are:
- **Auditable** (diff-only, minimal)
- **Verifiable** (must pass PatchGate)
- **Safe-by-default** (deny dangerous operations)

PatchGate is the only accepted edit interface.

---

## 1) Non-negotiable Rules

### R1 — Output format (STRICT)
You MUST output exactly **one** fenced code block:
- Language tag MUST be `diff`
- Content MUST be a **git-style unified diff** starting with:
  - `diff --git a/... b/...`

Outside the diff block:
- Allowed: nothing OR a single optional line `PATCH READY`
- Disallowed: any other prose, explanations, summaries, file dumps, multiple code blocks, or multi-patch outputs

### R2 — If information is missing
If you cannot proceed safely due to missing context:
- Output **NO patch**
- Output exactly one line:
  - `NEED INFO: <one question>`

### R3 — Patch must be verifiable
- The patch MUST pass `./patch_gate.sh`.
- The patch MUST apply cleanly to the current repo state:
  - No guessing file contents
  - No partial patches

### R4 — Minimal change principle
- Change only what is necessary to satisfy the request.
- Avoid refactors, renames, formatting-only churn, and large reorganizations unless explicitly requested.

### R5 — Safety constraints (HARD FAIL)
You MUST NOT produce patches that include:
- Binary patches (`GIT binary patch` / `Binary files ...`)
- Symlinks (`120000`) or submodules (`160000`)
- Rename/copy operations (`rename from/to`, `copy from/to`)
- Any touch of `.git/` internals
- Path traversal (`../`), backslashes in paths, absolute paths
  - Exception: `/dev/null` is allowed ONLY in `---/+++` markers for add/delete
- Marker/header mismatch (diff header path differs from `---/+++` targets)
- Illegal file modes (anything not exactly `100644` or `100755`)
- Mode-only patches

### R6 — Determinism / Minimal dependencies
- Do not introduce randomness, time-based logic, or environment-dependent behavior.
- Do not add runtime dependencies beyond: bash, git, awk, grep, mktemp.

---

## 2) Patch Protocol

The canonical protocol is defined in: `PATCH_SPEC.md`  
You MUST comply with it.

---

## 3) Gate validation

To validate a patch:
- `chmod +x patch_gate.sh`
- `./patch_gate.sh < change.diff`
- or `./patch_gate.sh change.diff`

Exit code `0` means PASS. Any non-zero means FAIL.

---

## 4) Workflow (required)

1) Inspect existing repository structure and relevant files.
2) Decide the smallest valid edit set.
3) Produce a unified diff patch (PP1 / Frozen v1).
4) Ensure it passes PatchGate.
5) Output ONLY the patch (plus optional `PATCH READY`).

---

End of AGENTS.md (Frozen v1).
