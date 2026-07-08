# 项目知识点（knowledge）

> explore 执行查找时反复用到的项目级约定 / 常量 / 路径规则。
> 每条一句话摘要 + 详述。新增时追加到末尾，保持独立可寻址。

---

## K1 · DevIntelligence LuaTypeDefinitions 目录结构

**摘要**：UE 反射类型导出为 EmmyLua `.lua` 文件，按 C++ 模块 / 蓝图资产路径镜像组织，可被 `rg -g '*.lua'` 直接搜索。

**详述**：

目录结构：
```
<ProjectDir>/DevIntelligence/LuaTypeDefinitions/
├── _index.json                  # 统计信息（JSON，只 grep）
├── _lua_script_map.json         # Lua 脚本→蓝图映射（~2MB，禁 Read 只 grep）
├── _directory_tree.json         # 文件列表（~1.4MB，禁 Read 只 grep）
├── Script/                      # C++ 反射类型（按 UE 模块分组）
│   └── <Module>/<classes|structs|enums>/<Name>.lua
├── Game/                        # 蓝图类型（镜像 UE 资产路径）
│   └── <AssetPath>/<BlueprintName>.lua
└── UnLua/                       # UnLua 额外绑定（FVector、UObject 等）
```

本地路径：`<codelink_target_dir>/Projects/HiGame/DevIntelligence/LuaTypeDefinitions/`

`.lua` 注解文件格式：
```lua
---@meta BP_Cow_C
--- Blueprint: /Game/Blueprints/Actor/Animal/Cow/BP_Cow
--- Lua binding (server): ServerScript.actors.UnAttackableAnimal
--- Lua binding (client): ClientScript.actors.UnAttackableAnimal
--- Lua binding inherited from: BPA_AnimalBase_C
--- Inherits: BP_Cow_C > BPA_UnAttackableAnimalBase_C > ... > Actor > Object

---@class BP_Cow_C : BPA_UnAttackableAnimalBase_C
---@field Capsule CapsuleComponent @public
local BP_Cow_C = {}

--- [static, BlueprintEvent]
---@param Param1 integer
---@return boolean
function BP_Cow_C:SomeFunction(Param1) end

return BP_Cow_C
```

注解含义：
- `---@meta` — 类型名
- `--- Inherits:` — 完整继承链（`>` 分隔，右侧为基类方向）
- `--- Lua binding (server/client):` — UnLua 脚本绑定路径
- `--- Lua binding inherited from:` — 绑定来源（非自身定义时标注）
- `---@class X : Y` — EmmyLua 类声明 + 直接父类
- `---@field` — 属性（含 access / replicated / RepNotify 标注）
- `--- [tags]` — 函数标签（static / const / ServerRPC / ClientRPC / BlueprintEvent 等）

**每个文件只含该类型自身声明的属性和函数**，不含继承的。

> 详见 `context/team/devintelligence-query-strategy.md`。

---

## K2 · UnLua 双搜索根

**摘要**：UnLua 有两个脚本搜索根目录，按 `Content/Script/`（主）→ `Content/`（CP 模块兜底）优先级查找。

**详述**：

| 优先级 | 搜索根目录 | 用途 |
|--------|-----------|------|
| 1（高） | `Content/Script/` | 主游戏脚本 |
| 2（低） | `Content/` | CP 模块脚本（`Content/CP*/Script/`） |

模块名 → 文件路径：点号替换为目录分隔符，加 `.lua`。

**示例**：
```
主脚本: CommonScript.actors.BP_MyActor_C
  → Content/Script/CommonScript/actors/BP_MyActor_C.lua  ✓

CP 模块: CP0022305_OF.Script.ServerScript.gameplay.BP_CPActor_C
  → Content/Script/CP0022305_OF/Script/...  ✗（不存在）
  → Content/CP0022305_OF/Script/ServerScript/gameplay/BP_CPActor_C.lua  ✓
```

