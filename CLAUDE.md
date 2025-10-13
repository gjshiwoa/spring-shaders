# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

本项目请始终用中文跟用户交流。

## Project Overview
This is an OptiFine/Iris Minecraft shaderpack called "0春 v2" (Chun v2) - a comprehensive PBR (Physically Based Rendering) shader with advanced lighting, atmospheric effects, and post-processing capabilities.

## Development Workflow

### Testing & Validation
- No build step - shaders are loaded directly by Minecraft
- Use Iris or OptiFine mod to load shaders
- Reload by toggling shaderpack or using in-game reload (F3+A)
- Check compile errors in `.minecraft/logs/latest.log`
- Test across dimensions: Overworld, Nether, End
- Verify conditions: day/night, rain/fog, underwater

### Common Development Tasks
- For quick iteration, focus on a single pass (e.g., `program/deferred.glsl`)
- Test in a controlled world environment to isolate changes
- Compare visuals and performance before/after modifications
- Watch for visual artifacts: halos, NaNs, banding, flicker, temporal ghosts
- Run with common post options on/off (TAA, SSAO, Bloom) to ensure compatibility

## Configuration System

### Settings Management
- All shader options are defined in `lib/settings.glsl` with `#define` statements
- UI configuration is in `shaders.properties` with screen layouts and option ranges
- Localization is in `lang/zh_cn.lang`
- Heavy/computationally expensive features should be behind toggles
- Provide safe default values for all options

### Adding New Options
1. Define the option in `lib/settings.glsl` with appropriate range
2. Add to `shaders.properties` UI layout and slider configuration
3. Add Chinese localization in `lang/zh_cn.lang`
4. Guard expensive code with `#ifdef OPTION_NAME`

## Repository Structure & Module Organization

### Core Directories
- `lib/` - Reusable GLSL modules organized by functionality:
  - `atmosphere/` - Atmospheric scattering, volumetric clouds, fog, celestial bodies
  - `camera/` - Post-processing effects (bloom, exposure, tone mapping, DOF, motion blur)
  - `common/` - Shared utilities (noise, position, normal, material mapping)
  - `lighting/` - Shadow mapping, RSM, SSAO, screen space shadows, lightmapping
  - `surface/` - PBR materials, parallax mapping
  - `water/` - Water rendering (waves, fog, reflection/refraction, caustics)

- `program/` - Render pass entry points:
  - `gbuffers_*.glsl` - Geometry buffer passes (terrain, water, entities, etc.)
  - `deferred*.glsl` - Deferred lighting passes
  - `composite*.glsl` - Post-processing passes
  - `shadow.glsl` - Shadow map rendering
  - `final.glsl` - Final composite pass

- `program/world_1/` and `program/world__1/` - Dimension-specific overrides (End, Nether)
- `world0/`, `world1/`, `world-1/` - Legacy per-dimension shader files
- `lang/` - Localization files (Chinese)
- `shaders.properties` - Shader configuration and UI layout

## Render Pipeline Architecture

### Multi-Pass Deferred Rendering
1. **Geometry Passes** (`gbuffers_*.glsl`):
   - Fill G-buffer with position, normal, material, lighting data
   - Different passes for terrain, water, entities, sky, etc.

2. **Deferred Lighting Passes** (`deferred*.glsl`):
   - Apply lighting calculations using G-buffer data
   - Multiple passes for different lighting components

3. **Post-Processing Passes** (`composite*.glsl`):
   - Atmospheric effects, bloom, tone mapping, anti-aliasing
   - Temporal accumulation for TAA

4. **Final Composite** (`final.glsl`):
   - Combine all effects and output final image

### Texture Management
- G-buffer layout defined in `lib/settings.glsl:28-39`
- Texture formats specified in `program/composite.glsl:9-22`
- Custom textures loaded via `shaders.properties:100-112`

## Lighting System Architecture

### Light Sources
- Direct sunlight/moonlight with atmospheric scattering
- Sky ambient light with configurable falloff
- Artificial light sources (torches, glowstone) with RGB color control
- Emissive materials with brightness control

### Shadow System
- Cascading shadow maps with configurable resolution and distance
- PCF filtering with adjustable sample counts
- Colored shadows for translucent materials
- Reflective shadow mapping (RSM) for indirect lighting
- Screen space shadows for contact shadows

### Atmospheric Effects
- Physically-based atmospheric scattering (Rayleigh + Mie)
- Volumetric clouds with multiple frequency noise
- Height-based fog with scattering properties
- Celestial bodies (sun, moon, stars) with configurable appearance

## Water Rendering System

### Surface Effects
- Gerstner waves with configurable frequency and amplitude
- Parallax wave displacement for depth perception
- Fresnel-based reflection/refraction
- Caustics for underwater light patterns

### Underwater Rendering
- Volumetric fog with phase functions
- Light absorption and scattering
- God rays through water surface
- Adjustable visibility and color parameters

## Material System

### PBR Properties
- Material ID system for different block types
- Configurable roughness and reflectance
- Subsurface scattering for appropriate materials
- Parallax occlusion mapping for depth

### Special Cases
- Hand-held items with separate lighting
- Weather effects (rain wetness)
- Emissive blocks with brightness control
- Transparent/translucent material handling

## Coding Standards

### Style Guidelines
- Indentation: 4 spaces, no tabs
- Keep lines under ~120 characters
- Functions/variables: camelCase (`waterReflectionRefraction`, `exposureCurve`)
- Constants/macros: UPPER_SNAKE_CASE
- Prefer small, pure helper functions in `lib/` modules
- Keep pass files focused on orchestration

### Code Organization
- Include common headers via relative paths: `#include "lib/camera/toneMapping.glsl"`
- Use material IDs for block/entity classification (defined in `lib/settings.glsl`)
- Guard platform-specific features with `#ifdef` blocks
- Validate inputs to prevent visual artifacts and driver issues

## Performance Considerations

### Optimization Guidelines
- Place expensive computations behind quality toggles
- Use adaptive sampling where possible (min/max sample counts)
- Implement early-out conditions for ray marching
- Consider temporal reprojection for expensive effects
- Balance quality vs performance for default settings

### Memory Management
- Be mindful of texture bindings and LUT sizes
- Reuse buffers where possible across passes
- Consider bandwidth implications of large render targets

## Debugging & Troubleshooting

### Common Issues
- Visual artifacts: Check for NaN values, divide by zero, clamping issues
- Performance drops: Profile specific passes, check sample counts
- Compilation errors: Verify syntax, check include paths, validate GLSL version
- Light leaks: Ensure proper depth testing and normal handling

### Debug Techniques
- Use conditional compilation to isolate problematic features
- Implement debug visualization modes for intermediate results
- Log uniform values and texture bindings
- Test with minimal settings to establish baseline

## Language & Communication
- This is a Chinese shaderpack - use Chinese for user-facing content
- Maintain Chinese localization for all new options
- User documentation and comments should be in Chinese where appropriate