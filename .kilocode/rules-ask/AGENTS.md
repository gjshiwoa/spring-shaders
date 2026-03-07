# Project Documentation Rules (Non-Obvious Only)

- `shaders/world*/*` 大多是入口包装层，不是功能实现；真正逻辑主要在 `shaders/program/*` 与 `shaders/lib/*`。
- 三维世界目录映射并不对称：`world0 -> program/*`，`world1 -> program/world_1/*`，`world-1 -> program/world__1/*`（下界双下划线）。
- 功能开关的“生效入口”优先看 `shaders/shaders.properties` 的 `program.world*/xxx.enabled`，不是只看 `#define`。
- UI 参数来源是双轨：`lib/settings.glsl` 的 `// [..]` 范围注释 + `shaders.properties` 的 `screen.* / sliders` 编排；只改一处会出现“代码有参数但界面不可调”。
- `colortex2/colortex8` 在配置中同时存在 2D/3D 绑定，且在 `uniform.glsl` 里按宏切换 sampler 类型；文档解释采样错误时要先确认 pass 宏。
- Voxy 入口仅在主世界包装层可见（`shaders/world0/voxy*`），不要假设末地/下界存在同名入口。
- 仓库内带 `* copy.glsl` 备份文件（如 `fog copy.glsl`），当前 include 链不会引用它们；说明实现时应以非 copy 文件为准。

