# 陷阱库（pitfalls）

> explore 执行查找时踩过的坑、禁止操作、常见误判。
> 每条一句话摘要 + 详述 + 正确做法。新增时追加到末尾。

---

## P1 · _lua_script_map.json / _directory_tree.json 禁 Read

**摘要**：DevIntelligence 的 `_lua_script_map.json`（~2MB）和 `_directory_tree.json`（~1.4MB）禁止 `Read`，只能 `rg` grep。

**详述**：

直接 `Read` 会把整个 JSON 灌进上下文，瞬间挤爆 3k+ tokens 上限，且大部分内容无关。

**正确做法**：
```bash
# 反向查找脚本→蓝图时 grep 这个文件
rg '<模块名或脚本路径>' <CODELINK>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/_lua_script_map.json
```

**相关**：根 `CLAUDE.md` 的「大体量内容读取的上下文隔离」规则。

---

## P2 · CODELINK 是 symlink，内置 Glob/Grep 不穿透

**摘要**：a helpful coding assistant 内置的 Glob / Grep 工具不穿透 symlink，搜 CODELINK 必须用 Bash 的 `rg --follow`。

**详述**：

CODELINK 是 symlink 工作区，指向真实 P4 目录。内置 Glob/Grep 工具只列直接子项，不跟随 symlink，导致搜索结果为空或缺失。

**正确做法**：
```bash
# ✅ 用 rg --follow
rg --follow '<pattern>' <CODELINK>/Projects/HiGame/

# ❌ 不要用内置 Glob/Grep 搜 CODELINK
```

**例外**：搜非 symlink 的目录（如 `context/`、`UE_PROJECT/` 真实目录）可以用内置工具，但项目约定 `context/` 必须用 `rg`（见 P4）。

---

## P3 · context/ 目录必须用 rg（Bash）

**摘要**：搜 `context/` 知识库必须用 Bash 的 `rg`，禁止用内置 Glob/Grep。

**详述**：

Agent 的 cwd 不为 workspace 目录时，内置 Glob/Grep 存在查找失败的情况。`context/` 是知识库根目录，搜索失败会导致漏掉关键团队约定。

**正确做法**：
```bash
# ✅ 文件名搜索
rg --files -g '*INDEX*' context/

# ✅ 内容搜索
rg 'keyword' context/

# ❌ 不要用内置 Glob/Grep
```

---

## P4 · 蓝图 JSON ≥ 50KB 用 Grep 不用 Read

**摘要**：蓝图 `.uasset` JSON 文件普遍较大（≥50KB），直接 `Read` 会挤爆上下文，用 `rg` grep 精确字段。

**详述**：

蓝图 JSON 含大量冗余字段（Pin、Subgraph、节点连线），整体 Read 几乎没用。需要判断某字段时直接 grep。

**正确做法**：
```bash
rg '"<FieldName>"' <UE_PROJECT>/Content/<path>/<BP>.uasset
```

> 详见 `context/team/devintelligence-query-strategy.md` 的「文件大小阈值」。

---

## P5 · 行号直觉陷阱（Bug 调查相关）

**摘要**：DS 日志 / Core Dump 的 traceback 行号对应**崩溃现场版本**，不是本地最新版本。直接看本地最新代码的第 N 行会定位到完全不相关的行。

**详述**：

代码改动后行号会偏移。DS 报错的第 100 行可能是旧版本的 `LocalPlayer:Spawn()`，本地最新版的第 100 行可能是完全无关的注释。

**正确做法**：
1. 从 TAPD 单 / 崩溃日志提取 `ds_version` / `ds_stream` / `changelist`
2. `p4 print -q "//HiGameDepot/<stream>/<path>@<changelist>"` 获取崩溃版本
3. 在该版本上确认行号语义
4. 修复时再 sync 到最新版应用 diff

> 详见 `context/team/bug-analysis-methodology.md` 的「版本对齐流程」。

**explore 的边界**：用户问"这行代码在哪"时，若来源是 DS 日志 / Core Dump，**先提醒版本对齐**，再查找。explore 不做完整 Bug 调查（那是 `higame-bug-investigator` 的事）。

---

## P6 · 蓝图类名后缀 _C

**摘要**：蓝图生成类名带 `_C` 后缀（`BP_MyActor` → `BP_MyActor_C`），搜代码引用时带 `_C`，搜资产文件名时不带。

**详述**：

- 搜蓝图资产文件：`es.exe "<BP_MyActor>.uasset"`（不带 `_C`）
- 搜代码引用：`rg 'BP_MyActor_C'`（带 `_C`）
- DevIntelligence `---@meta` 注解：用带 `_C` 的类名

混用会漏命中。

---

## P7 · GetServerModuleName / GetClientModuleName 与 GetModuleName 互斥

**摘要**：蓝图不能同时实现 `GetModuleName()` 和 `GetServerModuleName()` / `GetClientModuleName()`，这是互斥的两种绑定模式。

**详述**：

- **Default Module 模式**：只实现 `GetModuleName()`
- **CS 分离模式**：实现 `GetServerModuleName()` 和/或 `GetClientModuleName()`

判断蓝图是哪种模式：读 DevIntelligence `.lua` 文件的 `--- Lua binding (server):` 和 `--- Lua binding (client):` 注释行：
- 两行都有 → CS 分离模式
- 只有 `(server):` 一行（值形如 `CommonScript.xxx`）→ Default Module 模式（运行时重定向）

---

## P8 · 模块名前缀规则

