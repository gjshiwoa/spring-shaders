# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## 项目架构规则（非显而易见部分）

### 渲染管线架构
- 多通道延迟渲染系统：几何缓冲 → 延迟光照 → 后期处理 → 最终合成
- G-缓冲区布局在 `lib/settings.glsl:28-39` 中定义，包含位置、法线、材质ID等数据
- 纹理绑定在 `program/composite.glsl:9-22` 中指定，使用特定格式优化精度
- 维度特定渲染通过 `program/world_1/`（末地）和 `program/world__1/`（下界）实现

### 模块化设计
- `lib/` 目录按功能分类：大气散射、相机效果、光照计算、表面材质、水面效果
- 每个模块专注于特定功能，通过相对路径包含实现解耦
- 通用工具函数在 `lib/common/` 中，包括噪声生成、位置计算、法线处理
- 特殊效果如植物动画、水面反射/折射有独立模块

### 材质系统架构
- 材质ID系统通过 `lib/common/materialIdMapper.glsl` 统一管理
- 方块属性在 `block.properties` 中定义，实体属性在 `entity.properties` 中定义
- PBR材质属性包括粗糙度、反射率、次表面散射等
- 特殊材质如水面、植物、发光方块有专门处理路径

### 性能优化架构
- 条件编译系统允许根据硬件能力启用/禁用功能
- 自适应采样模式根据性能需求动态调整样本数
- 时间重投影技术减少帧间噪声，提高视觉质量
- 预计算查找表（LUT）用于大气散射等复杂计算

### 配置系统架构
- `lib/settings.glsl` 定义所有着色器选项和默认值
- `shaders.properties` 管理UI布局、屏幕组织和参数范围
- 本地化系统支持多语言，主要使用中文（`lang/zh_cn.lang`）
- 预设配置文件（Balanced、Bright、Vivid、Native）提供快速设置

### 兼容性架构
- 支持 Iris 和 OptiFine 两种着色器加载器
- 版本检查通过 `MC_VERSION` 宏实现跨版本兼容
- 显卡特定优化路径，特别是 Intel 集成显卡
- 维度特定渲染确保在不同游戏维度中正常工作