本地路径：`<codelink_target_dir>/Projects/HiGame/Content/Script/` 或 `Content/CP*/Script/`

---

## K3 · CS 分离三层目录

**摘要**：UnLua 脚本按 `ServerScript` / `ClientScript` / `CommonScript` 三层目录组织，对应服务端 / 客户端 / 共享逻辑。

**详述**：

```
Content/Script/
├── ServerScript/      # 服务端专用（DS 运行）
├── ClientScript/      # 客户端专用（客户端运行）
└── CommonScript/      # 共享逻辑（DS 和客户端都运行）
```

**绑定前缀规则**（`LuaModuleLocator::GetModuleNameCheck`）：
- `GetServerModuleName` 返回值必须以 `ServerScript.` 或 `CommonScript.` 开头
- `GetClientModuleName` 返回值必须以 `ClientScript.` 或 `CommonScript.` 开头
- `GetModuleName` 是默认绑定（旧模式），运行时由 `LuaModuleLocator` 按 Server/Client 环境重定向

**两种绑定模式**（互斥）：
- **Default Module**：只实现 `GetModuleName()`
- **CS 分离**：实现 `GetServerModuleName()` 和 / 或 `GetClientModuleName()`

> 详见 `context/team/unlua-binding.md`。

---

## K4 · CODELINK 前缀映射

**摘要**：CODELINK 是 symlink 工作区（~27 万代码文件，无 Intermediate / Binaries / 资产噪音），搜索用 CODELINK，读写 / P4 操作必须替换为真实路径。

**详述**：

```
CODELINK/Projects/HiGame/<相对路径>  ↔  UE_PROJECT/<相对路径>
CODELINK/Engine/<相对路径>           ↔  UE_ENGINE/<相对路径>
CODELINK/GameServer/<相对路径>       ↔  GS_ROOT/<相对路径>
```

- **搜索** → 用 CODELINK（快，只有代码文件）
- **读写 / P4 操作** → 用 UE_PROJECT / UE_ENGINE / GS_ROOT（真实 P4 目录）

**路径替换规则**：搜索结果路径是 CODELINK 前缀 → 替换为真实路径后再 Read / Edit / P4 操作。结果路径中的 `Projects/HiGame/`、`Engine/`、`GameServer/` 自动标识了文件归属。

**当前 session 的真实根路径**（从 `.user_profile.json` 读取）：
- `UE_PROJECT = <ue_workspace_root>\UnrealEngine\Projects\HiGame`
- `UE_ENGINE = <ue_workspace_root>\UnrealEngine\Engine`
- `GS_ROOT = <gameserver_workspace_root>`
- `CODELINK = <codelink_target_dir>`

---

## K5 · false-omission 约定

**摘要**：UE 蓝图 JSON 中缺失的布尔字段等同于 false，不要把"字段不存在"当成"配置错误"。

**详述**：

读取蓝图 `.uasset` JSON 时，未出现的布尔字段（如 `bCanEverTick`、`bReplicates`）应按 false 处理。这是 UE 序列化的标准约定，不是配置遗漏。

搜索蓝图配置时，判断"是否开启 X"的正确方式：
- 字段存在且值为 `true` → 开启
- 字段不存在 / 值为 `false` → 关闭（**不要**报"字段缺失，可能配置错误"）

---

## K6 · GameServer 服务架构基线

**摘要**：GameServer 基于 TSF4G v2，47 个微服务（19 C++/Lua 有状态 + 28 Go 无状态），核心三服务 LobbyService ↔ GameWorldManagerService ↔ WorldProxyManagerService。

**详述**：

源码位置：`CODELINK/GameServer/tsf4g-services/`

核心三服务：
- **LobbyService** — 玩家入口
- **GameWorldManagerService** — 中央调度
- **WorldProxyManagerService** — 世界代理

服务间通信：tbuspp v2（腾讯总线传输协议）

> 完整服务分类、通信链路、共享代码详见 `context/project/HiGame/architecture/gameserver-overview.md`

