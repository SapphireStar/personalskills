# 查找战术库（tactics）

> 每条战术对应一类查找目标。新增战术时按统一模板追加到对应小节末尾。
> 模板：**目标类型** / **首选路径** / **兜底路径** / **已知陷阱** / **相关知识点**。

---

## T1 · 蓝图 → Lua 脚本

**目标类型**：已知蓝图名（如 `BP_Cow`）或蓝图资产路径，找它绑定的 UnLua Lua 脚本文件。

**首选路径**：
1. 在 DevIntelligence 里搜蓝图的 `.lua` 注解文件：
   ```bash
   rg '---@meta <BlueprintName>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/Game/
   ```
   > Windows/PowerShell 注意：pattern 以 `--` 开头会被 shell 误判为 flag，去前缀只搜 `@meta <BlueprintName>` 或加引号包裹。
2. 读文件头部 binding 注释。**优先看** `--- Server script:` / `--- Client script:` / `--- Script:` 行——这是 DevIntelligence 直接给出的完整相对路径（如 `Script/ServerScript/actors/X.lua`），无需再走模块名→路径转换。若没有才回退到 `--- Lua binding (server): <模块名>` 行做点号→分隔符替换。
3. 拿到完整相对路径后，本地完整路径为：
   ```
   <CODELINK>/Projects/HiGame/Content/<相对路径，去掉开头的 Script/>
   ```
   例：`--- Server script: Script/ServerScript/actors/UnAttackableAnimal.lua`
   → `<CODELINK>/Projects/HiGame/Content/Script/ServerScript/actors/UnAttackableAnimal.lua`
4. 双搜索根按优先级试（仅在 DevIntelligence 没给 `--- Script:` 行时回退用）：
   - `Content/Script/<path>.lua`（主游戏脚本，优先）
   - `Content/<path>.lua`（CP 模块兜底，路径形如 `Content/CP*/Script/...`）

**兜底路径**：
- 步骤 1 搜不到 → 试 `rg '<BlueprintName>' -g '*.lua' DevIntelligence/` 宽松匹配
- 步骤 2 没有直接 binding 注释 → 看 `--- Lua binding inherited from: <ParentName>` → 转父类查找
- 无 binding 注释 → 从 `--- Inherits:` 取继承链，逐级向上搜

**已知陷阱**：
- `GetServerModuleName` / `GetClientModuleName` 与 `GetModuleName` 互斥，不能同时实现（见 `pitfalls.md` P3）
- `_lua_script_map.json` ~2MB 禁 Read，只能 grep（见 `pitfalls.md` P1）
- 模块名前缀规则：`GetServerModuleName` 返回值必须以 `ServerScript.` 或 `CommonScript.` 开头；`GetClientModuleName` 必须以 `ClientScript.` 或 `CommonScript.` 开头

**相关知识点**：
- DevIntelligence 目录结构 → `knowledge.md` K1
- UnLua 双搜索根 → `knowledge.md` K2
- CS 分离三层目录 → `knowledge.md` K3

**委派**：复杂继承链回溯 → 直接用 `bp-lua-script-locator` skill，不在这重写。

---

## T2 · Lua 脚本 → 蓝图（反向）

**目标类型**：已知 `.lua` 脚本路径或模块名，找它绑在哪个蓝图上。

**首选路径**：
```bash
rg '<模块名或脚本路径>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/
```
命中 `--- Lua binding (server/client): <模块名>` 注释行的文件，就是绑定该脚本的蓝图注解文件。

**兜底路径**：
- grep `_lua_script_map.json`（只 grep 不 Read）：
  ```bash
  rg '<模块名>' <CODELINK>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/_lua_script_map.json
  ```

**已知陷阱**：
- `_lua_script_map.json` 禁 Read，见 `pitfalls.md` P1
- 子类继承父类 binding 时，反向搜索会命中继承链上的所有子类注解——按 `--- Lua binding inherited from:` 过滤

---

## T3 · 函数 / 方法定义

**目标类型**：找某个函数（Lua 或 C++）在哪定义。

