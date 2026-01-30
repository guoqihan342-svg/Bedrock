# Frozen Charter v1 — PatchGate (FROZEN)

Status: FROZEN v1  
Rule: Any change that modifies meaning (allow/deny rules, output contract, safety model, gate semantics) MUST bump major version (v2/v3).  
No silent mutations.

---

## 0) Purpose (one sentence)

PatchGate provides a minimal, agent-first foundation to make AI/LLM repo edits **auditable, verifiable, and safe** by enforcing a single interface:
**one unified diff patch**, validated by a strict gate and enforced by CI.

---

## 1) Scope

This project defines:
- A strict **agent behavior contract** (`AGENTS.md`)
- A strict **patch protocol** (`PATCH_SPEC.md`)
- A strict **gate implementation** (`patch_gate.sh`)
- A **frozen regression corpus** (`tests/patch_samples.md`) and runner (`tests/run.sh`)
- CI enforcement (GitHub Actions workflow)

Non-goals:
- Not a full testing/lint/build system
- Not a performance benchmark
- Not an IDE/toolchain ecosystem
- Not human-friendly documentation first; machine clarity first

---

## 2) Platform & Environment (Linux-first)

The reference environment is GitHub Actions `ubuntu-latest` and Linux shells.

Minimum required tools:
- bash
- git
- awk
- grep
- mktemp

No network access required. No external runtime dependencies.

---

## 3) The ONLY accepted edit interface (Frozen)

### 3.1 Output contract (B chapter — FROZEN DEFAULT)
Agents MUST:
- Output **exactly one** fenced code block with language tag `diff`
- Contain a **git-style unified diff** starting with `diff --git a/... b/...`

Outside the diff block:
- Allowed: nothing OR a single optional line `PATCH READY`
- Disallowed: any other prose, explanation, file dumps, multiple blocks, multi-patch outputs

If insufficient info:
- Output **no patch**
- Output exactly one line: `NEED INFO: <one question>`

### 3.2 Patch protocol (Frozen)
The canonical protocol is `PATCH_SPEC.md` and is enforced by `patch_gate.sh`.

---

## 4) Safety model (deny-by-default) — FROZEN

Hard-fail categories (MUST be rejected by gate and CI):
- Binary patches (`GIT binary patch`, `Binary files ...`)
- Symlinks (mode 120000) and submodules (mode 160000)
- Rename/copy operations (`rename from/to`, `copy from/to`)
- Any patch that touches `.git/`
- Path traversal (`../`), absolute paths, or backslashes in paths
  - Exception: `/dev/null` is allowed ONLY in `---/+++` markers for add/delete
- Marker/header mismatch (diff header path differs from `---/+++` targets)
- Illegal file modes (any mode not exactly `100644` or `100755`)
- Mode-only patches (policy: not allowed)

Allowed categories (MUST be accepted when valid and applicable):
- Modify existing text files with hunks
- Add new text files (with correct `/dev/null` markers)
- Delete existing text files (with correct `/dev/null` markers)
- Add/delete empty files may have no hunks (allowed only for pure add/delete sections)

---

## 5) Verification contract — FROZEN

A patch is valid if and only if:
1) It conforms to the frozen rules above AND `PATCH_SPEC.md`, AND
2) It passes `patch_gate.sh`, including:
   - Safety checks
   - Per-file marker validation
   - `git apply --check --whitespace=error` clean-apply verification

---

## 6) Regression contract — FROZEN

`tests/patch_samples.md` is a **frozen regression corpus**.

Rules:
- Every PASS sample MUST PASS (exit 0)
- Every FAIL sample MUST FAIL (non-zero) AND output includes `[patch_gate] FAIL:`

`tests/run.sh` is the reference runner.

Any change to `patch_gate.sh` MUST:
- Preserve the expected outcomes on this corpus
- Unless a major bump explicitly changes the protocol (v2/v3)

---

## 7) CI policy — FROZEN

Reference CI: GitHub Actions.

Required PR checks (must be green to merge):
- Regression: `./tests/run.sh`
- PR patch validation: generate PR base→head diff (no renames) and validate it with PatchGate

Branch protection is recommended:
- Require PatchGate workflow to pass before merge
- PR-only merges (no direct pushes to main)

---

## 8) How to judge whether an “optimization” is successful (merge criteria)

### 8.1 Hard gates (any fail => DO NOT MERGE)
- Protocol meaning unchanged (or major bump explicitly declared)
- Regression passes (`tests/run.sh`)
- No new false negatives (dangerous patches must remain blocked)
- No regressions on must-pass cases (basic modify/add/delete/empty-file behavior remains consistent)

### 8.2 Value scoring (merge only if value is real)
Improvements are considered valuable when they do at least one of:
- Reduce false positives (legitimate patches previously blocked now pass) without introducing any false negatives
- Improve error messages to be more actionable and specific
- Reduce runtime or keep runtime stable (CI remains fast)
- Improve code clarity / reduce complexity / reduce dependency assumptions
- Improve doc ↔ gate behavior consistency

---

## 9) Change management (versioning) — FROZEN

Major bump required if:
- Any allow/deny rule changes
- Output contract changes (format, multi-patch, prose allowance)
- Safety model changes (what is blocked/allowed)
- Gate semantics change in a way that affects protocol meaning

Patch-level changes allowed without major bump only for:
- Bugfixes that restore intended behavior consistent with v1 meaning
- More precise error messages
- Refactoring that preserves behavior
- CI robustness improvements that preserve semantics

---

## 10) Repository artifacts (v1 set)

Core:
- AGENTS.md
- PATCH_SPEC.md
- patch_gate.sh

Regression:
- tests/patch_samples.md
- tests/run.sh

CI:
- .github/workflows/patchgate.yml

Docs/Legal/Process:
- README.md
- FROZEN_CHARTER_v1.md
- CONTRIBUTING.md
- SECURITY.md
- CHANGELOG.md
- LICENSE
- .github/pull_request_template.md
- .github/ISSUE_TEMPLATE/bug_report.md

End of Frozen Charter v1.