查 GameServer 代码时的路径约定：CODELINK/GameServer/ 搜索 → 替换为 GS_ROOT/ 真实路径后 P4 操作。

---

## K7 · Everything 环境检测

**摘要**：UE 资产搜索优先用 Everything (`es.exe`)，session 开始时执行一次环境检测。

**详述**：

```bash
es.exe -get-everything-version 2>/dev/null && echo "EVERYTHING_AVAILABLE" || echo "EVERYTHING_NOT_AVAILABLE"
```

- `EVERYTHING_AVAILABLE` → 后续资产搜索用 `es.exe -path "<UE_PROJECT>" "<AssetName>.uasset"`
- `EVERYTHING_NOT_AVAILABLE` → 回退到 `rg --files <UE_PROJECT>/Content/ -g '*<AssetName>*'`（慢）

---

## K8 · 大体量内容读取的上下文隔离

**摘要**：单次可能产生 3k+ tokens 的读取操作必须通过 subagent 隔离，主对话只接收精炼摘要。

**详述**：

适用场景：
- MCP 知识库检索（`knowledgebase_search`）→ 委托 subagent，主对话只接收摘要
- 经验文档批量读取 → 主对话只读 INDEX.md，具体文档委托 subagent
- 全局 `rg` 搜索结果预期 >3k tokens → 委托 subagent，主对话接收 top N 命中

**豁免**：用户明确需要原始数据时可直接调用。

> 详见根 `CLAUDE.md` 的「大体量内容读取的上下文隔离」。

---

## K9 · a helpful coding assistant skill 加载机制

**摘要**：a helpful coding assistant 的 skill loader 扫描 `.claude/commands/*.md`，**不**扫描 `.codebuddy/skills/`。项目约定用"桥接文件"模式让 `.codebuddy/skills/` 下的 skill 定义对 a helpful coding assistant 可见。

**详述**：

项目双轨制：
- **真正的 skill 定义** → `.codebuddy/skills/<name>/SKILL.md`（frontmatter + 完整流程 + references/）
- **a helpful coding assistant 可见的 skill 入口** → `.claude/commands/<name>.md`（极简桥接文件，内容是"读取并执行 .codebuddy/skills/<name>/SKILL.md"）

**桥接文件标准模板**：
```markdown
# <name>

$ARGUMENTS

读取并执行 `.codebuddy/skills/<name>/SKILL.md` 中定义的完整流程。

<一句话 skill 用途说明>
```

**system-reminder 里的"available skills"列表构成**：
1. `.claude/commands/*.md`（含桥接文件 + 独立 command）
2. 插件 skills（`~/.claude/plugins/cache/.../skills/`，如 skill-creator / dataviz）
3. 内置 skills（verify / code-review / simplify / loop 等）

**新建 skill 必做步骤**：
1. 写 `.codebuddy/skills/<name>/SKILL.md`（+ references/）
2. 写 `.claude/commands/<name>.md` 桥接文件
3. 更新 `.codebuddy/skills/INDEX.md` 和 `.claude/commands/INDEX.md`
4. `/reload-skills` → skill 数 +1 表示加载成功

**诊断口诀**：
- `/reload-skills` 显示 `N skills (no changes)` + 新 skill 没出现 → 缺桥接文件
- skill 出现在 reminder 里但执行报错 → 桥接文件路径写错，或 `.codebuddy/skills/<name>/SKILL.md` 不存在

**相关**：`pitfalls.md` P13。

---

## K10 · LocalAdapter 模式下 WorldProxy 不走 RPC，`LocalWorldProxySubsystem:SendMutableActorRequest` 直接按 RequestType 分发

**摘要**：DS 端 `MutableActorComponent` 发出的所有 MutableActorRequest（LOAD/UNLOAD/CREATE/DESTORY/RESET/MESSAGE/UNLOCK），在 LocalAdapter 模式下不跨进程，由 `LocalWorldProxySubsystem:SendMutableActorRequest` 在本进程内按 `InnerRequest.Type` 分发到 `LoadMutableActor` / `UnloadMutableActor` / `CreateMutableActor` / `DestroyMutableActor` / `ResetMutableActor` / `SendMutableActorMessage` / `UnlockMutableActor`。

