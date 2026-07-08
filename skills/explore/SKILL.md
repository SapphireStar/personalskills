---
name: explore
description: "项目代码库查找定位专家 — 给定『我要找 X』的意图（函数/字段/蓝图/资源/配置/日志输出点/绑定关系/调用方等），输出坐标 + 证据链 + 一句话定位结论。简单查找不产出长文档；复杂场景（跨进程调用链追踪/多文件关联分析/调用方穷举分类）产出 md 到 explore-results/，对话只给摘要+路径。不做根因分析、不修复。触发词：找一下、查找、找、定位、搜、搜一下、哪个文件、在哪儿、在哪定义、谁调用了、谁引用了、GetModuleName 怎么实现的、这个日志是谁打的、explore、find、locate、search。当用户说『帮我找一下 XXX』『XXX 在哪个文件』『谁调用了 XXX』『XXX 在哪定义』『这个日志输出点在哪』时，即便没说斜杠命令也要使用本 skill。自我进化：用户随时可向 references/tactics.md / knowledge.md / pitfalls.md 追加知识点/约束/陷阱，本 skill 每次先读对应 reference 再决定查找路径。边界：理解模块设计用 read-module-design / code-read；穷举 Bug 根因并修复用 higame-bug-investigator；本 skill 只负责『找到』，不负责『理解』或『修复』。"
---

# explore — 项目代码库查找定位专家

把模糊的"我要找 X"意图，变成精确的 `文件:行号` + 证据链 + 一句话定位结论。

> **核心定位**：只负责"找到"，不负责"理解"或"修复"。
> **输出对象**：坐标 + 证据链。简单查找对话直出；复杂场景（跨进程调用链/多文件关联/调用方穷举）额外产出 md 到 `explore-results/`，对话只给摘要 + 路径。详见 Phase 5。

---

## 什么时候用 explore，什么时候用别的

| 想做的事 | 用什么 | 不该用 explore |
|---|---|---|
| 找一个东西在哪（函数/字段/蓝图/资源/配置/日志点/绑定/调用方） | **explore** | — |
| 理解一个模块怎么设计的、为什么这样设计 | `read-module-design` 或 `code-read` | ✗ explore 不输出设计解读 |
| 穷举 Bug 根因 + 修复 | `higame-bug-investigator` | ✗ explore 不做根因分析 |
| 蓝图 → 它绑的 Lua 脚本（专门场景，深度继承链回溯） | `bp-lua-script-locator`（explore 会调用它） | explore 内部可委派 |
| 查 DS Lua 错误堆栈 | `ds-trace-debug` | ✗ |
| C++ Crash 分析 | `higame-cpp-expert` / `ue-gdb-core-debug` | ✗ |

**判断原则**：用户问的是"在哪/谁/哪个文件" → explore。用户问的是"为什么/怎么设计的/什么原因" → 不是 explore。

---

## 路径与工具基线（每次 explore 开始前必须遵守）

> 详见根 `CLAUDE.md` 的「路径约定与文件搜索」章节。这里只放最高频的几条。

| 场景 | 工具 | 关键约束 |
|------|------|---------|
| 模糊搜代码（文件名或内容） | `rg --follow` 在 CODELINK 顶层（Bash） | CODELINK 是 symlink，内置 Glob/Grep **不穿透 symlink**，必须用 `rg --follow` |
| 搜索 UE 资产（.uasset） | `es.exe` 优先（Everything），无则 `rg` 搜 UE_PROJECT | 资产不在 CODELINK |
| 搜索 context/ 知识库 | `rg`（Bash） | **禁用内置 Glob/Grep**，cwd 不为 workspace 时会失败 |
| 读真实文件 | `Read` 真实路径（UE_PROJECT / GS_ROOT） | CODELINK 是 symlink，改文件必须走真实路径 |
| 已知相对路径 | 直拼真实路径，零搜索 | 快于任何搜索 |

**搜索结果路径替换**：CODELINK 前缀的结果 → 替换为 UE_PROJECT / GS_ROOT 真实路径后再 Read / Edit / P4 操作。结果路径中的 `Projects/HiGame/`、`Engine/`、`GameServer/` 自动标识文件归属。

> 更多陷阱见 `references/pitfalls.md`。

---

## 工作流（4 阶段，必须按顺序）

### Phase 1 · 意图解析（不读代码）

把用户的"找 X"归到**一类查找目标**。这一步决定了 Phase 2 选哪条战术。

