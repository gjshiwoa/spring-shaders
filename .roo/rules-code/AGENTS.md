# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## 项目编码规则（仅非显而易见部分）

### 着色器文件结构
- 所有着色器文件必须包含 `#ifdef FSH` 和 `#ifdef VSH` 部分
- 使用 `#include "/lib/uniform.glsl"` 和 `#include "/lib/settings.glsl"` 作为前两个包含
- 纹理绑定格式定义在文件顶部（如 `const int colortex0Format = RGBA16F;`）
- 使用 `/* DRAWBUFFERS:x */` 注释指定输出缓冲区

### 材质ID系统
- 使用 `lib/settings.glsl` 中定义的材质ID常量（如 `PLANTS_SHORT`, `WATER`, `ENTITIES`）
- 材质ID映射通过 `lib/common/materialIdMapper.glsl` 中的 `IDMapping()` 函数处理
- 方块属性在 `block.properties` 中定义，实体属性在 `entity.properties` 中定义

### 纹理和缓冲区管理
- G-缓冲区布局在 `lib/settings.glsl:28-39` 中定义
- 纹理格式在 `program/composite.glsl:9-22` 中指定
- 自定义纹理通过 `shaders.properties:100-112` 加载
- 使用 `texelFetch()` 而非 `texture()` 进行精确像素访问

### 优化关键点
- 将昂贵计算放在 `#ifdef` 条件编译块后
- 使用自适应采样模式（最小/最大样本数）
- 光线行进必须实现早期退出条件
- 考虑为昂贵效果使用时间重投影

### 命名约定
- 函数/变量：camelCase（如 `waterReflectionRefraction`, `exposureCurve`）
- 常量/宏：UPPER_SNAKE_CASE（如 `PI`, `HALF_PI`）
- 纹理单元：colortex0-9，shadowtex0-1，shadowcolor0-1
- 位置向量：viewPos, worldPos, lightPos

### 特殊处理
- 植物动画在 `lib/wavingPlants.glsl` 中处理
- 水面反射/折射在 `lib/water/waterReflectionRefraction.glsl` 中
- 大气散射在 `lib/atmosphere/atmosphericScattering.glsl` 中
- 阴影映射在 `lib/lighting/shadowMapping.glsl` 中

### 调试技巧
- 使用条件编译隔离有问题的功能
- 实现调试可视化模式显示中间结果
- 检查 NaN 值和除以零错误
- 验证输入范围以防止视觉伪影