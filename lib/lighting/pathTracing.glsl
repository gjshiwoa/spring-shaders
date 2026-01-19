#ifdef FSH
#include "/lib/lighting/voxelization.glsl"

void buildTBN(in vec3 n, out vec3 t, out vec3 b){
    vec3 up = (abs(n.z) < 0.999) ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    t = normalize(cross(up, n));
    b = cross(n, t);
}

vec3 sampleCosineHemisphere(vec2 u){
    float r   = sqrt(u.x);
    float phi = 2.0 * PI * u.y;

    float x = r * cos(phi);
    float y = r * sin(phi);
    float z = sqrt(max(0.0, 1.0 - u.x)); 

    return vec3(x, y, z);
}

float pdfCosineHemisphere(float cosTheta){
    return cosTheta / PI; 
}
#ifdef COLORED_LIGHT
#endif
vec3 coloredLight(vec3 worldPos, vec3 normalV, vec3 normalW){
    vec3 tangent, bitangent;
    buildTBN(normalV, tangent, bitangent);
    mat3 TBN = mat3(tangent, bitangent, normalV);

    vec3 color = vec3(0.0);
    #if PATH_TRACING_QUALITY == 0
        const int DIR_SAMPLES = 1;
    #elif PATH_TRACING_QUALITY == 1
        const int DIR_SAMPLES = 2;
    #elif PATH_TRACING_QUALITY == 2
        const int DIR_SAMPLES = 4;
    #elif PATH_TRACING_QUALITY == 3
        const int DIR_SAMPLES = 12;
    #endif

    for(int i = 0; i < DIR_SAMPLES; ++i){
        vec2 u = rand2_3(texcoord + sin(frameTimeCounter) + float(i) * 17.0).xy;
        vec3 localDir = sampleCosineHemisphere(u);
        vec3 refViewDir = normalize(TBN * localDir);
        vec3 refWorldDir = normalize(viewPosToWorldPos(vec4(refViewDir, 0.0)).xyz);

        float cosTheta = saturate(dot(normalV, refViewDir));
        float pdf = pdfCosineHemisphere(cosTheta);
        pdf = max(pdf, 0.01);

        float noise = temporalBayer64(gl_FragCoord.xy);
        float stepSize = 1.5;
        vec3 stepVec = refWorldDir * stepSize;
        ivec3 oriVp = relWorldToVoxelCoord(worldPos + normalW * 0.05);
        
        vec3 rayOrigin = worldPos + stepVec * noise + normalW * 0.05;
        #ifndef NETHER
            const int N_SAMPLES = 12;
        #else
            const int N_SAMPLES = 20;
        #endif

        vec3 Li = vec3(0.0);
        for(int j = 0; j < N_SAMPLES; ++j){
            vec3 wp = rayOrigin + stepVec * float(j);
            ivec3 vp = relWorldToVoxelCoord(wp);
            vec4 sampleCol = texelFetch(customimg0, vp.xyz, 0);
            if(sampleCol.a < 0.96){
                Li = toLinearR(sampleCol.rgb * sampleCol.a) * 1.0;
                break;
            }
        }
        color += Li * (cosTheta / pdf);
    }

    return color / float(DIR_SAMPLES);
}

