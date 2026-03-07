# Project Debug Rules (Non-Obvious Only)

- 本项目无命令行编译日志入口；“是否通过”要靠游戏内重载光影观察。
- 排错首选在 `shaders.properties` 里临时只启用一个 `program.world*/xxx.enabled`，做最小化复现。
- 若出现“能编译但读错缓冲”，先查 world 包装层是否漏 `GBF`（会把 `gaux1..4` / `colortex4..7` 采样源切错）。
- 若仅末地/下界异常，优先核对包装 include 目标：`world1 -> program/world_1`，`world-1 -> program/world__1`（双下划线）。
- 云/天空相关 pass 若采样报错，检查是否定义了 `CLOUD3D/SKY_BOX/SHD/PROGRAM_VLF`；这会把 `colortex2/8` 切为 `sampler3D`。
- 植物摇摆、各向异性、发光异常优先查 ID 链路：`block.properties -> materialIdMapper.glsl -> settings.glsl -> CT4 编解码`。
- 透明裁剪伪影先对齐 `alphaTest.*`：terrain/water/entities=0.005，shadow=0.01（见 `shaders.properties`）。

