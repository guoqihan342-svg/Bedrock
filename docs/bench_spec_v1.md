# bench_spec_v1 (FROZEN CONTRACT)

本文件是 **冻结合同**：只要 `suite_id = bench_spec_v1`，就必须严格遵守这里的定义。  
未来升级只能通过新增 `bench_spec_v2` / `bench_spec_v3`，而不是修改 v1 的任何规则。

目标：
- 输出的性能结果可长期对比、可回归、可复现（在合理噪声内）
- 任何优化必须先通过 correctness gate
- 尽量减少外部依赖与“时代变化”带来的返工

---

## 1. Suite 标识与输出文件

- `suite_id` 固定为：`bench_spec_v1`
- 输出格式：JSON（UTF-8）
- 输出 schema：见本文第 6 节

---

## 2. Kernel 列表（v1）

v1 只包含一个 kernel：

- `dot_f32`：单精度浮点向量点积

未来新增 kernel 必须在 v2 起步（或在 v1 的 results 里新增字段也属于破坏性变化，不允许）。

---

## 3. 输入生成（确定性）

对每个 case（每个 n）生成两条向量 `a[n]`、`b[n]`：

- PRNG：xorshift64*（非加密，仅用于确定性输入）
- 种子（冻结）：
  - `seed_a = 0xBADC0FFEE0DDF00D`
  - `seed_b = 0xC001D00DDEADBEEF`

- 每个 n 使用轻微 seed tweak（冻结）：
  - `seedA_for_n = seed_a ^ (uint64)n`
  - `seedB_for_n = seed_b ^ (uint64)(n * 1315423911)`

- u64 -> f32 映射（冻结）：
  - `u24 = (u >> 40) & 0xFFFFFF`
  - `x = u24 / 2^24`
  - `val = x*2 - 1`  （范围：[-1, 1)）

这保证输入值稳定、分布稳定，且不依赖外部数据。

---

## 4. Case 表（sizes & reps）

v1 固定 case 表：

| n     | reps    |
|-------|---------|
| 256   | 200000  |
| 1024  | 60000   |
| 4096  | 15000   |
| 16384 | 4000    |
| 65536 | 1000    |

解释：
- reps 选择使得不同 n 的 wall-time 处于同一量级，便于统计稳定
- 不允许在 v1 中更改

---

## 5. 计时与统计（冻结）

### 5.1 Warmup / Measure 次数
- `warmup_iters = 5`
- `measure_iters = 9`

### 5.2 每次 measure 的过程
对某个 case（n, reps）：
- 先运行 warmup：`warmup_iters` 轮，每轮执行 `reps` 次 kernel
- 然后测量 `measure_iters` 轮：
  - 每轮：
    - 记录 `t0 = now_ns()`
    - 执行 `reps` 次 kernel
    - 记录 `t1 = now_ns()`
    - `dt = t1 - t0` （ns）
    - 可做 best-effort loop overhead 扣减（实现细节在代码，原则上是非负 clamp）

### 5.3 分位数定义（nearest-rank）
- 对 `measure_iters` 个样本排序
- `p50`、`p95` 使用 nearest-rank with ceil：
  - `rank = ceil(p * n_samples)`（1-indexed）
  - `idx = rank - 1`
- v1 固定 `p=0.50` 与 `p=0.95`

### 5.4 归一化单位（ns/elem）
- `ns_per_element = dt / (reps * n)`

---

## 6. Correctness Gate（冻结）

### 6.1 真相源
- reference 固定为：`dot_f32_scalar`
- 参考实现必须：
  - 顺序累加（i=0..n-1）
  - 禁止隐式 FMA contraction（防止与 SIMD 语义漂移）

### 6.2 判定阈值（冻结）
- `abs_tol = 1e-5`
- `rel_tol = 1e-5`
通过条件：
- `abs_err <= abs_tol` 或 `rel_err <= rel_tol`

### 6.3 失败行为
- 若任一 case `correct=false`：
  - `bedrock_bench` 进程返回非 0（当前实现为 20）
  - CI smoke 必须失败

---

## 7. Variant 语义（冻结）

- `variant = scalar`：稳定可比默认路径（推荐 baseline 也用它）
- `variant = avx2`：显式 opt-in 的加速路径
  - v1 要求：不得牺牲 correctness gate
  - 允许实现通过“保持 scalar 顺序”来保证数值一致（即便牺牲一点潜在吞吐）

---

## 8. 输出 JSON Schema（冻结）

顶层对象字段：

- `suite_id` : string (must be "bench_spec_v1")
- `target_name` : string
- `git_rev` : string ("unknown" allowed)
- `timestamp_utc` : string (ISO-8601 preferred, "unknown" allowed)
- `env` : object
- `results` : array of objects

`env` 字段（best-effort）：
- `uname` : string
- `cpu_model` : string
- `cpu_cores` : int
- `governor` : string
- `pinning_ok` : bool
- `pinned_cpu` : int
- `timer_source` : string
- `alignment_bytes` : int
- `variant_default` : string

`results[]` 每个元素字段：
- `kernel` : string ("dot_f32")
- `variant` : string
- `n` : int
- `reps` : int
- `warmup_iters` : int
- `measure_iters` : int
- `p50_ns_per_element` : number
- `p95_ns_per_element` : number
- `ns_per_element_unit` : string ("ns/elem")
- `correct` : bool
- `error_abs` : number
- `error_rel` : number

---

## 9. 兼容性与演进规则（极重要）

- v1 永不修改：包括 case 表、统计方法、阈值、字段名、字段含义。
- 新需求用 v2：
  - 例如新增 kernel、改变分位数计算、改变输入分布、改变输出字段等
- 旧 baseline 永远可用于旧版本对比，保证长期可回归。
