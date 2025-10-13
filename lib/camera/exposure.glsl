#ifdef CALCULATE_AVERAGE_LUMINANCE

float calculateAverageLuminance() {
    int samplerLod = int(log2(min(viewWidth, viewHeight)));
    return max(getLuminance(colortex0, vec2(0.5, 0.5), samplerLod), 0.001);
}

float calculateAverageLuminance1() {
    int samplerLod = int(log2(min(viewWidth, viewHeight))) - 2;
    vec3 c_s = vec3(0.0);
    for(int i = 0; i < 16; i++){
        vec2 offsetUV = offsetUV16[i] * 0.5 + 0.5;
        offsetUV.x = remapSaturate(offsetUV.x, 0.0, 1.0, uvTable[8].x, uvTable[8].z);
        offsetUV.y = remapSaturate(offsetUV.y, 0.0, 1.0, uvTable[8].y, uvTable[8].w);
        c_s += textureLod(colortex1, offsetUV, samplerLod).rgb;
    }
    c_s /= 16.0;
    return max(getLuminance(c_s), 0.001);
}

#endif

void avgExposure(inout vec3 color) {
    float avgLuminance = texelFetch(colortex2, averageLumUV, 0).a;
    float t = TARGET_BRIGHTNESS;
    float d = EXPOSURE_DELTA;
    float s = LIGHT_SENSITIVITY;
    float exposure = pow(mix(1.0, t / (avgLuminance + 0.015), d), s);
    color *= exposure;
}