vec2 SSRT_PT(vec3 viewPos, vec3 reflectViewDir, vec3 normalTex, out vec3 outMissPos){
    float curStep = REFLECTION_STEP_SIZE;

    vec3 startPos = viewPos;
    float worldDis = length(viewPos);
    #ifdef GBF
        startPos += normalTex * 0.2;
    #else
        startPos += normalTex * clamp(worldDis / 60.0, 0.01, 0.2);
    #endif

    float jitter = temporalBayer64(gl_FragCoord.xy);

    float cumUnjittered = 0.0;
    vec3 testScreenPos = viewPosToScreenPos(vec4(startPos, 1.0)).xyz;
    vec3 preTestPos = startPos;
    bool isHit = false;

    outMissPos = vec3(0.0);

    vec3 curTestPos = startPos;

    for (int i = 0; i < int(REFLECTION_SAMPLES); ++i){
        cumUnjittered += curStep;
        float adjustedDist = cumUnjittered - jitter * curStep;
        curTestPos = startPos + reflectViewDir * adjustedDist;
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

        if (testScreenPos.z > closest){
            isHit = true;
            vec3 ds = curTestPos - preTestPos;
            vec3 probePos = curTestPos;
            float sig = -1.0;
            float closestB = 1.0;
            for (int j = 1; j <= 5; ++j){
                float n = pow(0.5, float(j));
                probePos = probePos + sig * n * ds;
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

            vec3 newTestPos = screenPosToViewPos(vec4(ivalueTestScreenPos, 1.0)).xyz;
            float tp_dist = distance(curTestPos, newTestPos);
            float ds_len = length(ds);
            float cosA = dot(reflectViewDir, normalize(normalTex));
            if (tp_dist < ds_len * saturate(sqrt(1.0 - cosA * cosA))){
                return testScreenPos.st;
            }
            outMissPos = preTestPos;
            break;
        }

        preTestPos = curTestPos;
        curStep *= REFLECTION_STEP_GROWTH_BASE;
    }

    bool depthCondition = true;
    #if !defined END && !defined NETHER
        #ifdef DISTANT_HORIZONS
            depthCondition = texture(dhDepthTex0, testScreenPos.xy).r < 1.0 || texture(depthtex1, testScreenPos.xy).r < 1.0;
        #else
            depthCondition = texture(depthtex1, testScreenPos.xy).r < 1.0;
        #endif
    #endif

    if (!isHit){
        if(depthCondition) return vec2(testScreenPos.xy);
        else{ 
            outMissPos = curTestPos;
            return vec2(-1.0);
        }
    }

    return vec2(-1.0);
}




bool rayAABB(vec3 ro, vec3 rd, vec3 bmin, vec3 bmax, out float tEnter, out float tExit) {
    const float INF = 1e30;
    const float EPS_RAY = 1e-8;

    tEnter = -INF;
    tExit  =  INF;

    // X
    if (abs(rd.x) < EPS_RAY) {
        if (ro.x < bmin.x || ro.x > bmax.x) return false;
    } else {
        float tx0 = (bmin.x - ro.x) / rd.x;
        float tx1 = (bmax.x - ro.x) / rd.x;
        float t0 = min(tx0, tx1);
        float t1 = max(tx0, tx1);
        tEnter = max(tEnter, t0);
        tExit  = min(tExit,  t1);
        if (tEnter > tExit) return false;
    }

    // Y
    if (abs(rd.y) < EPS_RAY) {
        if (ro.y < bmin.y || ro.y > bmax.y) return false;
    } else {
        float ty0 = (bmin.y - ro.y) / rd.y;
        float ty1 = (bmax.y - ro.y) / rd.y;
        float t0 = min(ty0, ty1);
        float t1 = max(ty0, ty1);
        tEnter = max(tEnter, t0);
        tExit  = min(tExit,  t1);
        if (tEnter > tExit) return false;
    }

    // Z
    if (abs(rd.z) < EPS_RAY) {
        if (ro.z < bmin.z || ro.z > bmax.z) return false;
    } else {
        float tz0 = (bmin.z - ro.z) / rd.z;
        float tz1 = (bmax.z - ro.z) / rd.z;
        float t0 = min(tz0, tz1);
        float t1 = max(tz0, tz1);
        tEnter = max(tEnter, t0);
        tExit  = min(tExit,  t1);
        if (tEnter > tExit) return false;
    }

    return true;
}

bool voxelSolid(ivec3 v) {
    if (!voxelInBounds(v)) return false;
    float a = texelFetch(customimg0, v, 0).a;
    return a < 0.96;
}

uint voxelManhattanDF(ivec3 v) {
    if (!voxelInBounds(v)) return 0u;
    return texelFetch(customimg3, v, 0).r;
}

bool voxelDDA_Raycast(
    vec3 roRel,
    vec3 rdWorld,
    float maxDist,
    int maxSteps,
    vec3 initialPointRel,
    out vec3 hitPosRel,
    out ivec3 hitVoxel,
    out vec3 hitNormal
){
    if (length(rdWorld) > shadowDistance) return false;

    const float SURF_BIAS = 0.1;
    const float EPS_FLOOR = 1e-6;
    const float INF       = 1e30;
    const float EPS_RAY   = 1e-8;

    // DF 跳步相关参数
    const float DF_L1_VOXEL_RADIUS = 1.5;   // 实体体素中心到角点的 L1 半径 = 0.5+0.5+0.5
    const float SKIP_EPS_T         = 1e-4;  // 避免极小跳步导致原地抖动

    hitPosRel = vec3(0.0);
    hitVoxel  = ivec3(0);
    hitNormal = vec3(0.0);

    vec3 rd = rdWorld;

    vec3 camFract01 = getCameraFract01();
    vec3 roV = roRel + camFract01 + vec3(VOXEL_HALF); // voxel-space origin
    vec3 rdV = rd;                                    // voxel-space direction

    ivec3 initialVoxel = ivec3(floor(initialPointRel + camFract01 + vec3(VOXEL_HALF)));

    // 与体素世界 AABB 相交，裁剪射线有效段
    float tEnter, tExit;
    vec3 boxMin = vec3(0.0);
    vec3 boxMax = vec3(VOXEL_DIM);

    if (!rayAABB(roV, rdV, boxMin, boxMax, tEnter, tExit)) return false;

    float t    = max(tEnter, 0.0);
    float tEnd = min(tExit, maxDist);
    if (t > tEnd) return false;

    // 初始化当前位置
    float tBias = EPS_FLOOR; // 沿射线方向的微小偏移，避免卡在边界
    vec3 pV = roV + rdV * t + rdV * tBias;

    ivec3 v = ivec3(floor(pV));
    vec3 vf = floor(pV);
    vec3 frac = pV - vf;

    ivec3 step = ivec3(sign(rdV));

    vec3 tDelta;
    tDelta.x = (abs(rdV.x) < EPS_RAY) ? INF : abs(1.0 / rdV.x);
    tDelta.y = (abs(rdV.y) < EPS_RAY) ? INF : abs(1.0 / rdV.y);
    tDelta.z = (abs(rdV.z) < EPS_RAY) ? INF : abs(1.0 / rdV.z);

    // 计算到下一个体素边界的 t（local），再转为 global
    vec3 tMaxLocal;
    tMaxLocal.x = (step.x > 0) ? ((1.0 - frac.x) / rdV.x) : (frac.x / (-rdV.x));
    tMaxLocal.y = (step.y > 0) ? ((1.0 - frac.y) / rdV.y) : (frac.y / (-rdV.y));
    tMaxLocal.z = (step.z > 0) ? ((1.0 - frac.z) / rdV.z) : (frac.z / (-rdV.z));

    if (abs(rdV.x) < EPS_RAY) tMaxLocal.x = INF;
    if (abs(rdV.y) < EPS_RAY) tMaxLocal.y = INF;
    if (abs(rdV.z) < EPS_RAY) tMaxLocal.z = INF;

    vec3 tMaxGlobal = t + tMaxLocal;

    // 用于 DF 跳步：|rd|_1 的倒数（L1 速度）
    float rdL1 = abs(rdV.x) + abs(rdV.y) + abs(rdV.z);
    float invRdL1 = 1.0 / max(rdL1, EPS_RAY);

    vec3 n = vec3(0.0);

    for (int i = 0; i < maxSteps; i++) {
        if (!voxelInBounds(v)) return false;
        if (t > tEnd) return false;

        if (voxelSolid(v)) {
            if (!all(equal(v, initialVoxel))) {
                hitVoxel  = v;
                hitNormal = n;

                vec3 hitP = roRel + rd * t;
                hitPosRel = hitP + hitNormal * SURF_BIAS;
                return true;
            }
        } else {
            // -------------------------------
            // 距离场加速：安全跳步（在空体素内）
            // -------------------------------
            float d = float(voxelManhattanDF(v));

            // d==0 通常表示实体内部（但我们 voxelSolid 已判空），或 DF 与占用不一致
            // d<=2 时收益不大，直接走普通 DDA
            if (d > 2.0) {
                // 当前体素中心（voxel-space）
                vec3 c = vec3(v) + vec3(0.5);

                // 当前点到该中心的 L1 偏移
                float offL1 = abs(pV.x - c.x) + abs(pV.y - c.y) + abs(pV.z - c.z);

                // 由 DF 保证为空的 L1 半径（扣掉实体体素的 L1 “体积半径” 1.5）
                float R = d - DF_L1_VOXEL_RADIUS;

                float remain = R - offL1;
                if (remain > 0.0) {
                    // 用三角不等式做保守推进：|p(t)-c|_1 <= offL1 + |rd|_1 * dt
                    float dtSkip = remain * invRdL1;

                    if (dtSkip > SKIP_EPS_T) {
                        t += dtSkip;
                        if (t > tEnd) return false;

                        // 跳步后重建 DDA 状态（保证正确）
                        pV = roV + rdV * t + rdV * tBias;
                        v  = ivec3(floor(pV));

                        vf   = floor(pV);
                        frac = pV - vf;

                        tMaxLocal.x = (step.x > 0) ? ((1.0 - frac.x) / rdV.x) : (frac.x / (-rdV.x));
                        tMaxLocal.y = (step.y > 0) ? ((1.0 - frac.y) / rdV.y) : (frac.y / (-rdV.y));
                        tMaxLocal.z = (step.z > 0) ? ((1.0 - frac.z) / rdV.z) : (frac.z / (-rdV.z));

                        if (abs(rdV.x) < EPS_RAY) tMaxLocal.x = INF;
                        if (abs(rdV.y) < EPS_RAY) tMaxLocal.y = INF;
                        if (abs(rdV.z) < EPS_RAY) tMaxLocal.z = INF;

                        tMaxGlobal = t + tMaxLocal;
                        n = vec3(0.0);
                        continue;
                    }
                }
            }
        }

        // -------------------------------
        // 普通 DDA 单步推进
        // -------------------------------
        float tx = tMaxGlobal.x;
        float ty = tMaxGlobal.y;
        float tz = tMaxGlobal.z;

        float tNext = min(tx, min(ty, tz));
        if (tNext > tEnd) return false;

        const float EPS_TIE = 1e-7;
        bvec3 m = lessThanEqual(vec3(tx, ty, tz), vec3(tNext + EPS_TIE));

        // 一次性设置 t，避免 tie 时多次写 t 造成混乱
        t = tNext;

        // 更新体素坐标与下一次边界 t
        if (m.x) { v.x += step.x; tMaxGlobal.x += tDelta.x; }
        if (m.y) { v.y += step.y; tMaxGlobal.y += tDelta.y; }
        if (m.z) { v.z += step.z; tMaxGlobal.z += tDelta.z; }

        // 法线优先级：x > y > z（保持你原先的 tie 处理风格）
        if (m.x)      n = vec3(-float(step.x), 0.0, 0.0);
        else if (m.y) n = vec3(0.0, -float(step.y), 0.0);
        else          n = vec3(0.0, 0.0, -float(step.z));

        // 更新当前点（给下一轮 DF 跳步用）
        pV = roV + rdV * t + rdV * tBias;
    }

    return false;
}





#include "/lib/common/octahedralMapping.glsl"
#ifndef GBF

vec3 pathTracing(vec3 viewPos, vec3 worldPos, vec3 normalV, vec3 normalW){
    vec3 NV = normalize(normalDecode(texelFetch(colortex9, ivec2(gl_FragCoord.xy * 2.0), 0).ba));
    vec3 NW = mat3(gbufferModelViewInverse) * NV;
    vec3 tangent, bitangent;
    buildTBN(normalV, tangent, bitangent);
    mat3 TBN = mat3(tangent, bitangent, normalV);

    vec3 color = vec3(0.0);
    #if PATH_TRACING_QUALITY == 0
        const int DIR_SAMPLES = 1;
    #elif PATH_TRACING_QUALITY == 1
        const int DIR_SAMPLES = 2;
    #elif PATH_TRACING_QUALITY == 2
        const int DIR_SAMPLES = 4;
    #elif PATH_TRACING_QUALITY == 3
        const int DIR_SAMPLES = 12;
    #endif

    for(int i = 0; i < DIR_SAMPLES; ++i){
        vec2 u = rand2_3(texcoord + sin(frameTimeCounter) + float(i) * 17.0).xy;
        vec3 localDir = sampleCosineHemisphere(u);
        vec3 refViewDir  = normalize(TBN * localDir);
        if(dot(refViewDir, NV) < 0.01 /*|| dot(normalV, NV) < 0.05*/) refViewDir = NV;
        vec3 refWorldDir = normalize(viewPosToWorldPos(vec4(refViewDir, 0.0)).xyz);

        float cosTheta = saturate(dot(normalV, refViewDir));
        float pdf = pdfCosineHemisphere(cosTheta);
        pdf = max(pdf, 0.01);

        vec3 Li = vec3(0.0);
        vec3 missPos = vec3(0.0);
        vec2 ssrHitPos = SSRT_PT(viewPos, refViewDir, NV, missPos);

        if(ssrHitPos.x + ssrHitPos.y > 0.0){
            vec3 hitCol = texture(colortex0, ssrHitPos).rgb;
            vec3 hitAlbedo  = pow(hitCol, vec3(2.2));
            vec3 hitDiffuse = hitAlbedo / PI;

            vec4 CT4 = texelFetch(colortex4, ivec2(ssrHitPos * viewSize), 0);
            vec4 CT5 = texelFetch(colortex5, ivec2(ssrHitPos * viewSize), 0);

            vec2 CT4R = unpack16To2x8(CT4.r);
            vec3 hitNormalV = normalize(normalDecode(CT5.rg));
            float hitLoN = saturate(dot(hitNormalV, normalize(lightViewDir)));
            float hitShadow = min(CT4R.x, CT4R.y);

            Li = DIRECT_LUMINANCE * sunColor * hitShadow * hitDiffuse * hitLoN;

            vec4 hitSpecular = unpack2x16To4x8(CT4.ba);
            float selfLit = hitSpecular.a < 254.1 / 255.0 ? hitSpecular.a : 0.0;
            float hitMCLM = CT5.b;
            Li += toLinearR(hitCol * max(selfLit, hitMCLM)) * 2.0;
        } else {
            vec3 roRel = viewPosToWorldPos(vec4(missPos, 1.0)).xyz;
            vec3 hitPosRel;
            ivec3 hitVoxel;
            vec3 hitNormal;
            bool vxHit = voxelDDA_Raycast(
                roRel, refWorldDir, 128.0, 512,
                #ifdef STRICT_LEAK_PREVENTION
                    vec3(-999.0),
                #else
                    worldPos - 0.05 * NW,
                #endif
                hitPosRel, hitVoxel, hitNormal
            );

            if(!vxHit){
                vec3 skyColor = texture(
                    colortex7,
                    clamp(directionToOctahedral(refWorldDir) * 0.5, 0.0, 0.5 - 1.0 / 512.0)
                ).rgb;

                vec4 CT5 = texelFetch(colortex5, ivec2(gl_FragCoord.xy * 2.0), 0);
                vec2 mcLightmap = CT5.ba;

                float xFade = remapSaturate(abs(worldPos.x), 100.0, 128.0, 1.0, 0.33 * mcLightmap.y);
                float zFade = remapSaturate(abs(worldPos.z), 100.0, 128.0, 1.0, 0.33 * mcLightmap.y);
                float yFade = remapSaturate(abs(worldPos.y),  40.0,  64.0, 1.0, 0.33 * mcLightmap.y);
                float fade = min3(xFade, zFade, yFade);

                float UoR = dot(refWorldDir, upWorldDir);
                float dFade = worldPos.y < -32.0 ? remapSaturate(UoR, -0.33, 0.0, 0.0, 1.0) : 1.0;

                Li = skyColor * max(fade * dFade, 0.0);
            } else {
                vec3 shadowPos = getShadowPos(vec4(hitPosRel, 1.0)).xyz;
                float hitShadow = texture(shadowtex0, shadowPos).r;
                hitShadow *= length(texture(shadowcolor1, shadowPos.xy).xyz * 2.0 - 1.0);

                vec3 hitAlbedo  = pow(texture(shadowcolor0, shadowPos.xy).rgb, vec3(2.2));
                vec3 hitDiffuse = hitAlbedo / PI;

                float hitLoN = saturate(dot(hitNormal, lightWorldDir));
                Li = DIRECT_LUMINANCE * sunColor * hitShadow * hitDiffuse * hitLoN;

                vec4 hitVoxelCol = texelFetch(customimg0, hitVoxel, 0);
                Li += toLinearR(hitVoxelCol.rgb * hitVoxelCol.a) * 1.0;
            }
        }
        color += Li * (cosTheta / pdf);
    }
    color /= float(DIR_SAMPLES);

    // color += coloredLight(worldPos, normalV, normalW);

    return color;
}



vec4 temporal_RT(vec4 color_c){
    vec2 uv = texcoord * 2;
    vec2 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).rg;
    float z = cur.g;
    vec4 viewPos = screenPosToViewPos(vec4(uv, z, 1.0));
    vec3 prePos = getPrePos(viewPosToWorldPos(viewPos));

    prePos.xy = prePos.xy * 0.5 * viewSize - 0.5;
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;
    
    vec3 normal_c = unpackNormal(cur.r);
    float depth_c = linearizeDepth(prePos.z);
    float fDepth = fwidth(depth_c);

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen(curUV * 2 * invViewSize)) continue;

        vec2 pre = texelFetch(colortex6, ivec2(curUV + 0.5 * viewSize), 0).rg;
        float depth_p = linearizeDepth(pre.g);   

        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));
        float depthWeight = exp(-abs(depth_p - depth_c) / (1.0 + fDepth * 2.0 + depth_p / 2.0));
        float normalWeight = saturate(dot(normal_c, unpackNormal(pre.r)));

        weight *= depthWeight;
        weight *= normalWeight;
        
        c_s += texelFetch(colortex10, ivec2(curUV), 0) * weight;
        w_s += weight;
    }
    }

    #if PATH_TRACING_QUALITY == 0
        float blend = 0.97;
    #elif PATH_TRACING_QUALITY == 1
        float blend = 0.97;
    #elif PATH_TRACING_QUALITY == 2
        float blend = 0.95;
    #elif PATH_TRACING_QUALITY == 3
        float blend = 0.95;
    #endif
    color_c = mix(color_c, c_s, w_s * blend);

    return color_c;
}