**首选路径**（Lua 函数）：
```bash
rg --follow 'function.*[:.]<FuncName>' -g '*.lua' <CODELINK>/Projects/HiGame/Content/Script/
rg --follow 'function.*[:.]<FuncName>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/Script/
```

**首选路径**（C++ 函数）：
```bash
rg --follow '<ReturnType>.*<FuncName>\\s*\\(' -g '*.h' -g '*.cpp' <CODELINK>/Projects/HiGame/Source/ <CODELINK>/Engine/Source/
```

**兜底路径**：
- DevIntelligence 类型注解文件里搜 `---@return` + 函数名（C++ 反射函数）
  ```bash
  rg 'function.*[:.]<FuncName>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/Script/
  ```
- 不知道是 Lua 还是 C++ → 先 rg 全 CODELINK 顶层：
  ```bash
  rg --follow '<FuncName>' <CODELINK>
  ```

**已知陷阱**：
- CODELINK 是 symlink，内置 Glob/Grep 不穿透，必须 `rg --follow`（见 `pitfalls.md` P2）
- 函数可能有多个同名重载 / 蓝图实现 / Lua 覆写，全部列出按相关性排序

**相关知识点**：
- DevIntelligence `.lua` 注解文件格式 → `knowledge.md` K1

---

## T4 · 字段 / 属性 / 变量声明

**目标类型**：找某个字段在哪声明 / 谁赋值。

**首选路径**（C++ 反射字段）：
```bash
rg '---@field.*<FieldName>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/
```
注解行格式：`---@field <Name> <Type> @<access> [@replicated]`

**首选路径**（Lua 字段）：
```bash
rg --follow '\\.<FieldName>\\s*=' -g '*.lua' <CODELINK>/Projects/HiGame/Content/Script/
```

**首选路径**（C++ UPROPERTY）：
```bash
rg --follow 'UPROPERTY.*<FieldName>' -g '*.h' <CODELINK>/Projects/HiGame/Source/
```

**兜底路径**：
- 不知道在哪层 → `rg --follow '<FieldName>' <CODELINK>` 全局搜
- 配置表字段 → 看 DataTable schema：`rg '<FieldName>' -g '*.json' <CODELINK>/Projects/HiGame/Content/DataTable/`

---

## T5 · C++ 类 / 结构体 / 枚举

**目标类型**：找 C++ 类型定义。

**首选路径**：
```bash
rg --follow '^(class|struct|enum)\\s+<TypeName>\\b' -g '*.h' <CODELINK>/Projects/HiGame/Source/ <CODELINK>/Engine/Source/
```

**兜底路径**：
- DevIntelligence 反射注解：
  ```bash
  rg '---@class <TypeName>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/Script/
  ```
- UCLASS / USTRUCT / UENUM 标签：
  ```bash
  rg --follow 'UCLASS|USTRUCT|UENUM' -A 5 -g '*.h' <CODELINK>/Projects/HiGame/Source/ | rg '<TypeName>'
  ```

---

## T6 · UE 资产（.uasset）

**目标类型**：找蓝图 / 贴图 / 材质 / StaticMesh 等 UE 资产。

**首选路径**（Everything 优先）：
```bash
es.exe -path "<UE_PROJECT>" "<AssetName>.uasset"
```

**兜底路径**（无 Everything）：
```bash
rg --files <UE_PROJECT>/Content/ -g '*<AssetName>*'
```

**已知陷阱**：
- 资产不在 CODELINK，必须搜 UE_PROJECT 真实目录
- 蓝图生成类名带 `_C` 后缀（`BP_MyActor` → `BP_MyActor_C`），搜文件名时不带 `_C`，搜代码引用时带 `_C`
- Everything 环境检测：`es.exe -get-everything-version`（session 开始时执行一次）

---

## T7 · 配置文件 / DataTable

**目标类型**：找游戏配置 / DataTable / JSON 配置。

**首选路径**：
```bash
rg --files <CODELINK>/Projects/HiGame/ -g '*<ConfigName>*' -g '*.json' -g '*.h'
rg --files <UE_PROJECT>/Content/DataTable/ -g '*<ConfigName>*'
```

