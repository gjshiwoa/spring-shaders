#ifdef FSH
vec2 waterRefractionCoord(vec3 normalTex, vec3 worldNormal, float worldDis0, float intensity){
    vec3 waterOriNormal = normalTex;
    worldNormal.xy -= waterOriNormal.xy;

    vec2 fragCoord = gl_FragCoord.xy * invViewSize;
    vec2 refractCoord = fragCoord - clamp(worldNormal.xy * intensity / (worldDis0 + 0.0001), vec2(-1.0), vec2(1.0));
    if(outScreen(refractCoord)) 
        refractCoord = fragCoord;

    return refractCoord;
}
#include "/lib/common/octahedralMapping.glsl"

// 排除 SSR 命中天空
bool isNotSky(vec2 screenUV){
    #ifdef DISTANT_HORIZONS
        return texture(dhDepthTex0, screenUV).r < 1.0
            || texture(depthtex1,   screenUV).r < 1.0;
    #elif defined VOXY
        return texture(depthtex1,      screenUV).r < 1.0
            || texture(vxDepthTexTrans, screenUV).r < 1.0;
    #else
        return texture(depthtex1, screenUV).r < 1.0;
    #endif
}

// 屏幕空间反射光线行进（SSRT）
// 返回命中 UV；未命中返回 vec2(-1.0)，outMissPos 输出最后有效采样点供 PT fallback
vec2 SSRT(vec3 viewPos, vec3 reflectViewDir, vec3 normalTex, out vec3 outMissPos){
    // 起点沿法线偏移，避免自相交
    vec3 startPos = viewPos;
    float worldDis = length(viewPos);
    #ifdef GBF
        startPos += normalTex * 0.2;
    #elif defined VOXY_WATER
        startPos += normalTex * clamp(worldDis / 60.0, 0.1, 5.0);
    #else
        startPos += normalTex * clamp(worldDis / 60.0, 0.01, 0.33);
    #endif

    float curStep       = REFLECTION_STEP_SIZE;
    float cumUnjittered = 0.0;
    float jitter        = temporalBayer64(gl_FragCoord.xy);

    vec3 preTestPos    = startPos;
    vec3 curTestPos    = startPos;
    vec3 testScreenPos = viewPosToScreenPos(vec4(startPos, 1.0)).xyz;
    bool isHit         = false;

    outMissPos = vec3(0.0);

    // DH / Voxy 扩大采样次数
    float N_SAMPLES = REFLECTION_SAMPLES;
    #if defined VOXY || defined DISTANT_HORIZONS
        N_SAMPLES *= 1.5;
    #endif

    // 主循环：指数步进
    for (int i = 0; i < int(N_SAMPLES); ++i){
        cumUnjittered += curStep;
        float adjustedDist = cumUnjittered - jitter * curStep;
        curTestPos    = startPos + reflectViewDir * adjustedDist;
        testScreenPos = viewPosToScreenPos(vec4(curTestPos, 1.0)).xyz;

        if (outScreen(testScreenPos.xy)){
            outMissPos = preTestPos;
            return vec2(-1.0);
        }

        float closest = texture(depthtex1, testScreenPos.xy).r;
        #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
            #ifdef GBF
                float dhDepth = texture(dhDepthTex1, testScreenPos.xy).r;
            #else
                float dhDepth = texture(dhDepthTex0, testScreenPos.xy).r;
            #endif
            vec4 dhViewPos = screenPosToViewPosDH(vec4(testScreenPos.xy, dhDepth, 1.0));
            closest = min(closest, viewPosToScreenPos(dhViewPos).z);
        #endif
        vec3 ivalueTestScreenPos = vec3(testScreenPos.xy, closest);

        // 穿过表面：进入二分细化
        if (testScreenPos.z > closest){
            isHit = true;

            vec3  ds       = curTestPos - preTestPos;
            vec3  probePos = curTestPos;
            float sig      = -1.0;
            float closestB = 1.0;

            // 5 次二分精修
            for (int j = 1; j <= 5; ++j){
                float n = pow(0.5, float(j));
                probePos      = probePos + sig * n * ds;
                testScreenPos = viewPosToScreenPos(vec4(probePos, 1.0)).xyz;

                closestB = texture(depthtex1, testScreenPos.xy).r;
                #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
                    #ifdef GBF
                        float dhDepthB = texture(dhDepthTex1, testScreenPos.xy).r;
                    #else
                        float dhDepthB = texture(dhDepthTex0, testScreenPos.xy).r;
                    #endif
                    vec4 dhViewPosB = screenPosToViewPosDH(vec4(testScreenPos.xy, dhDepthB, 1.0));
                    closestB = min(closestB, viewPosToScreenPos(dhViewPosB).z);
                #endif
                sig = sign(closestB - testScreenPos.z);
            }

            // 过滤擦边命中伪影
            vec3  newTestPos = screenPosToViewPos(vec4(ivalueTestScreenPos, 1.0)).xyz;
            float tp_dist    = distance(curTestPos, newTestPos);
            float ds_len     = length(ds);
            float cosA       = dot(reflectViewDir, normalize(normalTex));
            if (tp_dist < ds_len * saturate(sqrt(1.0 - cosA * cosA))){
                if (isNotSky(testScreenPos.xy)) return testScreenPos.st;
                outMissPos = preTestPos;
                return vec2(-1.0);
            }
            outMissPos = preTestPos;
            break;
        }

        preTestPos = curTestPos;
        curStep   *= REFLECTION_STEP_GROWTH_BASE;
    }

    // 未命中：最终采样点若非天空视为远端命中
    if (!isHit){
        if (isNotSky(testScreenPos.xy)) return vec2(testScreenPos.xy);
        outMissPos = curTestPos;
        return vec2(-1.0);
    }

    return vec2(-1.0);
}

