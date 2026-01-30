# Security Policy (PatchGate v1)

PatchGate is a **deny-by-default** safety gate for AI/agent-driven repository changes.
This document describes the security boundaries and threat model for v1.

Status: Applies to **Frozen Charter v1**.

---

## 1) Security goals

PatchGate v1 aims to:
- Prevent unsafe or hard-to-audit patch patterns from being merged.
- Enforce a strict, machine-verifiable change interface (unified diff only).
- Reduce risk from AI/agent hallucinations or uncontrolled edits.

PatchGate is a **policy gate**, not a full security solution for your application.

---

## 2) Non-goals

PatchGate v1 does NOT:
- Run project tests, SAST/DAST, dependency scanning, or supply-chain verification.
- Guarantee code correctness or eliminate vulnerabilities in the code being changed.
- Provide runtime sandboxing or isolation.
- Prevent malicious logic inside otherwise valid text diffs (review and tests still matter).

---

## 3) Threat model (what v1 explicitly blocks)

PatchGate v1 hard-rejects:
- Binary patches (`GIT binary patch`, `Binary files ...`)
- Symlinks (mode `120000`) and submodules (mode `160000`)
- Rename/copy metadata (`rename from/to`, `copy from/to`)
- Patches touching `.git/` internals
- Path traversal (`../`), backslashes in paths, absolute paths
  - Exception: `/dev/null` allowed only in `---/+++` markers for add/delete
- Marker/header mismatch (diff header path differs from `---/+++` targets)
- Illegal modes (anything not exactly `100644` or `100755`)
- Mode-only patches (policy: not allowed)

Additionally:
- Patch must apply cleanly (`git apply --check --whitespace=error`).

---

## 4) Residual risks (what v1 does NOT block)

Even with PatchGate, the following remain possible:
- Malicious or buggy logic inserted as normal text changes.
- Secrets accidentally committed as text.
- Vulnerable dependencies introduced by text edits.
- Social engineering via PR descriptions, issue comments, etc.

Mitigations (out of scope for v1, optional to add in downstream repos):
- Mandatory code review and tests
- Secret scanning
- Dependency review / lockfile policies
- Static analysis and CI security tooling

---

## 5) Reporting a security issue

If you believe PatchGate has a security weakness (e.g., a false negative that should be blocked):
- Provide a minimal patch reproducer (`.diff`) and explain expected vs actual outcome.
- Include the output of:
  - `./patch_gate.sh <your.diff>`
- Include environment details if relevant:
  - OS, shell, git version

For public repos:
- Prefer opening an issue labeled `security` with a minimal reproducible diff
- If the issue is sensitive, use private disclosure channels appropriate to your org

---

## 6) Versioning & security changes

PatchGate protocol semantics are frozen by major version.
Security-relevant policy changes require a major bump (v2/v3) and explicit documentation.

v1 remains deny-by-default.