**详述**：

调用链分叉点在 `MutableActorComponent:ProcessRemoteForwarding`（`mutable_actor_component.lua:1894`）。它调 `GetMutableActorRequestSendProxy`（`:1851`）拿 SendProxy：

- **LocalAdapter 模式**（`UE.UHiRuntimeEnvFunctionLibrary.IsLocalAdapter()` 为 true）→ `GetWorldProxySender`（`:325`）返回缓存的 `LocalWorldProxyMessageSendProxy` → `SendMutableActorRequest`（`local_world_proxy_subsystem.lua:39`）转发到 `LocalWorldProxySubsystem:SendMutableActorRequest`（`:469`）。该方法遍历 `Request.Requests`，按 `InnerRequest.Type` 分发（`:474-488`）：
  ```lua
  if InnerRequest.Type == MutableActorRequestType.LOAD then
      self:LoadMutableActor(InnerRequest.Target, InnerRequest.LoadMutableActorParam)  -- :599
  elseif InnerRequest.Type == MutableActorRequestType.UNLOAD then ...
  ```
  分发完直接 `Callback(ClientContext, Response)` 本地回 ACK（`:496-503`），不发起 RPC。
- **远程模式**（非 LocalAdapter）→ `GetMutableActorRequestSendProxy` 返回 `GetWorldProxyForwardMailbox` 或 `GetProxyMailbox()` → `SendProxy:SendMutableActorRequest` 把 BatchMutableActorRequest RPC 到 GS 侧 WorldProxyService（见 K11）。

**LOAD 分支的本地处理**（`local_world_proxy_subsystem.lua:599-616`）：按 Target 解析 ActorProxies，对每个 ActorProxy 调 `RequestLoad({bTransformValid, Transform, RuntimeTags, RuntimeLifetimeEndTs})`，其中 `RuntimeLifetimeEndTs = ExistTime>0 and now+ExistTime or 0`（业务指定 ExistTime → 转为截止时间戳）。

**查找意义**：跨进程 MutableActor 调用链追踪时，LocalAdapter 是整条链同进程闭合的关键判定点。看到 `LocalWorldProxySubsystem` 路径就知道不需要去 GS 侧找 handler。

**相关**：`tactics.md` 无对应条目（跨进程调用链追踪属 T9 调用方的扩展场景）；与 K11（GS 侧 LOAD handler）互补，二者共同覆盖 MutableActor 请求的两种落地路径。

---

## K11 · MutableActor 请求 spawn 终点 + GS 侧 LOAD handler 坐标

**摘要**：MutableActor 请求"最终把 Actor spawn 出来"的终点是 `MutableActorSubsystem:SpawnEditorActor` / `SpawnNamedRuntimeActor`（DS Lua）→ `GameAPI.SpawnActor`（UE `SpawnActor`）。C++→蓝图的桥是 `UDSLocalWorldProxySubsystem::CreateMutableActorInGame`（UFUNCTION）。GS 侧（WorldProxyManagerService）的 LOAD handler 在 `MutableActorManager:LoadMutableActor`（Lua，非 Go），GS 不实际 spawn UE Actor，而是通过 ActorOpManager 驱动目标 DS。

**详述**：

### DS 侧 spawn 终点链路

