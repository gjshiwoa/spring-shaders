# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## 项目概述
这是一个名为"0春 v2"的OptiFine/Iris Minecraft着色器包，实现了基于物理渲染(PBR)的高级光照、大气效果和后处理功能。

## 开发工作流程

### 测试与验证
- 无构建步骤 - 着色器由Minecraft直接加载
- 使用Iris或OptiFine模组加载着色器
- 通过切换着色器包或使用游戏内重新加载(R)进行重载
- 在`.minecraft/logs/latest.log`中检查编译错误
- 跨维度测试：主世界、下界、末地
- 验证各种条件：白天/夜晚、雨天/雾天、水下

### 常见开发任务
- 快速迭代时，专注于单个通道(如`program/deferred.glsl`)
- 在受控的世界环境中测试以隔离更改
- 比较修改前后的视觉效果和性能
- 注意视觉伪影：光晕、NaN值、色带、闪烁、时间重影
- 在常见后期选项开启/关闭的情况下运行(TAA、SSAO、泛光)以确保兼容性

## 配置系统

### 设置管理
- 所有着色器选项在`lib/settings.glsl`中使用`#define`语句定义
- UI配置在`shaders.properties`中设置屏幕布局和选项范围
- 本地化在`lang/zh_cn.lang`中
- 重型/计算密集型功能应放在切换开关后
- 为所有选项提供安全的默认值

### 添加新选项
1. 在`lib/settings.glsl`中使用适当范围定义选项
2. 在`shaders.properties`UI布局和滑块配置中添加
3. 在`lang/zh_cn.lang`中添加中文本地化
4. 使用`#ifdef OPTION_NAME`保护昂贵代码

## 代码风格指南

### 样式指南
- 缩进：4个空格，不使用制表符
- 行保持在约120字符以下
- 函数/变量：camelCase(`waterReflectionRefraction`, `exposureCurve`)
- 常量/宏：UPPER_SNAKE_CASE
- 优先使用`lib/`模块中的小型、纯辅助函数
- 保持通道文件专注于编排

### 代码组织
- 通过相对路径包含公共头文件：`#include "lib/camera/toneMapping.glsl"`
- 使用材质ID进行方块/实体分类(在`lib/settings.glsl`中定义)
- 使用`#ifdef`块保护平台特定功能
- 验证输入以防止视觉伪影和驱动程序问题

## 性能考虑

### 优化指南
- 将昂贵计算放在质量切换开关后
- 尽可能使用自适应采样(最小/最大样本数)
- 为光线行进实现早期退出条件
- 考虑为昂贵效果使用时间重投影
- 平衡默认设置的质量与性能

## 调试与故障排除

### 常见问题
- 视觉伪影：检查NaN值、除以零、限制问题
- 性能下降：分析特定通道，检查样本数
- 编译错误：验证语法，检查包含路径，验证GLSL版本
- 光线泄漏：确保适当的深度测试和法线处理

### 调试技术
- 使用条件编译隔离有问题的功能
- 为中间结果实现调试可视化模式
- 记录uniform值和纹理绑定
- 使用最小设置测试以建立基线

## 语言与交流
- 这是一个中文着色器包 - 用户界面内容使用中文
- 为所有新选项维护中文本地化
- 用户文档和注释应在适当时使用中文