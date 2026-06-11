# AGENTS.md

Minecraft OptiFine/Iris 光影包（GLSL 4.50 compatibility）。无 npm/gradle/cmake 等构建系统。

## 测试

- 无 CLI 测试。唯一验证方式：游戏内 F3+R 重载光影观察编译结果。
- 排错时在 `shaders.properties` 临时只启用单个 `program.world*/xxx.enabled` 做最小化复现。
- 快速冒烟：改 `shaders/program/*.glsl` 后重载；`shaders/world*/*` 只是入口包装层。

## 架构

### 双层架构：包装层 + 实现层

- `shaders/world*/*.fsh|vsh|csh|gsh` — 仅注入维度/阶段宏并 `#include` 路由到 program。
- `shaders/program/*.glsl` + `shaders/lib/*` — 功能实现主体。

### 维度路由（硬编码分片）

| 包装目录 | include 目标 | 说明 |
|----------|-------------|------|
| `world0/` | `/program/*` | 主世界 |
| `world1/` | `/program/world_1/*` | 末地 |
| `world-1/` | `/program/world__1/*` | 下界（双下划线） |

- 跨维共享改动通常需要三处对齐。
- Deferred pass 按维度分化：并非所有维度都有相同的 deferred 文件集（如 world__1 缺少 deferred5/21，world_1 另有 deferred9）。

### 包装文件编写规则

```glsl
#version 450 compatibility
#define FSH        // 或 VSH / GSH / CSH
#define GBF        // 如为 GBuffer pass，必须有
#define NETHER     // 或 END（按维度需要）
#include "/program/some_program.glsl"
```

- 必须先 `#define` 阶段宏再 `#include`；漏定义会走错代码分支。
- **`GBF` 是 GBuffer pass 强制要求**：`uniform.glsl` 依赖 `GBF` 将纹理别名切到 `gaux1..4`，否则回退到 `colortex4..7`，结果"能编译但读错缓冲"。

### sampler 维度路由器

- **`CLOUD3D` / `SKY_BOX` / `SHD` / `PROGRAM_VLF`**：定义时 `colortex2` 和 `colortex8` 为 `sampler3D`，未定义时为 `sampler2D`。同一段采样代码复用前必须确认 pass 宏。
- **`GBF`**：切换 GBuffer 采样源 `gaux1..4` ↔ `colortex4..7`。

### Path Tracing / Colored Light 联合开关

启用 `PATH_TRACING` 或 `COLORED_LIGHT` 时，以下 program 必须**同步启用**，否则依赖缓冲缺失：
- `begin`
- `shadowcomp_a/b/c`、`shadowcomp`、`shadowcomp1_a/b`
- `deferred6`、`deferred7`、`deferred8`

### Voxy 体素链路

- Voxy 入口仅主世界存在（`world0/voxy_opaque.glsl`、`world0/voxy_translucent.glsl`）。
- 末地/下界仅有 `voxy.json` 配置文件，无实际 GLSL 入口。
- `VOXY` 宏会改变部分 pass 的 RENDERTARGETS 数量与写入布局。

### Distant Horizons

- `dh_*` 包装文件（`dh_terrain`、`dh_water`、`dh_shadow`）仅在 `world0/` 存在，末地/下界无 DH 入口。

### 方块 ID 硬耦合链路

`block.properties` 数字 ID → `materialIdMapper.glsl` 映射 → `settings.glsl` 常量 → CT4 打包（`ID_SCALE=255`）

修改任一环节需四处同步。
- **`block id 10` → `NO_ANISO`**：在 `gbuffers_terrain` 强制跳过各向异性过滤，不是可选优化而是防伪影约束，不可删除。

## 约定

### Include 顺序（隐式约束）

先 `uniform` → `settings` → `utils`，再 `common`，最后功能模块。调换顺序容易触发宏/类型未定义。

### settings.glsl 参数开关

参数集中在 `lib/settings.glsl` 的 `#define`，必须保持 `// [value1 value2 ...]` slider 注释格式——会被 `shaders.properties` UI 读取。改参数需确认 `screen.*` 和 `sliders` 编排也包含该参数名。

### GBuffer 编解码

必须走 `lib/common/utils.glsl` 的 `pack/unpack` 函数，并保持 `lib/common/gbufferData.glsl` 的通道语义不变。`CT4/CT5` 字段被多个 deferred pass 复用，改任一字段会级联破坏光照链路。

### alphaTest 阈值

与 `shaders.properties` 的 `alphaTest.*` 保持同步：terrain/water/entities=0.005，shadow=0.01。

### `customimg*` 资源

- `customimg0/4/5/6`（voxel/voxelLitSky/voxelPrev/voxelLitSkyPrev）在 `PATH_TRACING || COLORED_LIGHT` 下创建。
- `customimg1/2/3`（tmpX/tmpY/SDF）仅在 `PATH_TRACING` 下创建。
- 扩展资源分配必须先保证 `shaders.properties` 声明与宏条件一致。

### 死代码

仓库内 `* copy.glsl` 文件（如 `fog copy.glsl`、`parallaxMapping copy.glsl` 等）是备份/草稿，不在当前 include 链中，不应引用或修改。