```
LocalSpawnableActorProxy:RequestLoad (local_spawnable_actor_proxy.lua:280)
  → _DoLoad (:323) → OpManager:RequestLoad
  → LocalActorProxy:IssueCreateActor (local_actor_proxy.lua:219)
  → self:GetManager():CreateMutableActorInGame(ActorID, ActorMsgWrapper, CreateType, bPropertiesFromDB, TemplateEditorID, LoadVersion)
  → UDSLocalWorldProxySubsystem::CreateMutableActorInGame  [C++ UFUNCTION]
      DevIntelligence 注解: DevIntelligence/.../DSLocalWorldProxySubsystem.lua:102 (基类只导出1参, 蓝图子类覆写支持6参)
  → MutableActorSubsystem:SpawnActorInDatabaseCache (mutable_actor_subsystem.lua:104)
      → SpawnEditorActor (:138, Editor类型) / SpawnNamedRuntimeActor (:178, Runtime类型)
  → GameAPI.SpawnActor(GameWorld, Class, Transform, SpawnParameters, ExtraData, ExtraSpawnOp)
      [UE UWorld::SpawnActor 的 Lua 反射绑定, 全局 GameAPI 表]
```

**关键签名陷阱**：`CreateMutableActorInGame` 的 DevIntelligence 注解只导出 C++ 基类 1 参签名 `CreateMutableActorInGame(ActorID)`，但 `local_actor_proxy.lua:223` 实际传 6 参。原因是蓝图子类覆写了 UFUNCTION 签名——这是 UE 蓝图反射的固有限制，DevIntelligence 只能拿到 C++ 基类声明。查调用约定时以 Lua 调用点实参为准，不要被 DevIntelligence 1 参签名误导。

### GS 侧 LOAD handler（远程模式路径 B）

GS 的 WorldProxyManagerService 是 **C++ 服务 + Lua 脚本**（不是 Go），MutableActor 逻辑全在 Lua：

```
DS: MutableActorComponent:ProcessRemoteForwarding (mutable_actor_component.lua:1894)
  → SendProxy:SendMutableActorRequest(Request, Callback)  [RPC 到 GS]
GS: BaseActorProxy:OnReceiveMutableActorRequest (GameServer/tsf4g-services/CppServices/WorldProxyManagerService/Script/MutableActor/BaseActorProxy.lua:191)
  → RequestReceiver:OnReceiveRequest (去重确认)
GS: MutableActorManager 分发 LOOP  (MutableActorManager.lua:1073 附近)
  → LOAD 分支: self:LoadMutableActor(InnerRequest.Target, InnerRequest.LoadMutableActorParam)  (:1073)
GS: MutableActorManager:LoadMutableActor (MutableActorManager.lua:1265)
  → 按 Target 解析 ActorProxies → ActorProxy:RequestLoad(SpecifiedLoadParams)
GS: SpawnableActorProxy:RequestLoad (SpawnableActorProxy.lua:304) → _DoLoad (:349)
GS: MutableActorProxy:IssueCreateActor (MutableActorProxy.lua:416)  [GS 不 spawn UE Actor]
  → 通过 ActorOpManager + SpacePartition 驱动目标 DS 实际 spawn
```

**GS 不 spawn UE Actor**：GS 侧 `IssueCreateActor` 不调 `SpawnActor`，而是通过 EntitySystem + tbuspp RPC 通知目标 DS 的 `LocalActorProxy:IssueCreateActor` 执行实际 spawn。GS 持有的是 ActorProxy（数据代理），不是 UE Actor 实例。

### GameServer 代码访问约定

`GameServer/` 在 CODELINK 下的路径前缀是 `GameServer/`（不是 `Projects/HiGame/GameServer/`）。当前为**手动链接**，session 开始时需 `ls CODELINK/GameServer/` 确认是否可访问——空目录说明未链接，无法查 GS 侧代码。后续会改为自动链接。

**查找意义**：追踪 MutableActor 跨进程调用链时，GS 侧 handler 的精确坐标。看到 `MutableActorManager.lua:1073` 的 RequestType 分发即知是 GS 侧 LOAD/UNLOAD/CREATE 等的总入口。

**相关**：与 K10（LocalAdapter 本地路径）互补；`pitfalls.md` 可补一条"DevIntelligence 只导出 C++ 基类签名，蓝图子类覆写签名时以 Lua 调用点实参为准"（候选 P14）。
