# Project Architecture Rules (Non-Obvious Only)

- 渲染架构是“包装层(world*) + 实现层(program/lib)”双层：world 文件只负责注入维度/阶段宏并路由 include，功能实现必须落在 `program/*` 或 `lib/*`。
- 三维度实现路径是硬编码分片：主世界用 `program/*`，末地用 `program/world_1/*`，下界用 `program/world__1/*`；跨维共享改动通常需要三处对齐。
- GBuffer 通道语义由 `lib/common/gbufferData.glsl` 与 pack/unpack 约定固定，`CT4/CT5` 字段被多个 deferred pass 复用，改任一字段会级联破坏后续光照链路。
- Path Tracing/Colored Light 不是单一开关：需与 `shaders.properties` 里的 `begin`、`shadowcomp*`、`deferred6/7/8` 等 program 启用关系联动，否则会出现依赖缓冲缺失。
- `GBF` 与 `CLOUD3D` 都是跨模块类型路由器：前者切换 gbuffer 采样源（`gaux*` vs `colortex4..7`），后者切换 `colortex2/8` 的 sampler 维度（2D vs 3D）。
- Voxy 体素链路是条件化架构：仅主世界有 `world0/voxy*` 入口，且 `VOXY` 会改变部分 pass 的 `RENDERTARGETS` 数量与写入布局。
- 资源分配由 `shaders.properties` 驱动（`texture.*` 与 `image.*`）；`customimg*` 仅在特定宏下创建，架构扩展必须先保证资源声明与宏条件一致。

