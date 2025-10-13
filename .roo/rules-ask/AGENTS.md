# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## 项目文档规则（非显而易见部分）

### 文档组织结构
- 主要功能实现在 `lib/` 目录中，按功能分类（大气、相机、光照等）
- 渲染通道在 `program/` 目录中，按渲染阶段组织（gbuffers_*, deferred*, composite*）
- 维度特定着色器在 `program/world_1/`（末地）和 `program/world__1/`（下界）
- 旧版本兼容文件在 `world0/`, `world1/`, `world-1/` 目录中

### 配置系统说明
- `lib/settings.glsl` 包含所有着色器选项的定义和默认值
- `shaders.properties` 定义 UI 布局、屏幕组织和滑块范围
- `lang/zh_cn.lang` 包含所有用户界面文本的中文本地化
- `block.properties` 和 `entity.properties` 定义材质ID映射

### 渲染管线文档
- 几何缓冲阶段（gbuffers_*.glsl）收集表面数据
- 延迟光照阶段（deferred*.glsl）计算光照
- 合成阶段（composite*.glsl）应用大气效果和后期处理
- 最终阶段（final.glsl）应用色调映射和输出

### 特殊实现细节
- 材质ID系统通过 `lib/common/materialIdMapper.glsl` 中的 `IDMapping()` 函数工作
- 植物动画使用时间函数和正弦波创建自然运动
- 水面效果结合 Gerstner 波和视差贴图
- 大气散射使用预计算的查找表优化性能

### 测试和验证
- 使用 Iris 或 OptiFine 加载着色器进行测试
- 按 R 键重新加载着色器（比切换着色器包更快）
- 检查 `.minecraft/logs/latest.log` 查找编译错误
- 在不同维度（主世界、下界、末地）和条件下（白天/夜晚、雨天）测试

### 性能考虑
- 高计算成本功能位于条件编译块后
- 使用自适应采样减少不必要的计算
- 光线行进算法实现早期退出条件
- 时间重投影用于减少帧间噪声