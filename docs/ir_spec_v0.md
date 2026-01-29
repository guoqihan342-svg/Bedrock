# ir_spec_v0 (FROZEN CONTRACT)

本文件定义 Bedrock 的 **最小 IR（中间表示）合同**：  
它不是为了人类可读，而是为了 **AI/工具链稳定、确定、可证明** 地生成与优化。

原则：
- **冻结**：`spec_v0` 一旦发布，不做破坏性变更
- **可验证**：所有 IR 都能被验证器在 O(n) 时间内检查结构合法性
- **可映射到底层**：能无歧义地映射到低层执行模型（寄存器/内存/简单控制流）
- **最少语义**：避免时代变化导致的“语义漂移”

> 说明：v0 先定义格式与最小指令集框架；实现可以逐步补齐（通过新增 opcode 版本或 v1）。  
> 但 “v0 已定义的字段/含义” 永不改变。

---

## 1. Spec ID

- `suite/spec id`: `spec_v0`

---

## 2. 文件格式（v0）

- 文件为 **纯文本**（UTF-8）
- 每行一条记录（record）
- 以 `#` 开头的行为注释（忽略）
- 空行忽略
- 词法分隔：空格或制表符

### 2.1 顶层结构（固定顺序建议，但解析器允许乱序）
- `spec spec_v0`
- `module <module_name>`
- 零或多条：`fn ...` 定义
- `end`

---

## 3. 类型系统（极简）

v0 只提供以下基础类型（固定）：

- `i1`  : 1-bit（逻辑）
- `i8`  : 8-bit 有符号
- `i16` : 16-bit 有符号
- `i32` : 32-bit 有符号
- `i64` : 64-bit 有符号
- `u8/u16/u32/u64` : 无符号
- `f32` : IEEE-754 float32
- `f64` : IEEE-754 float64
- `ptr` : 无类型指针（字长随 target；解析器只把它当“地址”）

> 不提供 struct/array/vector 等复合类型：通过内存布局与 load/store 表达。

---

## 4. 存储模型（固定）

- 虚拟寄存器 SSA 风格：`%0 %1 ...`（无上限）
- 显式内存操作：`alloca/load/store`
- 函数参数：`%a0 %a1 ...`
- 所有指令都有显式类型标注（避免推断歧义）

---

## 5. 控制流（最小）

- 基本块 label：`bb <name>`
- 跳转：
  - `br <bb>`
  - `br_if <cond> <bb_true> <bb_false>`
- 返回：
  - `ret`
  - `retv <value>`

v0 不定义异常、不可达等高级控制语义。

---

## 6. 指令集（v0 最小集）

指令形态（统一）：

- `set <dst> <op> <type> <args...>`

其中：
- `<dst>`: `%N`
- `<op>`: opcode
- `<type>`: 结果类型（例如 i32/f32/ptr）
- `<args>`: 参数（寄存器或立即数）

### 6.1 算术（整数/浮点）
- `add/sub/mul`（整数）
- `and/or/xor`（整数位运算）
- `shl/shr`（逻辑移位）
- `fadd/fsub/fmul/fdiv`（浮点）

### 6.2 比较
- `icmp_eq/ne/lt/le/gt/ge` -> `i1`
- `fcmp_eq/ne/lt/le/gt/ge` -> `i1`

### 6.3 转换（最少）
- `zext/sext/trunc`
- `sitofp/uitofp`
- `fptosi/fptoui`
- `bitcast`（同位宽）

### 6.4 内存
- `alloca <type> <count_i64>` -> `ptr`
- `load <type> <ptr>` -> `<type>`
- `store <type> <ptr> <value>` -> `i1`（返回 i1 仅用于统一；成功恒为 1）
- `gep <ptr> <offset_i64>` -> `ptr`（字节偏移；不做类型寻址）

### 6.5 调用
- `call <ret_type> <fn_name> <args...>` -> `<ret_type>`  
  - v0 不包含变参、ABI 细节；由 target 层定义具体 calling convention

---

## 7. 函数定义格式（v0）
fn <fn_name> (<arg0_type> <arg1_type> ...) -> <ret_type> bb entry set %0 add i32 %a0 %a1 retv %0 endfn

- 参数寄存器命名：`%a0 %a1 ...`
- 返回类型可以是 `void`
  - `-> void` 时只能用 `ret`

---

## 8. 验证规则（必须）

验证器必须检查：
- 第一行 `spec spec_v0`
- 所有 `%N` 使用前已定义（SSA）
- opcode 与类型匹配（例如 `fadd` 只能用于 f32/f64）
- `bb` 必须有唯一名字
- `br/br_if` 目标块必须存在
- `ret/retv` 类型与函数签名一致
- `alloca` 的 count 必须是非负 i64（允许 0）
- `gep` offset 必须是 i64

任何违规都必须拒绝（非 0 exit code）。

---

## 9. 演进规则（永恒核）

- v0 不会改字段、不改已有 opcode 语义
- 新 opcode 只能：
  - 通过 `spec_v1` 引入，或
  - 在 v0 中作为“扩展 opcode”但必须带前缀并保证旧解析器可跳过（**不建议**）

建议路线：
- v0：冻结 IR 外壳 + 最小指令集
- v1：增加向量/内存模型细化/ABI 明确化/更强验证
- v2：增加更高层优化提示（仍保持可验证）
