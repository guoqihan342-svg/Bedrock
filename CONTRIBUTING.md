# Contributing to PatchGate (Frozen v1)

PatchGate is intentionally minimal. Contributions must preserve:
- Frozen v1 protocol semantics
- strict safety defaults (deny-by-default)
- deterministic, auditable behavior
- minimal dependencies (Linux-first)

---

## 1) Ground rules (non-negotiable)

### 1.1 Frozen protocol
`AGENTS.md`, `PATCH_SPEC.md`, and `FROZEN_CHARTER_v1.md` define **Frozen v1** semantics.

- Do NOT silently change meaning (allow/deny rules, output contract, safety model, gate semantics).
- If a semantic change is required, it MUST be a major bump (v2/v3) and explicitly documented.

### 1.2 Minimal dependencies
Do not add runtime dependencies beyond:
- bash
- git
- awk
- grep
- mktemp

No network calls. No installers.

### 1.3 Determinism
No random behavior, time-based logic, or environment-dependent outcomes.

---

## 2) What changes are welcome in v1

Allowed without major bump (v1-compatible):
- Bugfixes that restore intended v1 behavior (fix a false negative/false positive that contradicts v1 rules)
- Clearer error messages (more actionable `[patch_gate] FAIL:` output)
- Refactors that preserve behavior (no semantic changes)
- CI robustness improvements that preserve semantics

Requires a major bump (v2/v3):
- Changing what is allowed/denied (rename/copy policy, modes, path rules, prose allowance, multi-patch, etc.)
- Changing the output contract for agents
- Any change that alters the meaning of `PATCH_SPEC.md` rules

---

## 3) How to validate your change (required)

Before opening a PR:

1) Make scripts executable:
```bash
chmod +x patch_gate.sh
chmod +x tests/run.sh
```

2) Run the frozen regression corpus:
```bash
./tests/run.sh
```

A valid PR MUST:
- keep all PASS samples passing
- keep all FAIL samples failing
- keep FAIL output including `[patch_gate] FAIL:`

CI enforces this.

---

## 4) PR expectations

- Keep diffs small and focused.
- Explain intent in the PR description:
  - what bug/issue is fixed
  - why it is v1-compatible (or why it requires v2/v3)
- Do not mix unrelated changes.
- Do not introduce formatting churn.

---

## 5) Reporting issues

When reporting a failure:
- include the patch you tried to validate (or a minimal reproducer)
- include the output of:
  - `./patch_gate.sh <patch>`
- include your platform:
  - OS / shell / git version (if relevant)

---

## 6) Security stance

PatchGate is deny-by-default. When in doubt:
- reject rather than allow
- prefer explicit version bumps over silent loosening
