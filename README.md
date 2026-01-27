# Bedrock

Bedrock is a **Linux-first**, **performance-first** execution layer for AI/system-generated programs.

It is **not** designed for human-written code or readability. The goal is to provide:
- A stable, low-level IR/bytecode (CFG + SSA + strong typing)
- Strict verification (missing performance-critical info is rejected)
- A minimal toolchain that can JIT/AOT to native code (start with Linux + x86-64)
- A benchmark + regression gate so performance never silently degrades

## Non-goals (for now)
- Ecosystem adoption, package manager, human-friendly syntax
- Large external dependencies (LLVM/Cranelift) that force chasing upstream updates
- Multi-OS support in v0 (but the architecture keeps core OS-agnostic; OS support is a thin platform layer)

## Core invariants (hard rules)
1. IR is **CFG + SSA** with **strong typing**.
2. Every `load/store` must carry **align + alias_tag**.
   - If missing: **verifier must reject** (no “default conservative and continue”).
3. Canonical form:
   - Equivalent programs normalize to one representation (stable hash).
4. Verifier errors must be machine-locatable:
   - function / block / instruction / field
5. Performance is a gate:
   - Bench runs must produce machine-readable summaries and **fail on regression**.

## Repo layout (high level)
- `docs/` Specs and benchmarking methodology
- `core/` IR, verifier, canonicalizer, optimizer
- `backend/x86_64/` Codegen backend (isel/regalloc/emit/abi)
- `platform/linux/` Minimal OS layer for executable memory + timing
- `runtime/minimal/` Tiny runtime utilities
- `tools/bedrockc/` CLI tool (build/run/verify/bench)
- `tests/` Unit tests + E2E tests
- `bench/` Micro-kernels and regression baselines
- `scripts/` One-command build/test/bench + AI bundle collector

## Quick start (Linux)
### Prereqs
- gcc or clang
- cmake
- make or ninja

### Build
```bash
./scripts/build.sh
```

### Run tests
```bash
./scripts/test.sh
```

### Run benchmarks (with regression gate)
```bash
./scripts/bench.sh
```
### AI iteration workflow (recommended)
#### To iterate with AI efficiently without sending the whole repo every time:

```bash
./scripts/collect_for_ai.sh
```

#### This generates ai_bundle.zip containing:

- repo tree snapshot
- git diff (if any)
- build/test/bench logs (best effort)
- machine info

#### Upload ai_bundle.zip to the AI, apply returned patches, and rerun.

### License
See LICENSE.
---