| 查找目标类型 | 典型问法 | 输出形态 |
|---|---|---|
| 函数 / 方法定义 | "XXX 函数在哪定义""谁实现了 XXX" | `文件:行号` |
| 字段 / 属性 / 变量 | "XXX 字段在哪声明""这个变量谁赋值" | `文件:行号` |
| 蓝图 → Lua 脚本 | "BP_XXX 绑的 lua 在哪""GetModuleName 返回什么" | `.lua` 路径 |
| Lua 脚本 → 蓝图 | "这个 lua 脚本绑在哪个蓝图上" | 蓝图资产路径 |
| C++ 类 / 结构体 / 枚举 | "XXX 类在哪""FXXX 在哪定义" | `.h` + `.cpp` 路径 |
| UE 资产 | "XXX 蓝图在哪""XXX 贴图/材质在哪" | `.uasset` 路径 |
| 配置文件 / DataTable | "XXX 配置在哪""XXX 表在哪" | 文件路径 |
| 日志输出点 | "这个日志是谁打的""[LogXXX] 这行日志在哪输出" | `文件:行号` |
| 调用方 / 引用方 | "谁调用了 XXX""谁引用了 XXX" | 多个 `文件:行号` |
| 继承关系 | "XXX 的父类是谁""谁继承了 XXX" | 继承链 |
| 常量 / 字符串字面量 | "XXX 字符串在哪写死""XXX 常量在哪" | `文件:行号` |

**输出**：在脑子里（或简短一句话）明确"这是哪类查找"。**不要**急着搜。

### Phase 2 · 战术选择

查 `references/tactics.md` 里对应类型的条目。每条战术包含：

- **目标类型**（函数 / 字段 / 蓝图 / 资产 / ...）
- **首选路径**（最可能一次命中的搜索方式）
- **兜底路径**（首选失败时的备选）
- **已知陷阱**（指向 `pitfalls.md` 对应条目）
- **相关知识点**（指向 `knowledge.md`）

> **若 `tactics.md` 没有对应条目**：用通用搜索（`rg --follow` + DevIntelligence + `es.exe`），并在 Phase 4 的阻力报告里把"缺失战术"标为候选知识点——这是 explore 自我进化的入口。

### Phase 3 · 执行查找

按 Phase 2 选定的战术执行。**必须遵守的产出诚实性底线**：

- **无坐标不输出**：任何"找到了"的结论必须附带 `文件:行号`。找不到就明说"未找到"，不要编。
- **覆盖范围显式声明**：搜了哪些目录、用了什么 pattern、命中几条，都要讲清楚。禁止暗示全覆盖。
- **多条命中按相关性排序**，不要平铺。
- **路径替换**：CODELINK 前缀的结果 → 真实路径后再交给用户。
- **大体量结果隔离**：单次搜索预期 >3k tokens 时，委托 subagent 执行；主对话只接收精炼摘要。详见根 `CLAUDE.md` 的「产出诚实性规则」和「大体量内容读取的上下文隔离」。

**委派边界**：
- 蓝图→Lua 脚本若涉及复杂继承链回溯 → 委派 `bp-lua-script-locator` skill，不要在 explore 里重写一遍。
- 知识库检索 → 委派 subagent。

### Phase 4 · 阻力报告（每次 explore 结束必须输出）

固定格式。**不自动写文件**——只输出候选，由人决定是否 Edit 进 `references/`。

```markdown
## 本次 explore 阻力报告

### 卡点
- [卡点描述] → [如何绕过 / 没绕过]

### 候选知识点（人工决定是否写入 references/）
- 候选 1: <一句话知识点>
  - 建议写入: `references/tactics.md` / `knowledge.md` / `pitfalls.md`
  - 理由: <为什么这条值得沉淀>
- （无候选时写"无"）

### 浪费的时间（可选）
- [做了什么没用的事] → [原因，是缺战术 / 缺知识点 / 还是工具选错]

### 覆盖范围
- 已搜: <目录 / pattern / 工具>
- 未搜: <目录 / 原因>
```

**自省触发时机**：每次 explore 完成、给出坐标之后。即便一次就找到了、零卡点，也要输出（写"无卡点 / 无候选"）——这本身是"这次没踩坑"的信号。

> 用户看到候选知识点后，说"把候选 1 写进去"，explore 才 `Edit references/xxx.md` 追加。**禁止**主动写。

### Phase 5 · 复杂场景产出 md（仅复杂场景，简单查找不产出）

**触发条件**（满足任一即视为复杂场景，需产出 md）：

| 场景特征 | 示例 |
|---------|------|
| 跨进程 / 跨语言调用链追踪 | "追踪 X 方法最后怎么把 Actor spawn 出来"、"X 的 RPC 从 DS 到 GS 再回来的完整链路" |
| 多文件 / 多模块关联分析 | "X 的所有调用方 + 每个调用方的上下文"、"X 涉及的所有相关文件清单" |
| 调用方穷举 + 分类 | "谁调用了 X，按业务模块归类" |
| 单次查找产出预期超过单页（>3k tokens） | 横跨多个载体（C++/蓝图/Lua）的模块定位 |

**简单查找不产出 md**（只输出坐标 + 证据链 + 阻力报告）：

