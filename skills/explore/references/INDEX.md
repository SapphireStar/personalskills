# explore references 索引

> 每条 reference 文件的一句话摘要 + 关键词。决定是否加载全文。
> 新增/修改条目时同步更新本索引。

---

## tactics.md — 查找战术库

按查找目标类型组织的战术条目，每条含首选路径 / 兜底 / 陷阱 / 知识点。

| ID | 目标类型 | 一句话摘要 |
|----|---------|-----------|
| T1 | 蓝图 → Lua 脚本 | DevIntelligence 查 binding 注释 → 优先读 `--- Server script:` 直接给路径 → 否则模块名转双搜索根 |
| T2 | Lua 脚本 → 蓝图（反向） | grep DevIntelligence 命中 binding 注释行 / `_lua_script_map.json` |
| T3 | 函数 / 方法定义 | Lua 用 `function.*[:.]FuncName`，C++ 用返回类型 + 函数名 |
| T4 | 字段 / 属性 / 变量 | DevIntelligence `---@field` / Lua 赋值 / C++ UPROPERTY |
| T5 | C++ 类 / 结构体 / 枚举 | `^(class\|struct\|enum)\s+Type` 或 UCLASS/USTRUCT/UENUM |
| T6 | UE 资产（.uasset） | Everything (`es.exe`) 优先，无则 rg UE_PROJECT |
| T7 | 配置文件 / DataTable | rg `*.json` / DataTable schema / Lua 导表入口 |
| T8 | 日志输出点反向定位 | UE_LOG / Lua print / 自定义日志宏，按 Tag 反查 |
| T9 | 调用方 / 引用方 | `:FuncName(` / `FuncName(` / LSP findReferences |
| T10 | 继承关系 | DevIntelligence `--- Inherits:` 行 / C++ `: public Parent` |
| T11 | 常量 / 字符串字面量 | rg 字符串字面量 / TEXT() 宏 / Localization 目录 |
| — | 通用兜底 | CODELINK → DevIntelligence → UE_PROJECT → 知识库，逐级放宽 |

---

## knowledge.md — 项目知识点

explore 执行查找时反复用到的项目级约定 / 常量 / 路径规则。

| ID | 标题 | 一句话摘要 |
|----|------|-----------|
| K1 | DevIntelligence 目录结构 | UE 反射类型导出为 EmmyLua `.lua`，按 C++ 模块 / 蓝图资产路径镜像组织 |
| K2 | UnLua 双搜索根 | `Content/Script/`（主）→ `Content/`（CP 模块兜底）按优先级查找 |
| K3 | CS 分离三层目录 | ServerScript / ClientScript / CommonScript 三层 + 绑定前缀规则 |
| K4 | CODELINK 前缀映射 | symlink 工作区，搜索用 CODELINK，读写 / P4 用真实路径 |
| K5 | false-omission 约定 | UE 蓝图 JSON 缺失的布尔字段等同于 false |
| K6 | GameServer 服务架构基线 | TSF4G v2，47 微服务，核心三服务 Lobby ↔ GWM ↔ WorldProxy |
| K7 | Everything 环境检测 | session 开始执行一次 `es.exe -get-everything-version` |
| K8 | 大体量内容读取的上下文隔离 | 单次 >3k tokens 必须委托 subagent，主对话只接收摘要 |
| K9 | a helpful coding assistant skill 加载机制 | 扫 `.claude/commands/*.md`，不扫 `.codebuddy/skills/`，需桥接文件 |
| K10 | LocalAdapter 模式 WorldProxy 本地分发 | `LocalWorldProxySubsystem:SendMutableActorRequest` 按 RequestType 本地分发，不跨进程 RPC |
| K11 | MutableActor spawn 终点 + GS LOAD handler | DS 终点 `SpawnEditorActor`→`GameAPI.SpawnActor`；GS handler `MutableActorManager.lua:1265`；GS 不 spawn UE Actor |

---

## pitfalls.md — 陷阱库

explore 执行查找时踩过的坑、禁止操作、常见误判。

| ID | 标题 | 一句话摘要 |
|----|------|-----------|
| P1 | _lua_script_map.json 禁 Read | ~2MB JSON 只能 grep 不能 Read |
| P2 | CODELINK 是 symlink | 内置 Glob/Grep 不穿透，必须 `rg --follow` |
| P3 | context/ 目录必须用 rg | Agent cwd 不为 workspace 时内置工具会失败 |
| P4 | 蓝图 JSON ≥ 50KB 用 Grep | 直接 Read 挤爆上下文，grep 精确字段 |
| P5 | 行号直觉陷阱 | DS/Core Dump 行号对应崩溃版本不是本地最新，需 p4 print 对齐 |
| P6 | 蓝图类名后缀 _C | 搜资产不带 `_C`，搜代码引用带 `_C` |
| P7 | GetServer/Client vs GetModuleName 互斥 | 两种绑定模式不能同时实现 |
| P8 | 模块名前缀规则 | Server→ServerScript./CommonScript.，Client→ClientScript./CommonScript. |
| P9 | MSYS2 find / cmd.exe dir /s 禁用 | CODELINK 文件量大，必须用 rg |
| P10 | 必须声明覆盖范围 | 禁止暗示全覆盖，Phase 4 阻力报告必填 |
| P11 | CODELINK vs 真实路径混淆 | Edit/Write/P4 必须走真实路径，搜索走 CODELINK |
| P12 | Windows rg pattern 以 `--` 开头被误判 | PowerShell 下 `rg '---@meta X'` 报错，去前缀或用 `--` / `-e` 分隔 |
| P13 | `.codebuddy/skills/` 不被 a helpful coding assistant 扫描 | 必须建 `.claude/commands/<name>.md` 桥接文件，`/reload-skills` 才会 +1 |

---

## 维护要求

- 每条 reference 必须有 ID（T/K/P + 序号）+ 一句话摘要
- 新增条目时同步更新本索引
- 摘要要含关键词，便于 skim 决定是否加载全文
- 战术条目用统一模板（目标类型 / 首选路径 / 兜底 / 陷阱 / 知识点）
- 不要堆叠成大段落，每条独立可寻址