vec3 skyReflection(vec3 reflectWorldDir){
    #ifndef GBF
        vec3 reflectSkyColor = texture(colortex7, clamp(directionToOctahedral(reflectWorldDir) * 0.5, 0.0, 0.5 - 1.0 / 512.0)).rgb;
    #else
        vec3 reflectSkyColor = texture(gaux4, clamp(directionToOctahedral(reflectWorldDir) * 0.5, 0.0, 0.5 - 1.0 / 512.0)).rgb;
    #endif

    return max(reflectSkyColor, vec3(0.0));
}

vec3 reflection(sampler2D tex, vec3 viewPos, vec3 reflectWorldDir, vec3 reflectViewDir, 
                float lightmap, vec3 normalTex, float colorScale, inout bool ssrTargetSampled){
    vec3 reflectColor = vec3(0.0);
    vec3 NW = mat3(gbufferModelViewInverse) * normalTex;
    vec3 worldPos = viewPosToWorldPos(vec4(viewPos, 1.0)).xyz;

    vec3 missPos = vec3(0.0);

    vec2 testScreenPos = SSRT(viewPos, reflectViewDir, normalTex, missPos);
    vec2 velocity = texture(colortex9, testScreenPos.xy).xy;
    testScreenPos.xy = testScreenPos.xy - velocity;

    if(testScreenPos.x >= 0.0 && testScreenPos.y >= 0.0){
        ssrTargetSampled = true;
        
        reflectColor = texture(tex, testScreenPos.xy).rgb * colorScale;
    }else{
        #ifdef PATH_TRACING_REFLECTION
        #endif
        #if defined PATH_TRACING_REFLECTION && defined PATH_TRACING
            vec3 roRel = viewPosToWorldPos(vec4(missPos, 1.0)).xyz;
            vec3 hitPosRel;
            ivec3 hitVoxel;
            vec3 hitNormal;
            bool vxHit = voxelDDA_Raycast(
                roRel, reflectWorldDir, 128.0, 512,
                worldPos - 0.1 * NW,
                hitPosRel, hitVoxel, hitNormal
            );

            if(!vxHit){
                reflectColor = skyReflection(reflectWorldDir) * float(dot(reflectWorldDir, upWorldDir) > 0.01)
                             * remapSaturate(lightmap, 0.0, 0.01, 0.0, 1.0);
            } else{
                vec3 shadowPos = getShadowPos(vec4(hitPosRel, 1.0)).xyz;
                float hitShadow = textureLod(shadowtex0, shadowPos, 0).r;

                vec4 hitCol = texelFetch(customimg0, hitVoxel, 0);
                vec3 hitAlbedo  = pow(hitCol.rgb, vec3(2.2));
                vec3 hitDiffuse = hitAlbedo / PI;

                float hitLoN = saturate(dot(hitNormal, lightWorldDir));
                reflectColor += DIRECT_LUMINANCE * sunColor * hitShadow * hitDiffuse * hitLoN;

                float hitLMC_y = texelFetch(customimg4, hitVoxel, 0).x;
                hitLMC_y = saturate(pow(hitLMC_y, 2.2 + SKY_LIGHT_FALLOFF) * lightmap);
                reflectColor += hitLMC_y * mix(sunColor, skyColor, mix(0.5, 1.0, hitLMC_y)) * 
                                SKY_LIGHT_BRIGHTNESS * 0.5 * hitDiffuse;
                reflectColor += hitCol.a * hitDiffuse;
            }
        #else
            if(isEyeInWater == 0){
                reflectColor = skyReflection(reflectWorldDir);
                reflectColor = reflectColor * lightmap;
            }
        #endif
        
    }

    return max(reflectColor, BLACK);
}

