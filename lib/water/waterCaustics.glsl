float laplacianAt(vec2 pos, const int quality, float sampleRadius) {
    float c = getWaveHeight(pos, quality);
    float rx = getWaveHeight(pos + vec2(sampleRadius, 0.0), quality);
    float lx = getWaveHeight(pos + vec2(-sampleRadius, 0.0), quality);
    float uz = getWaveHeight(pos + vec2(0.0, sampleRadius), quality);
    float dz = getWaveHeight(pos + vec2(0.0, -sampleRadius), quality);

    float hxx = (rx - 2.0*c + lx) / (sampleRadius * sampleRadius);
    float hzz = (uz - 2.0*c + dz) / (sampleRadius * sampleRadius);
    return hxx + hzz;
}

float getCausticsIntensityApprox(
    vec2 pos,
    const int quality,
    float sampleRadius,
    float focusScale,
    float exposure
) {
    float lap = laplacianAt(pos, quality, sampleRadius);
    float focus = max(0.0, 1.0 - lap * focusScale);
    float intensity = 1.0 - exp(-focus * exposure);
    return clamp(intensity, 0.0, 1.0);
}

vec2 gradientAt(vec2 pos, const int quality, float sampleRadius) {
    float rx = getWaveHeight(pos + vec2(sampleRadius, 0.0), quality);
    float lx = getWaveHeight(pos + vec2(-sampleRadius, 0.0), quality);
    float uz = getWaveHeight(pos + vec2(0.0, sampleRadius), quality);
    float dz = getWaveHeight(pos + vec2(0.0, -sampleRadius), quality);

    float gx = (rx - lx) / (2.0 * sampleRadius);
    float gz = (uz - dz) / (2.0 * sampleRadius);
    return vec2(gx, gz);
}

vec3 getCausticsColorApprox(
    vec2 pos,
    const int quality,
    float sampleRadius,
    float focusScale,
    float exposure,
    float dispersionShift
) {
    vec2 grad = gradientAt(pos, quality, sampleRadius);
    float gLen = length(grad);
    vec2 dir;
    if (gLen > 1e-6) {
        vec2 gn = grad / gLen;
        dir = vec2(gn.x, gn.y);
    } else {
        dir = vec2(1.0, 0.0);
    }

    vec2 offR = pos + dir * dispersionShift;
    vec2 offG = pos;
    vec2 offB = pos - dir * dispersionShift;

    float lapR = laplacianAt(offR, quality, sampleRadius);
    float lapG = laplacianAt(offG, quality, sampleRadius);
    float lapB = laplacianAt(offB, quality, sampleRadius);

    float focR = max(0.0, 1.0-lapR * focusScale);
    float focG = max(0.0, 1.0-lapG * focusScale);
    float focB = max(0.0, 1.0-lapB * focusScale);

    float iR = clamp(1.0 - exp(-focR * exposure), 0.0, 1.0);
    float iG = clamp(1.0 - exp(-focG * exposure), 0.0, 1.0);
    float iB = clamp(1.0 - exp(-focB * exposure), 0.0, 1.0);

    vec3 col = vec3(iR, iG, iB);

    return clamp(col, 0.0, 1.0);
}



float evalCaustRemapped(vec2 caust) {
    float wc = (1.0 - caust.g) * mix(caust.r, 1.0, 0.8);
    return remapSaturate(pow(wc, CAUSTICS_POWER), 0.0, 1.0, CAUSTICS_BRI_MIN, CAUSTICS_BRI_MAX);
}

vec3 computeCausticsWithDispersion(vec3 vMcPos) {
    vec3 sampleUV = vMcPos.xyz;
    sampleUV *= CAUSTICS_FREQ;
    sampleUV.xz = rotate2D(sampleUV.xz, -0.45);
    sampleUV.z *= 3.0;
    sampleUV += CAUSTICS_SPEED * vec3(0.0, frameTimeCounter * 0.8, frameTimeCounter);

    vec2 caustBase = texture(colortex8, sampleUV).ba;
    float baseCol = evalCaustRemapped(caustBase);

    float disp = clamp(CAUSTICS_DISPERSION, 0.0, 1.0);
    if (disp <= 0.0001) {
        return vec3(baseCol);
    }

    float shift = CAUSTICS_CHROMA_SHIFT * disp;
    vec3 offR = vec3( 0.0, shift * 0.66, 0.0 );
    vec3 offB = vec3( 0.0, -shift * 1.0, 0.0 );

    vec2 caustR = texture(colortex8, sampleUV + offR).ba;
    vec2 caustB = texture(colortex8, sampleUV + offB).ba;

    vec3 colDisp = vec3(
        evalCaustRemapped(caustR),
        evalCaustRemapped(caustBase),
        evalCaustRemapped(caustB)
    );

    return mix(vec3(baseCol), colDisp, disp);
}