**兜底路径**：
- 配置加载代码反查：`rg 'DataTable.*<ConfigName>|<ConfigName>.*DataTable' -g '*.lua' -g '*.cpp' <CODELINK>/Projects/HiGame/`
- Lua 导表入口：`rg 'LoadDataTable|DataTableManager' -g '*.lua' <CODELINK>/Projects/HiGame/Content/Script/`

---

## T8 · 日志输出点反向定位

**目标类型**：日志里看到一行 `[LogXXX] ...` 或 `print(xxx)`，找输出它的代码位置。

**首选路径**：
```bash
# UE_LOG
rg --follow 'UE_LOG.*LogXXX' -g '*.cpp' -g '*.h' <CODELINK>/Projects/HiGame/Source/
# Lua print / log
rg --follow "print\\(.*<关键字>" -g '*.lua' <CODELINK>/Projects/HiGame/Content/Script/
# 自定义日志宏
rg --follow 'LOG_<TAG>|LogSystem.*<TAG>' -g '*.lua' -g '*.cpp' <CODELINK>/Projects/HiGame/
```

**兜底路径**：
- 日志 Tag 定义点：`rg 'DEFINE_LOG_CATEGORY.*LogXXX' -g '*.h' -g '*.cpp' <CODELINK>/`
- Lua 日志框架统一入口：`rg 'LogService|LogManager|log\\.print' -g '*.lua' <CODELINK>/Projects/HiGame/Content/Script/`

---

## T9 · 调用方 / 引用方

**目标类型**：找谁调用了某函数 / 谁引用了某字段。

**首选路径**（Lua）：
```bash
rg --follow ':<FuncName>\\(|\\.<FuncName>\\(' -g '*.lua' <CODELINK>/Projects/HiGame/Content/Script/
```

**首选路径**（C++）：
```bash
rg --follow '<FuncName>\\s*\\(' -g '*.cpp' -g '*.h' <CODELINK>/Projects/HiGame/Source/
```

**兜底路径**：
- LSP `findReferences`（若 LSP 可用，定位精度更高）— 见 `context/team/lsp-tool-selection.md`
- 大范围搜索结果 >3k tokens → 委派 subagent，主对话只接收摘要

---

## T10 · 继承关系

**目标类型**：找某类的父类 / 子类 / 完整继承链。

**首选路径**（DevIntelligence，蓝图和 C++ 反射类型都支持）：
```bash
# 读目标类的 Inherits 注释行
rg '---@meta <TypeName>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/
# 读该文件的 --- Inherits: 行获取完整链

# 找所有继承自某类的子类
rg 'Inherits:.*<ParentName>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/
```

**首选路径**（C++）：
```bash
rg --follow ':\\s*(public|protected|private)\\s+<ParentName>\\b' -g '*.h' <CODELINK>/Projects/HiGame/Source/
```

---

## T11 · 常量 / 字符串字面量

**目标类型**：找某个字符串字面量 / 常量在哪写死。

**首选路径**：
```bash
rg --follow '"<字符串内容>"' <CODELINK>/Projects/HiGame/
rg --follow "'<字符串内容>'" <CODELINK>/Projects/HiGame/
```

**兜底路径**：
- UE 字符串字面量常带 TEXT() 宏：`rg 'TEXT\\("\\.*<关键字>.*"\\)' -g '*.cpp' -g '*.h' <CODELINK>/`
- 国际化 / 本地化字符串：`rg '<关键字>' <UE_PROJECT>/Content/Localization/`

---

## 通用兜底（任何类型查不到时）

按以下顺序逐级放宽：

1. `rg --follow '<关键字>' <CODELINK>` — 全 CODELINK 搜索
2. DevIntelligence 反射注解 — `rg '<关键字>' -g '*.lua' <CODELINK>/Projects/HiGame/DevIntelligence/`
3. UE_PROJECT 资产 — `es.exe -path "<UE_PROJECT>" "<关键字>"`
4. 知识库 — 委派 subagent 调 `knowledgebase_search`（data_type 视场景选 git / git_iwiki / document / story）
5. 都查不到 → 输出"未找到"+ 已搜范围 + 阻力报告

> 每一级都要在 Phase 4 覆盖范围里声明"搜了哪、命中几条"。