#if !defined GBF && defined FSH
vec3 temporal_Reflection(vec3 color_c, int samples, float r){
    vec2 uv = texcoord * 2.0 - 1.0;
    float z = texture(depthtex1, uv).r;
    vec4 screenPos = vec4(uv, z, 1.0);
    vec4 viewPos = screenPosToViewPos(screenPos);
    vec4 worldPos = viewPosToWorldPos(viewPos);
    vec3 prePos = getPrePos(worldPos);

    bool isHand = texture(depthtex2, uv).r > z;
    if(isHand) color_c = vec3(0.0);

    prePos.xy = (prePos.xy * 0.5 + 0.5) * viewSize - vec2(0.5);
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;

    vec4 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy - 0.5 * viewSize), 0);
    vec3 normal_c = unpackNormal(cur.r);
    float depth_c = linearizeDepth(prePos.z);
    float fDepth = fwidth(depth_c);

    float blur = 0.0;
    #ifndef PBR_REFLECTION_BLUR
        blur = 1.0;
    #endif

    float cameraDisplacementWeight = clamp(1.2 - length(cameraPosition - previousCameraPosition) * 20.0 / depth_c, 0.5, 1.0);
    float rWeight = remapSaturate(r, 0.0, 0.1, 0.9, 1.0);
    float sampleWeight = exp2(-float(samples - 1) * 0.05);
    float commonWeight = cameraDisplacementWeight * rWeight * sampleWeight;

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen((curUV * invViewSize) * 2.0 - 1.0)) continue;

        vec4 pre = texelFetch(colortex6, ivec2(curUV), 0);

        float depth_p = linearizeDepth(pre.g);   

        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));

        weight *= saturate(mix(1.0, dot(unpackNormal(pre.r), normal_c), 1.0));
        weight *= exp(-abs(depth_p - depth_c) / (1.0 + fDepth * 2.0 + depth_p / 2.0));

        c_s += texelFetch(colortex3, ivec2(curUV), 0) * weight;
        w_s += weight;
    }
    }

    color_c = mix(color_c.rgb, c_s.rgb, w_s * 0.95 * commonWeight);
    return color_c;
}

vec3 JointBilateralFiltering_Refl_Horizontal(){
    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec2 curGD = texelFetch(colortex6, ivec2(pix - 0.5 * viewSize), 0).rg;
    vec3  normal0 = unpackNormal(curGD.r);
    float z0      = linearizeDepth(curGD.g);

    const float radius  = 4.0;
    const float quality = 6.0;
    const float sigma   = radius * 0.5;
    const float invSigma2 = 1.0 / (2.0 * sigma * sigma);
    float d = 2.0 * radius / quality;

    vec3 wSum = vec3(0.0);
    vec3  cSum = vec3(0.0);

    float fDepth = fwidth(z0);

    for (float dx = -radius; dx <= radius + 0.001; dx += d) {
        ivec2 offset = ivec2(dx, 0.0);
        ivec2 p = pix + offset;

        if (outScreen((vec2(p) * invViewSize) * 2.0 - 1.0)) continue;

        vec2 gd = texelFetch(colortex6, ivec2(p - 0.5 * viewSize), 0).rg;
        vec3  n  = unpackNormal(gd.r);
        float z  = linearizeDepth(gd.g);

        float wN = saturate(mix(1.0, dot(n, normal0), 25.0));
        float wZ = exp(-abs(z - z0) / (1.0 + fDepth * 2.0 + z0 / 2.0));
        float wS = exp(-dx * dx * invSigma2);
        vec3 w  = vec3(wN * wZ * wS);

        vec3 col = texelFetch(colortex3, p, 0).rgb;
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec3(1e-4), wSum);
}