- 函数在哪定义 / 字段在哪声明 / 蓝图绑哪个 Lua / 谁调用了 X（少量命中）/ 常量字面量在哪
- 判据：能在一两句话里给完坐标 + 一句话定位的，不写 md

**产出位置**：

```
<workspace_root>/explore-results/<kebab-case-主题>.md
```

- workspace_root = 当前工作空间根（含 `.user_profile.json` 软链的目录，通常是 `workspaces/<用户>_<日期>_<ft>`）
- 文件名用 kebab-case，主题词来自查找目标（如 `batch-load-mutable-actor-call-chain.md`）
- 目录不存在时 `mkdir -p` 创建

**md 结构**（复杂场景产出时遵循）：

```markdown
# <查找目标> 调用链追踪 / 定位结果

> **explore 产出** · <一句话说明查找意图>
> **目标函数/对象**：<file:line>
> **产出时间**：<YYYY-MM-DD>
> **代码版本**：基于 CODELINK（注明 UE/GS 侧链接状态）

## 一句话定位
<核心结论，2-3 句>

## 一、入口本体 / 核心坐标
<贴关键代码 + 行号表>

## 二~N、链路各段 / 调用方分类 / ...
<按查找目标组织, 每段含 file:line>

## 完整调用链总览图（如适用）
<ASCII 流程图, 从入口到终点>

## 覆盖范围声明
- 已搜: <目录 / pattern / 工具>
- 未搜: <目录 / 原因>

## 关键知识点（如已沉淀到 references）
<本次沉淀的 K/T/P 条目摘要>

## 阻力报告
<同 Phase 4 格式>
```

**对话输出形态**（产出 md 后）：

- **对话里只给**：一句话定位 + 核心坐标（≤5 个 file:line）+ md 文件路径 + Phase 4 阻力报告
- **不重复**：md 里的详细内容不在对话里再贴一遍。用户看 md 即可。
- 用户若追问 md 里某段细节，再展开那段。

**判断口诀**：如果删掉 md 文件，对话里的摘要仍能回答用户问题的一半以上 → 简单场景，不该产出 md。如果删掉 md 文件，对话摘要不足以回答 → 复杂场景，该产出 md。

---

## 自我进化机制

explore 的能力随使用积累而增长，载体是 `references/` 下的三个 md 文件：

| 文件 | 内容 | 何时追加 |
|------|------|---------|
| `references/tactics.md` | 查找战术（"X 类型目标怎么找"） | 发现一类新的查找目标、或现有战术有更好路径时 |
| `references/knowledge.md` | 项目知识点（路径约定 / 常量 / 约定俗成） | 发现某条项目约定反复用到、或踩坑后总结出规则时 |
| `references/pitfalls.md` | 陷阱库（"别用 X 干 Y"） | 踩坑后总结出禁止操作时 |

**追加流程**：
1. 用户在 explore 输出里看到候选知识点
2. 用户判断"这条值得沉淀" → 说"把候选 N 写进去" 或自己直接 `Edit`
3. explore 用 `Edit` 工具追加到对应文件末尾（保持一句话摘要 + 详述两段式结构）
4. 同步更新 `references/INDEX.md` 的一行摘要

**Style 要求**：
- 每条知识点用 `## 标题` + 一句话摘要 + 详述结构，便于 skim
- 战术条目用统一模板（目标类型 / 首选路径 / 兜底 / 陷阱 / 知识点）
- 不要堆叠成大段落，每条独立可寻址

---

## 与项目其他能力的关系

| 想做的事 | 用什么 |
|---|---|
| 找一个东西在哪 | **本 skill** |
| 蓝图找它绑的 Lua 脚本（深度继承链） | `bp-lua-script-locator`（本 skill 会委派） |
| 理解一个模块怎么设计的 | `read-module-design` |
| 剖析模块代码结构 + 调用逻辑 + 数据 + 依赖 | `code-read` |
| 穷举 Bug 根因 + 修复 | `higame-bug-investigator` |
| 查 DS Lua 错误堆栈 | `ds-trace-debug` |
| 蓝图资产 CRUD | `ue-blueprint-ops` |
| 写架构设计方案（前向设计） | `dev-architect-design` |

本 skill 是**只读查找**，不改代码、不改资产、不做架构提案、不产出长设计文档。

---

## references 加载策略

SKILL.md 主体不展开具体战术细节，按需读 references：

| 触发条件 | 读哪个 |
|---------|--------|
| Phase 2 选战术 | `references/tactics.md`（按目标类型跳到对应小节） |
| 踩到路径/工具/约定陷阱 | `references/pitfalls.md` |
| 需要项目常量 / 约定 / 路径规则背景 | `references/knowledge.md` |
| 不确定某 reference 有没有对应条目 | 先读 `references/INDEX.md` 一行摘要，再决定是否读全文 |

`references/INDEX.md` 维护要求：每条 tactics/knowledge/pitfalls 必须有一句话摘要（含关键词），便于 skim 决定是否加载全文。
