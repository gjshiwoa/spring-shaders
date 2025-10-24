vec4 EqualWeightSeparableBlur(
    sampler2D colorTex,
    sampler2D depthTex,
    vec2 uv,
    vec2 dir,
    float radius,
    float quality,
    bool useNormal,
    bool useDepth,
    float normalThreshold,
    float depthThreshold)
{
    int steps = int(ceil(max(1.0, quality)));
    float stepPx = 2.0 * radius / float(steps);

    vec4 cSum = vec4(0.0);
    float wSum = 0.0;

    vec3 centerN = vec3(0.0, 0.0, 1.0);
    float centerZ = 0.0;
    if (useNormal) {
        centerN = normalize(getNormal(uv));
    }
    if (useDepth) {
        centerZ = linearizeDepth(texture(depthTex, uv).r);
    }

    for (int i = 0; i <= steps; ++i) {
        float offsetPx = -radius + float(i) * stepPx;
        vec2 sampleUV = uv + dir * (offsetPx * invViewSize);

        if (outScreen(sampleUV)) continue;

        float w = 1.0;
        if (useNormal) {
            vec3 n = normalize(getNormal(sampleUV));
            float wN = saturate(dot(n, centerN) * normalThreshold); 
            w *= wN;
        }
        if (useDepth) {
            float z = linearizeDepth(texture(depthTex, sampleUV).r);
            float wZ = saturate(1.2 - abs(z - centerZ) * depthThreshold); 
            w *= wZ;
        }

        if (w <= 1e-5) continue;

        vec4 col = texture(colorTex, sampleUV);
        cSum += col * w;
        wSum += w;
    }

    if (wSum <= 1e-5) {
        return texture(colorTex, uv);
    } else {
        return cSum / wSum;
    }
}

vec4 EqualWeightBlur_Horizontal(
    sampler2D colorTex, sampler2D depthTex,
    vec2 uv, float radius, float quality,
    bool useNormal, float normalThreshold, 
    bool useDepth, float depthThreshold)
{
    return EqualWeightSeparableBlur(colorTex, depthTex, uv, vec2(1.0, 0.0),
                                    radius, quality, useNormal, useDepth, normalThreshold, depthThreshold);
}

vec4 EqualWeightBlur_Vertical(
    sampler2D colorTex, sampler2D depthTex,
    vec2 uv, float radius, float quality,
    bool useNormal, float normalThreshold, 
    bool useDepth, float depthThreshold)
{
    return EqualWeightSeparableBlur(colorTex, depthTex, uv, vec2(0.0, 1.0),
                                    radius, quality, useNormal, useDepth, normalThreshold, depthThreshold);
}

vec4 JointBilateralFiltering_hrr_Horizontal(){
    return texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
    
    ivec2 pix = ivec2(gl_FragCoord.xy);
    float z0;

    #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
        ivec2 hrrUV_c = ivec2(pix * 2.0 - vec2(0.0, 1.0) * viewSize);
        float depthHrr = texelFetch(depthtex0, hrrUV_c, 0).r;
        float dhDepth = texelFetch(dhDepthTex0, hrrUV_c, 0).r;
        float dhTerrainHrr = depthHrr == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
        if(dhTerrainHrr > 0.5){
            z0 = screenPosToViewPos(vec4(hrrUV_c * invViewSize, dhDepth, 1.0)).z;
        }else{
            z0 = screenPosToViewPos(vec4(hrrUV_c * invViewSize, depthHrr, 1.0)).z;
        }
    #else
        vec4 curGD = texelFetch(colortex6, pix, 0);
        z0 = linearizeDepth(curGD.g);
    #endif

    const float radius  = 6.0;
    const float quality = 6.0;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);

    for (float dx = -radius; dx <= radius + 0.001; dx += d) {
        ivec2 offset = ivec2(dx, 0.0);
        ivec2 p = pix + offset;

        if (outScreen((p * invViewSize) * 2.0 - vec2(0.0, 1.0))) continue;

        vec4 w = vec4(1.0);
        if(isEyeInWater == 0.0){
            float z;
            #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
                ivec2 uv = ivec2(p * 2.0 - vec2(0.0, 1.0) * viewSize);
                float depthHrr = texelFetch(depthtex0, uv, 0).r;
                float dhDepth = texelFetch(dhDepthTex0, uv, 0).r;
                float dhTerrainHrr = depthHrr == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
                if(dhTerrainHrr > 0.5){
                    z = screenPosToViewPos(vec4(uv * invViewSize, dhDepth, 1.0)).z;
                }else{
                    z = screenPosToViewPos(vec4(uv * invViewSize, depthHrr, 1.0)).z;
                }
            #else
                vec4 gd = texelFetch(colortex6, p, 0);
                z = linearizeDepth(gd.g);
            #endif
            
            float wZ = saturate(1.2 - abs(z - z0) * 1.0); 
            w  = vec4(wZ);
        }
        vec4 col = texelFetch(colortex3, p, 0);
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec4(1e-4), wSum);
}

vec4 JointBilateralFiltering_hrr_Vertical(){
    return texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

    ivec2 pix = ivec2(gl_FragCoord.xy);
    float z0;

    #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
        ivec2 hrrUV_c = ivec2(pix * 2.0 - vec2(0.0, 1.0) * viewSize);
        float depthHrr = texelFetch(depthtex0, hrrUV_c, 0).r;
        float dhDepth = texelFetch(dhDepthTex0, hrrUV_c, 0).r;
        float dhTerrainHrr = depthHrr == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
        if(dhTerrainHrr > 0.5){
            z0 = screenPosToViewPos(vec4(hrrUV_c * invViewSize, dhDepth, 1.0)).z;
        }else{
            z0 = screenPosToViewPos(vec4(hrrUV_c * invViewSize, depthHrr, 1.0)).z;
        }
    #else
        vec4 curGD = texelFetch(colortex6, pix, 0);
        z0 = linearizeDepth(curGD.g);
    #endif

    const float radius  = 6.0;
    const float quality = 6.0;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);

    for (float dy = -radius; dy <= radius + 0.001; dy += d) {
        ivec2 offset = ivec2(0.0, dy);
        ivec2 p = pix + offset;

        if (outScreen((p * invViewSize) * 2.0 - vec2(0.0, 1.0))) continue;

        vec4 w = vec4(1.0);
        if(isEyeInWater == 0.0){
            float z;
            #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
                ivec2 uv = ivec2(p * 2.0 - vec2(0.0, 1.0) * viewSize);
                float depthHrr = texelFetch(depthtex0, uv, 0).r;
                float dhDepth = texelFetch(dhDepthTex0, uv, 0).r;
                float dhTerrainHrr = depthHrr == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
                if(dhTerrainHrr > 0.5){
                    z = screenPosToViewPos(vec4(uv * invViewSize, dhDepth, 1.0)).z;
                }else{
                    z = screenPosToViewPos(vec4(uv * invViewSize, depthHrr, 1.0)).z;
                }
            #else
                vec4 gd = texelFetch(colortex6, p, 0);
                z = linearizeDepth(gd.g);
            #endif

            float wZ = saturate(1.2 - abs(z - z0) * 1.0);
            w  = vec4(wZ);
        }

        vec4 col = texelFetch(colortex1, p, 0);
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec4(1e-4), wSum);
}