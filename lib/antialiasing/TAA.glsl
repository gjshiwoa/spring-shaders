// 李知青：TAA原理及OpenGL实现
// https://zhuanlan.zhihu.com/p/479530563

// 月光下的旅行: Vulkan TAA实现与细节
// https://qiutang98.github.io/post/%E5%9B%BE%E5%BD%A2%E7%A1%AC%E4%BB%B6api/vulkan-taa%E5%AE%9E%E7%8E%B0%E4%B8%8E%E7%BB%86%E8%8A%82

vec3 clipAABB(vec3 nowColor, vec3 preColor){
    vec3 m1 = vec3(0), m2 = vec3(0);
    for(int i = -1; i <= 1; i++){
    for(int j = -1; j <= 1; j++){
        vec2 newUV = texcoord.st + invViewSize * vec2(i, j);
        vec3 C = RGB2YCoCgR(ToneMap(textureLod(colortex0, newUV, 0.0).rgb));
        m1 += C;
        m2 += C * C;
    }
    }

    const float TAA_variance_clip_gamma = TAA_VARIANCE_CLIP_GAMMA;
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

float getBlendFactor(vec2 velocity, vec3 preColor, vec3 nowColor){
    float blendFactor = 1.0;
    float lDepth = getLinearDepth(texcoord);
    float lVelocity = length(velocity * viewSize);
    float LDmLV = lDepth * lVelocity;
    blendFactor *= LDmLV * 0.5 + saturate(0.5 / LDmLV + 0.000001) * 0.1666;

    float lumPreColor = getLuminance(preColor);
    float lumNowColor = getLuminance(nowColor);
    float lumDiff = 1.0 - abs(lumNowColor - lumPreColor) / (max(lumNowColor, lumPreColor) + 0.3);
    blendFactor *= lumDiff;

    return clamp(blendFactor, 0.01, 0.10);
}

void TAA(inout vec3 nowColor){
    vec2 velocity = getVelocity();
    vec2 offsetUV = saturate(texcoord - velocity);
    // vec3 preColor = max(BLACK, texture(colortex2, offsetUV).rgb);
    // vec3 preColor = max(BLACK, catmullRom(colortex2, offsetUV).rgb);
    vec3 preColor = max(BLACK, catmullRom5(colortex2, offsetUV, SHARPENING_FACTOR).rgb);

    nowColor = RGB2YCoCgR(ToneMap(nowColor));
    preColor = RGB2YCoCgR(ToneMap(preColor));

    preColor = clipAABB(nowColor, preColor);

    preColor = UnToneMap(YCoCgR2RGB(preColor));
    nowColor = UnToneMap(YCoCgR2RGB(nowColor));

    #ifdef TAA_CUSTOM_BLEND_FACTOR
        float blendFactor = TAA_BLEND_FACTOR;
    #else
        float blendFactor = getBlendFactor(velocity, preColor, nowColor);
    #endif

    nowColor = mix(preColor, nowColor, blendFactor);
}