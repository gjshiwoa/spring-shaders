// https://zhuanlan.zhihu.com/p/525500877
vec2 offset = vec2(10.0 * invViewSize.x, 0.0);
vec4 uvTable[9] = vec4[](
    vec4(0.0, 0.0, 1.0, 1.0),
    vec4(0.0, 0.0, 0.5, 0.5),
    vec4(0.0, 0.0, 0.25, 0.25),
    vec4(0.25, 0.0, 0.375, 0.125) + offset.xyxy,
    vec4(0.375, 0.0, 0.4375, 0.0625) + 2.0 * offset.xyxy,
    vec4(0.4375, 0.0, 0.46875, 0.03125) + 3.0 * offset.xyxy,
    vec4(0.46875, 0.0, 0.484375, 0.015625) + 4.0 * offset.xyxy,
    vec4(0.484375, 0.0, 0.4921875, 0.0078125) + 5.0 * offset.xyxy,
    vec4(0.4921875, 0.0, 0.49609375, 0.00390625) + 6.0 * offset.xyxy
);

#ifdef BLOOM_DOWNSAMPLE
    vec4 uvI = uvTable[BLOOM_LOD - 1];
    vec4 uvO = uvTable[BLOOM_LOD];
    vec2 uv = vec2(remap(texcoord.s, uvO.x, uvO.z, uvI.x, uvI.z), remap(texcoord.t, uvO.y, uvO.w, uvI.y, uvI.w));

    vec3 color = vec3(0.0);
    #if BLOOM_LOD == 1
        if(!isOutsideRange(texcoord, uvO.xy, uvO.zw)) color = gaussianBlur5x5(colortex0, uv, 2.0).rgb;
        if(any(greaterThan(texcoord.xy, uvO.zw + vec2(offset.x)))) discard;
    #elif BLOOM_LOD == 2
        if(!isOutsideRange(texcoord, uvO.xy, uvO.zw)) color = gaussianBlur5x5(colortex1, uv, 2.0).rgb;
        if(texcoord.x > uvTable[8].z + offset.x || texcoord.y > 0.25 + offset.x) discard;
    #elif BLOOM_LOD == 3
        color = texture(colortex1, texcoord).rgb;
        if(!isOutsideRange(texcoord, uvO.xy, uvO.zw)) color = gaussianBlur5x5(colortex1, uv, 2.0).rgb;
        if(texcoord.x > uvTable[8].z + offset.x || texcoord.y > 0.25 + offset.x) discard;
    #else
        color = texture(colortex1, texcoord).rgb;
        if(!isOutsideRange(texcoord, uvO.xy, uvO.zw)) color = gaussianBlur5x5(colortex1, uv, 2.0).rgb;
        if(texcoord.x > uvO.z + offset.x || texcoord.y > 0.25 + offset.x) discard;
    #endif
#endif

#ifdef BLOOM_UPSAMPLE
    const vec4 uvO = vec4(0.0, 0.0, 1.0, 1.0);

    #if BLOOM_MODE == 0
        const float bloomWeights[7] = float[](
            1.62, 1.56, 1.49, 1.41, 1.32, 1.19, 1.0
        );
    #elif BLOOM_MODE == 1
        const float bloomWeights[7] = float[](
            1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
        );
    #elif BLOOM_MODE == 2
        const float bloomWeights[7] = float[](
            1.0, 1.19, 1.32, 1.41, 1.49, 1.56, 1.62
        );
    #endif

    for (int i = 0; i < BLOOM_LAYERS; ++i) {
        vec4 uvI = uvTable[i+2];
        vec2 uv = vec2(remap(texcoord.s, uvO.x, uvO.z, uvI.x, uvI.z), 
                    remap(texcoord.t, uvO.y, uvO.w, uvI.y, uvI.w));
        blur += textureBicubic(colortex1, uv).rgb * bloomWeights[i];
    }
#endif