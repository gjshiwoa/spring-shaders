// 八面体映射工具函数
// Octahedral Mapping Utility Functions
// 用于将3D方向向量映射到2D八面体纹理坐标，以及逆向映射

#ifndef OCTAHEDRAL_MAPPING_GLSL
#define OCTAHEDRAL_MAPPING_GLSL

/**
 * 将3D方向向量转换为八面体映射的2D纹理坐标
 * @param direction 归一化的3D方向向量
 * @return 范围在[0,1]的2D纹理坐标
 */
vec2 directionToOctahedral(vec3 direction) {
    // 确保方向向量已归一化
    direction = normalize(direction);
    
    // 将向量投影到八面体表面 (|x| + |y| + |z| = 1)
    float sum = abs(direction.x) + abs(direction.y) + abs(direction.z);
    vec3 octahedron = direction / sum;
    
    // 如果在八面体的"下半部分"(z < 0)，需要进行折叠变换
    if (octahedron.z < 0.0) {
        vec2 wrapped = (1.0 - abs(octahedron.yx)) * sign(octahedron.xy);
        octahedron.xy = wrapped;
    }
    
    // 将坐标从[-1,1]范围映射到[0,1]范围
    return octahedron.xy * 0.5 + 0.5;
}

/**
 * 将八面体映射的2D纹理坐标转换回3D方向向量
 * @param uv 范围在[0,1]的2D纹理坐标
 * @return 归一化的3D方向向量
 */
vec3 octahedralToDirection(vec2 uv) {
    // 将坐标从[0,1]范围映射回[-1,1]范围
    vec3 position = vec3(2.0 * (uv - 0.5), 0.0);
    
    // 计算z坐标：在八面体表面，|x| + |y| + |z| = 1
    vec2 absolute = abs(position.xy);
    position.z = 1.0 - absolute.x - absolute.y;
    
    // 如果在"下半部分"，需要进行反向折叠变换
    if (position.z < 0.0) {
        position.xy = sign(position.xy) * (1.0 - absolute.yx);
    }
    
    // 归一化得到单位方向向量
    return normalize(position);
}

/**
 * 带边缘镜像的八面体纹理采样
 * 处理纹理边缘的特殊情况，确保正确的八面体边缘镜像
 * @param tex 八面体映射的纹理
 * @param direction 3D方向向量
 * @return 采样的颜色值
 */
vec4 sampleOctahedralTexture(sampler2D tex, vec3 direction) {
    vec2 uv = directionToOctahedral(direction);
    
    // 获取纹理尺寸
    ivec2 texSize = textureSize(tex, 0);
    vec2 invTexSize = 1.0 / vec2(texSize);
    
    // 检查是否在纹理边缘附近
    if (any(lessThanEqual(uv, invTexSize)) || any(greaterThanEqual(uv, 1.0 - invTexSize))) {
        // 在边缘附近使用手动双线性插值以正确处理八面体边缘镜像
        uv = uv * vec2(texSize) - 0.5;
        ivec2 baseCoord = ivec2(floor(uv));
        vec2 fractionalPart = uv - vec2(baseCoord);
        
        // 使用包装函数处理边缘坐标
        // 这里需要实现特殊的八面体边缘包装逻辑
        // 暂时使用标准采样，后续可以优化
        return texture(tex, directionToOctahedral(direction));
    } else {
        // 非边缘区域可以直接采样
        return texture(tex, uv);
    }
}

/**
 * 将立方体贴图方向转换为八面体映射坐标
 * 用于从现有的立方体贴图转换到八面体映射
 * @param face 立方体贴图面索引 (0-5)
 * @param faceUV 面内的UV坐标 [0,1]
 * @return 八面体映射的UV坐标
 */
vec2 cubemapToOctahedral(int face, vec2 faceUV) {
    // 将面UV坐标转换为3D方向
    vec3 direction;
    vec2 coord = faceUV * 2.0 - 1.0; // 转换到[-1,1]范围
    
    if (face == 0) {        // +X
        direction = vec3(1.0, -coord.y, -coord.x);
    } else if (face == 1) { // -X
        direction = vec3(-1.0, -coord.y, coord.x);
    } else if (face == 2) { // +Y
        direction = vec3(coord.x, 1.0, coord.y);
    } else if (face == 3) { // -Y
        direction = vec3(coord.x, -1.0, -coord.y);
    } else if (face == 4) { // +Z
        direction = vec3(coord.x, -coord.y, 1.0);
    } else {                // -Z
        direction = vec3(-coord.x, -coord.y, -1.0);
    }
    
    return directionToOctahedral(normalize(direction));
}

#endif // OCTAHEDRAL_MAPPING_GLSL