#if PATH_TRACING_QUALITY == 0
    const float PT_F_R = 32.0;
    const float PT_F_Q = 32.0;
#elif PATH_TRACING_QUALITY == 1
    const float PT_F_R = 32.0;
    const float PT_F_Q = 32.0;
#elif PATH_TRACING_QUALITY == 2
    const float PT_F_R = 16.0;
    const float PT_F_Q = 16.0;
#elif PATH_TRACING_QUALITY == 3
    const float PT_F_R = 12.0;
    const float PT_F_Q = 12.0;
#endif

vec4 JointBilateralFiltering_PT_Horizontal(){
    // return texelFetch(colortex10, ivec2(gl_FragCoord.xy), 0);
    
    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec2 curGD = texelFetch(colortex6, pix, 0).rg;
    vec3  normal0 = unpackNormal(curGD.r);
    float z0      = linearizeDepth(curGD.g);

    const float radius  = PT_F_R;
    const float quality = PT_F_Q;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);
    float fDepth = fwidth(z0);
    for (float dx = -radius; dx <= radius + 0.001; dx += d) {
        ivec2 offset = ivec2(dx, 0.0);
        ivec2 p = pix + offset;

        if (outScreen(vec2(p) * 2.0 * invViewSize)) continue;

        vec2 gd = texelFetch(colortex6, p, 0).rg;
        vec3  n  = unpackNormal(gd.r);
        float z  = linearizeDepth(gd.g);

        float wN = saturate(dot(n, normal0));             // 法线权重
        float wZ = saturate(1.2 - abs(z - z0) * 1.2 / (1.0 + fDepth * 0.1));      // 深度权重
        vec4 w  = vec4(wN * wZ);
        w.a = abs(dx) < 3.0 ? w.a : 0.0;

        vec4 col = texelFetch(colortex10, p, 0);
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec4(1e-4), wSum);
}

