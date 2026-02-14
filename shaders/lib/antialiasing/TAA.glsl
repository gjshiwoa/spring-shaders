// 李知青：TAA原理及OpenGL实现
// https://zhuanlan.zhihu.com/p/479530563

// 月光下的旅行: Vulkan TAA实现与细节
// https://qiutang98.github.io/post/%E5%9B%BE%E5%BD%A2%E7%A1%AC%E4%BB%B6api/vulkan-taa%E5%AE%9E%E7%8E%B0%E4%B8%8E%E7%BB%86%E8%8A%82

float depth_confidence(float depth1, vec2 velocity){
    vec4 viewPos = screenPosToViewPos(vec4(texcoord, depth1, 1.0));
    vec4 worldPos = viewPosToWorldPos(viewPos);
    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    vec4 preWorldPos = worldPos + vec4(cameraOffset, 0.0);
	vec4 preViewPos = gbufferPreviousModelView * preWorldPos;
    vec4 prePos = gbufferPreviousProjection * preViewPos;
    prePos /= prePos.w;
    prePos.xyz = 0.5 * prePos.xyz + 0.5;
    if(outScreen(prePos.xyz)) return 0.0;

    float pDepth1 = texelFetch(colortex12, ivec2(prePos.xy * viewSize), 0).r;
    vec4 pScreenPos = vec4(prePos.xy, pDepth1, 1.0);
    vec4 pViewPos = gbufferPreviousProjectionInverse * vec4(pScreenPos.xyz * 2.0 - 1.0, pScreenPos.w);
    pViewPos /= pViewPos.w;

    float rel = abs(preViewPos.z - pViewPos.z) / (max(abs(preViewPos.z), abs(pViewPos.z)) + 0.0001);
    float lo = 0.0015;
    float hi = 0.01;
    float result = 1.0 - smoothstep(lo, hi, rel);

    float velLength = length(velocity * viewSize);
    result *= remapSaturate(velLength, 2.0, 5.0, 1.0, 0.0);

    return saturate(result);
}

float edgeFactorFromMinMax(float zMin, float zMax, float zCenter){
    zMax = linearizeDepth(zMax);
    zMin = linearizeDepth(zMin);
    zCenter = linearizeDepth(zCenter);

    float rangeRel = (zMax - zMin) / (zCenter + 0.001);

    float t0 = 0.002;
    float t1 = 0.01;

    return smoothstep(t0, t1, rangeRel);
}

vec3 clipAABB(vec3 nowColor, vec3 preColor, float depthConfidence){
    vec3 m1 = vec3(0), m2 = vec3(0);
    for(int i = -1; i <= 1; i++){
    for(int j = -1; j <= 1; j++){
        vec2 newUV = texcoord.st + invViewSize * vec2(i, j);
        vec3 C = RGB2YCoCgR(ToneMap(textureLod(colortex0, newUV, 0.0).rgb));
        m1 += C;
        m2 += C * C;
    }
    }

    float TAA_variance_clip_gamma = TAA_VARIANCE_CLIP_GAMMA;

    #ifdef TAA_DEPTH_CONFIDENCE
        TAA_variance_clip_gamma += mix(1.0, depthConfidence, 1.0) * TAA_DEPTH_CONFIDENCE_STRENGTH;
        TAA_variance_clip_gamma = max(TAA_variance_clip_gamma, 0.5);
    #endif

    #ifdef DEPTH_OF_FIELD
        float coc = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0).a;
        float radius = saturate(abs(coc) - DOF_FOCUS_TOLERANCE) * DOF_BOKEH_RADIUS;
        float zeroFac = radius < 0.5 ? 0.0 : 1.0;
        float radiusFac = remapSaturate(radius / DOF_BOKEH_RADIUS, 0.1, 0.5, 1.0, 0.5);
        TAA_variance_clip_gamma += 1.0 * radiusFac * zeroFac;
    #endif

    vec3 aabbMin = nowColor, aabbMax = nowColor;
    const int N = 9;
    vec3 mu = m1 / N;
    vec3 sigma = sqrt(abs(m2 / N - mu * mu));
    aabbMin = mu - TAA_variance_clip_gamma * sigma;
    aabbMax = mu + TAA_variance_clip_gamma * sigma;

    vec3 p_clip = 0.5 * (aabbMax + aabbMin);
    vec3 e_clip = 0.5 * (aabbMax - aabbMin);

    vec3 v_clip = preColor - p_clip;
    vec3 v_unit = v_clip.xyz / e_clip;
    vec3 a_unit = abs(v_unit);
    float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

    if (ma_unit > 1.0)
        return p_clip + v_clip / ma_unit;
    else
        return preColor;
}

float getBlendFactor(float depth_confidence, vec3 preColor, vec3 nowColor){
    float lumPre = getLuminance(preColor);
    float lumNow = getLuminance(nowColor);
    float lumDiff = abs(lumNow - lumPre) / (max(lumNow, lumPre) + 0.001);
    float fLum = smoothstep(0.01, 0.15, lumDiff);

    float fDepth = (1.0 - depth_confidence);

    float blendFactor = max(fDepth, fLum) * 0.05;
    return clamp(blendFactor, 0.02, 0.05);
}


void TAA(inout vec3 nowColor){
    vec4 nearFar = getClosestOffsetWithFarthest(texcoord.st, 1.0);
    vec2 velocity = texture(colortex9, nearFar.xy).xy;
    // if(nearFar.z < 0.7) velocity = vec2(0.0);
    vec2 offsetUV = texcoord - velocity;
    if(outScreen(offsetUV)){
        return;
    }

    // vec3 preColor = max(BLACK, texture(colortex2, offsetUV).rgb);
    // vec3 preColor = max(BLACK, catmullRom(colortex2, offsetUV).rgb);
    vec3 preColor = max(BLACK, catmullRom5(colortex2, offsetUV, SHARPENING_FACTOR).rgb);

    nowColor = RGB2YCoCgR(ToneMap(nowColor));
    preColor = RGB2YCoCgR(ToneMap(preColor));

    float depth1 = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    float depthConfidence = 0.0;
    #ifdef TAA_DEPTH_CONFIDENCE
        float edgeFactor = 0.0;
        // edgeFactor = edgeFactorFromMinMax(nearFar.z, nearFar.w, depth1);
        depthConfidence = depth_confidence(depth1, velocity) * (1.0 - edgeFactor);
    #endif
    preColor = clipAABB(nowColor, preColor, depthConfidence);

    preColor = UnToneMap(YCoCgR2RGB(preColor));
    nowColor = UnToneMap(YCoCgR2RGB(nowColor));

    #ifdef TAA_CUSTOM_BLEND_FACTOR
        float blendFactor = TAA_BLEND_FACTOR;
    #else
        float blendFactor = getBlendFactor(depthConfidence, preColor, nowColor);
    #endif

    nowColor = mix(preColor, nowColor, blendFactor);
}