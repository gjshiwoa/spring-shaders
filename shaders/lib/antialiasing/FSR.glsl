// https://zhuanlan.zhihu.com/p/637639295

void fetchNeighbors(sampler2D tex, ivec2 coord,
                    out vec3 b, out vec3 d, out vec3 e,
                    out vec3 f, out vec3 h) {
    b = texelFetch(tex, coord + ivec2( 0,  1), 0).rgb;
    d = texelFetch(tex, coord + ivec2(-1,  0), 0).rgb;
    e = texelFetch(tex, coord                , 0).rgb;
    f = texelFetch(tex, coord + ivec2( 1,  0), 0).rgb;
    h = texelFetch(tex, coord + ivec2( 0, -1), 0).rgb;
}

float luma(vec3 c) {
    return c.b * 0.5 + (c.r * 0.5 + c.g);
}

float computeLobeChannel(float b, float d, float e, float f, float h) {
    const vec2 peakC = vec2(1.0, -4.0);
    float mn4 = min(min3(b, d, f), h);
    float mx4 = max(max3(b, d, f), h);
    float hitMin = -min(mn4, e) / (4.0 * mx4);
    float hitMax = (peakC.x - max(mx4, e)) / (4.0 * mn4 + peakC.y);
    return max(hitMin, hitMax);
}

vec3 fsrRCAS(sampler2D inputTexture, ivec2 fragCoord) {
    float sharpnessStops  = (1.0 - saturate(RCAS_SHARPNESS)) * 2.5;
    float sharpnessLinear = exp2(-sharpnessStops);

    vec3 b, d, e, f, h;
    fetchNeighbors(inputTexture, fragCoord, b, d, e, f, h);

    #ifdef RCAS_ENABLE_NOISE_SUPPRESSION
        float bL = luma(b), dL = luma(d), eL = luma(e), fL = luma(f), hL = luma(h);
        float maxL = max3(max(bL, dL), max(eL, fL), hL);
        float minL = min3(min(bL, dL), min(eL, fL), hL);
        float avgNei = 0.25 * (bL + dL + fL + hL);
        float nz = -0.5 * saturate(abs(avgNei - eL) / max(maxL - minL, 1e-4)) + 1.0;
    #else
        float nz = 1.0;
    #endif

    float lR = computeLobeChannel(b.r, d.r, e.r, f.r, h.r);
    float lG = computeLobeChannel(b.g, d.g, e.g, f.g, h.g);
    float lB = computeLobeChannel(b.b, d.b, e.b, f.b, h.b);

    float lobe = max(-RCAS_LIMIT, min(max3(lR, lG, lB), 0.0)) * sharpnessLinear * nz;

    float rcpL = 1.0 / (4.0 * lobe + 1.0);
    return (lobe * (b + d + f + h) + e) * rcpL;
}