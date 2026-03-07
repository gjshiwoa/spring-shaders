# Project Coding Rules (Non-Obvious Only)

- `world` 包装层不是可选：`shaders/world0/*` -> `program/*`，`world1/*` -> `program/world_1/*`，`world-1/*` -> `program/world__1/*`（下界是双下划线）。
- 包装文件必须先定义阶段宏（`FSH/VSH/GSH/CSH`，按需加 `GBF/END/NETHER`）再 `#include`；漏定义会直接走错分支。
- GBuffer pass 若漏 `GBF`，`uniform` 会从 `gaux1..4` 回退到 `colortex4..7`，结果是“能编译但读错缓冲”。
- 含 `CLOUD3D`（或 `SKY_BOX/SHD/PROGRAM_VLF`）的 pass 中，`colortex2/8` 是 `sampler3D`；同一采样代码不能无脑复用到 2D pass。
- 方块材质 ID 修改需四处同步：`block.properties` -> `lib/common/materialIdMapper.glsl` -> `lib/settings.glsl` 常量 -> CT4 打包/解包语义。
- `block id 10` 被映射为 `NO_ANISO`；在 `gbuffers_terrain` 会强制跳过各向异性过滤，删掉会引入伪影。
- include 顺序是隐式约束：先 `uniform/settings/utils`，再 `common`，最后功能模块；调换顺序会触发宏/类型未定义。