vec3 JointBilateralFiltering_Refl_Vertical(){
    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec2 curGD = texelFetch(colortex6, ivec2(pix - 0.5 * viewSize), 0).rg;
    vec3  normal0 = unpackNormal(curGD.r);
    float z0      = linearizeDepth(curGD.g);

    const float radius  = 4.0;
    const float quality = 6.0;
    const float sigma   = radius * 0.5;
    const float invSigma2 = 1.0 / (2.0 * sigma * sigma);
    float d = 2.0 * radius / quality;

    vec3 wSum = vec3(0.0);
    vec3  cSum = vec3(0.0);
    float fDepth = fwidth(z0);
    
    for (float dy = -radius; dy <= radius + 0.001; dy += d) {
        ivec2 offset = ivec2(0.0, dy);
        ivec2 p = pix + offset;

        if (outScreen((vec2(p) * invViewSize) * 2.0 - 1.0)) continue;

        vec2 gd = texelFetch(colortex6, ivec2(p - 0.5 * viewSize), 0).rg;
        vec3  n  = unpackNormal(gd.r);
        float z  = linearizeDepth(gd.g);

        float wN = saturate(mix(1.0, dot(n, normal0), 25.0));
        float wZ = exp(-abs(z - z0) / (1.0 + fDepth * 2.0 + z0 / 2.0));
        float wS = exp(-dy * dy * invSigma2);
        vec3 w  = vec3(wN * wZ * wS);

        vec3 col = texelFetch(colortex1, p, 0).rgb;
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec3(1e-4), wSum);
}

vec3 getReflectColor(float depth, vec3 normal){
    ivec2 uv = ivec2(gl_FragCoord.xy * 0.5 + 0.5 * viewSize);
    float w_max = 0.0;
    ivec2 uv_closet = uv;

    float z = linearizeDepth(depth);

    vec4 centerData = texelFetch(colortex6, ivec2(uv - 0.5 * viewSize), 0);
    float centerWeight = max(0.0f, mix(1.0, dot(unpackNormal(centerData.r), normal), 2.0));
    float centerZ = linearizeDepth(centerData.g);
    centerWeight *= saturate(1.0 - abs(centerZ - z) * 2.0);
    w_max = centerWeight;

    if(centerWeight > 0.9){
        #ifdef PBR_REFLECTION_BLUR
            return texelFetch(colortex1, ivec2(uv), 0).rgb;
        #else
            return texelFetch(colortex3, ivec2(uv), 0).rgb;
        #endif
    }

    for(int i = 0; i < 5; i++){
        float weight = 1.0;
        ivec2 offset = ivec2(offsetUV5[i]);
        ivec2 curUV = uv + offset;
        if(outScreen(curUV * invViewSize * 2.0 - 1.0 + vec2(-1.0) * invViewSize)) weight = 0.0;

        vec4 curData = texelFetch(colortex6, ivec2(curUV - 0.5 * viewSize), 0);
        weight *= max(0.0f, mix(1.0, dot(unpackNormal(curData.r), normal), 2.0));

        float curZ = linearizeDepth(curData.g);
        weight *= saturate(1.0 - abs(curZ - z) * 2.0);

        if(weight > w_max){
            w_max = weight;
            uv_closet = curUV;
        }
    }

    #ifdef PBR_REFLECTION_BLUR
        return texelFetch(colortex1, ivec2(uv_closet), 0).rgb;
    #else
        return texelFetch(colortex3, ivec2(uv_closet), 0).rgb;
    #endif
}

#endif
#endif