**摘要**：`GetServerModuleName` 返回值必须以 `ServerScript.` 或 `CommonScript.` 开头；`GetClientModuleName` 必须以 `ClientScript.` 或 `CommonScript.` 开头。违反会被 `LuaModuleLocator::GetModuleNameCheck` 拦截。

**详述**：

查找绑定脚本时，若模块名前缀不符合规则，运行时不会报错而是 fallback 到空绑定。看到不符合前缀规则的模块名要警觉：
- 可能是历史遗留错误绑定
- 可能是从父类继承来的，需要回溯

**相关**：`knowledge.md` K2 / K3。

---

## P9 · MSYS2 find / cmd.exe dir /s 禁用

**摘要**：禁止用 MSYS2 `find`、`cmd.exe dir /s` 搜索 CODELINK。

**详述**：

CODELINK 文件量大（~27 万），`find` / `dir /s` 速度极慢且不跟随 symlink。

**正确做法**：用 `rg --follow`（Bash）。

---

## P10 · 不报"未检查全代码库就下结论"

**摘要**：每次 explore 结束必须显式声明覆盖范围（搜了哪些目录、用了什么 pattern、命中几条），禁止暗示全覆盖。

**详述**：

根 `CLAUDE.md` 的「产出诚实性规则」要求：
- **覆盖范围显式声明**：每次分析/审查结束时，列出"本次检查了哪些文件/函数"和"未检查哪些"
- 禁止输出"代码质量良好"等总结性好评

explore 的 Phase 4 阻力报告里的「覆盖范围」小节就是为此存在——即便一次命中、零卡点，也要写"已搜 X / 未搜 Y"。

---

## P11 · 路径混淆：CODELINK vs 真实路径

**摘要**：CODELINK 是 symlink，读 / 改文件必须走真实路径（UE_PROJECT / GS_ROOT），不能在 CODELINK 下 P4 操作。

**详述**：

- **搜索** → CODELINK（快）
- **Read 文件** → 可以走 CODELINK 路径（Read 不区分 symlink），但**推荐**走真实路径
- **Edit / Write** → 必须走真实路径
- **P4 操作**（p4 edit / p4 add）→ 必须走真实路径，P4 不认 symlink

**正确做法**：搜索拿到 CODELINK 路径 → 替换为真实路径 → 再 Read / Edit / P4。

**相关**：`knowledge.md` K4。

---

## P12 · Windows / PowerShell 下 rg pattern 以 `--` 开头被误判为 flag

**摘要**：在 Windows PowerShell 或 Git Bash 下，`rg` 搜索 pattern 以 `--` 开头（如 `---@meta BP_Cow_C`）会被 shell / rg 误判为命令行 flag，导致报错 `unrecognized flag`。

**详述**：

错误示例：
```bash
# ❌ 报错：rg: unrecognized flag ---@meta BP_Pika
rg '---@meta BP_Pika' -g '*.lua' <path>
```

**正确做法**（任选其一）：
```bash
# ✅ 方法 1：去前缀，只搜后面的部分（EmmyLua 注解仍能精确命中）
rg '@meta BP_Pika' -g '*.lua' <path>

# ✅ 方法 2：用 -- 分隔符隔开 rg 选项和 pattern
rg -- '---@meta BP_Pika' -g '*.lua' <path>

# ✅ 方法 3：用 -e 显式声明 pattern
rg -e '---@meta BP_Pika' -g '*.lua' <path>
```

方法 1 最简单；方法 2/3 更通用，适合 pattern 本身以 `-` 开头的场景。

**高频场景**：搜 DevIntelligence `.lua` 文件的 `---@meta` / `---@field` / `---@class` 注解。

---

## P13 · `.codebuddy/skills/` 不被 a helpful coding assistant 直接扫描，必须建 `.claude/commands/<name>.md` 桥接

**摘要**：项目 skill 定义放在 `.codebuddy/skills/<name>/SKILL.md`，但 a helpful coding assistant 的 skill loader **不扫描这个目录**。`/reload-skills` 扫的是 `.claude/commands/*.md`。必须在 commands 下建同名桥接文件，skill 才会出现在 reminder 列表里。

**详述**：

项目约定：
- 真正的 skill 定义 → `.codebuddy/skills/<name>/SKILL.md`（含 frontmatter + 完整流程）
- a helpful coding assistant 可见的"skill"入口 → `.claude/commands/<name>.md`（极简桥接文件）

桥接文件模板（参考 `.claude/commands/bp-lua-script-locator.md` / `read-module-design.md`）：
```markdown
# <name>

$ARGUMENTS

读取并执行 `.codebuddy/skills/<name>/SKILL.md` 中定义的完整流程。

<一句话 skill 用途说明>
```

**症状**：
- 新建 `.codebuddy/skills/<name>/SKILL.md` 后跑 `/reload-skills`，显示 `N skills available (no changes)`
- skill 不出现在 system-reminder 的 available skills 列表里

**正确做法**：
1. 确认 `.codebuddy/skills/<name>/SKILL.md` 已建
2. 在 `.claude/commands/<name>.md` 建桥接文件（用上面模板）
3. 跑 `/reload-skills` → skill 数 +1
4. 更新 `.codebuddy/skills/INDEX.md` 和 `.claude/commands/INDEX.md`

**误判陷阱**：之前以为是 SKILL.md frontmatter 的半角双引号 / `**` 粗体导致 YAML 解析失败，改了 frontmatter 没用——根因不在 frontmatter，在缺桥接文件。

**相关**：`knowledge.md` K9（a helpful coding assistant skill 加载机制）。