vec4 JointBilateralFiltering_PT_Vertical(){
    // return texelFetch(colortex11, ivec2(gl_FragCoord.xy), 0);

    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec2 curGD = texelFetch(colortex6, pix, 0).rg;
    vec3  normal0 = unpackNormal(curGD.r);
    float z0      = linearizeDepth(curGD.g);

    const float radius  = PT_F_R;
    const float quality = PT_F_Q;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);
    float fDepth = fwidth(z0);
    for (float dy = -radius; dy <= radius + 0.001; dy += d) {
        ivec2 offset = ivec2(0.0, dy);
        ivec2 p = pix + offset;

        if (outScreen(vec2(p) * 2.0 * invViewSize + vec2(1.0, 1.0) * invViewSize)) continue;

        vec2 gd = texelFetch(colortex6, p, 0).rg;
        vec3  n  = unpackNormal(gd.r);
        float z  = linearizeDepth(gd.g);

        float wN = saturate(dot(n, normal0));
        float wZ = saturate(1.2 - abs(z - z0) * 1.2 / (1.0 + fDepth * 0.1));
        vec4 w  = vec4(wN * wZ);
        w.a = abs(dy) < 3.0 ? w.a : 0.0;

        vec4 col = texelFetch(colortex11, p, 0);
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec4(1e-4), wSum);
}

vec4 getGI_PT(float depth, vec3 normal){
    // return catmullRom(colortex1, texcoord * 0.5);
    ivec2 uv = ivec2(gl_FragCoord.xy * 0.5);
    float w_max = 0.0;
    ivec2 uv_closet = uv;

    float z = linearizeDepth(depth);

    for(int i = 0; i < 5; i++){
        float weight = 1.0;
        ivec2 offset = ivec2(offsetUV5[i]);
        ivec2 curUV = uv + offset;
        if(outScreen(curUV * 2 * invViewSize)) continue;

        vec4 curData = texelFetch(colortex6, curUV, 0);
        weight *= max(0.0f, mix(1.0, dot(unpackNormal(curData.r), normal), 2.0));

        float curZ = linearizeDepth(curData.g);
        weight *= saturate(1.0 - abs(curZ - z) * 2.0);

        if(weight > w_max){
            w_max = weight;
            uv_closet = curUV;
        }
    }
    return texelFetch(colortex11, uv_closet, 0);
}
#endif

#endif