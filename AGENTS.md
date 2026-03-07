# AGENTS.md

This file provides guidance to agents when working with code in this repository.

- 技术栈：Minecraft OptiFine/Iris 光影包（GLSL 4.50 compatibility）。仓库内无 npm/gradle/cmake 等构建系统。
- 构建/校验命令（项目实际情况）：
  - 无 CLI build/lint/test 脚本。
  - 单点“测试”做法：在 `shaders.properties` 里只开/关某个 `program.world*/xxx.enabled`，然后在游戏内重载光影观察编译结果。
  - 快速冒烟：改一个 `shaders/program/*.glsl` 后重载；`shaders/world*/*.fsh|vsh|csh|gsh` 只是入口包装层。
- 架构耦合（易踩坑）：
  - `shaders/world0/*` -> `shaders/program/*`（主世界）；`shaders/world1/*` -> `shaders/program/world_1/*`（末地）；`shaders/world-1/*` -> `shaders/program/world__1/*`（下界，双下划线）。
  - 包装文件必须先 `#define FSH/VSH/GSH/CSH`（可再加 `GBF/END/NETHER`）再 `#include` 对应 program 文件。
  - `GBF` 会把 `uniform` 纹理别名切到 `gaux1..4`，非 `GBF` 才是 `colortex4..7`；忘记 `GBF` 会直接读错 GBuffer。
  - 定义 `CLOUD3D`（或 `SKY_BOX/SHD/PROGRAM_VLF`）时，`colortex2/colortex8` 从 `sampler2D` 切成 `sampler3D`，类型必须跟随 pass 宏。
  - 方块 ID 流程是硬耦合：`block.properties` 数字 ID -> `materialIdMapper.glsl` -> `settings.glsl` 常量 -> `CT4.g` 打包（`ID_SCALE=255`）。
  - `block id 10` 映射 `NO_ANISO`，在地形 pass 中被强制跳过各向异性过滤（不是可选优化，而是防伪影约束）。
- 代码风格（项目特有）：
  - 参数开关集中在 `lib/settings.glsl` 的 `#define`，并保持 `// [..]` slider 注释格式（会被 `shaders.properties` UI 读取）。
  - 保持既有 include 顺序：`uniform/settings/utils` 在前，再 `common`，最后功能模块；改顺序容易触发宏/类型未定义。
  - GBuffer 编解码必须走 `lib/common/utils.glsl` 的 `pack/unpack`，并保持 `lib/common/gbufferData.glsl` 的通道语义不变。
  - 透明裁剪阈值要与 `shaders.properties` 的 `alphaTest.*` 同步（terrain/water/entities=0.005，shadow=0.01）。
