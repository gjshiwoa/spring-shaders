// 叛逆者: Tone mapping进化论
// https://zhuanlan.zhihu.com/p/21983679

vec3 ACES(vec3 color) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    color *= ACES_ADDITIVE;
    color = saturate((color * (a * color + b)) / (color * (c * color + d) + e));
    return color;
}

const mat3 LinearToACES = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
);

const mat3 ACESToLinear = mat3(
    1.60475, -0.10208, -0.00327,
    -0.53108, 1.10813, -0.07276,
    -0.07367, -0.00605, 1.07602
);

vec3 rrt_and_odt_fit(vec3 col){
    vec3 a = col * (col + 0.0245786) - 0.000090537;
    vec3 b = col * (0.983729 * col + 0.4329510) + 0.238081;
    return a / b;
}

vec3 ACESFull(vec3 col){
    col *= ACES_FULL_ADDITIVE;
    vec3 aces = LinearToACES * col;
    aces = rrt_and_odt_fit(aces);
    return ACESToLinear * aces;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 F(vec3 x){
    const float A = 0.22;
    const float B = 0.30;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.01;
    const float F = 0.30;
 
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 Hable(vec3 color){
    const float WHITE = 11.2;
    color = F(HABLE_ADDITIVE * color) / F(vec3(WHITE));
    return color;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 Hejl(vec3 color) {
    color *= HEJL_ADDITIVE;
    color = max(vec3(0.0), color - vec3(-0.001));
    color = (color * (6.2 * color + 0.5)) / (color * (6.2 * color + 1.7) + 0.06);
    toLinear(color);
    return color;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 Lottes(vec3 x) {
    const vec3 a = vec3(1.6);
    const vec3 d = vec3(0.977);
    const vec3 hdrMax = vec3(8.0);
    const vec3 midIn = vec3(0.18);
    const vec3 midOut = vec3(0.267);

    const vec3 b =
        (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    const vec3 c =
        (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

    x *= LOTTES_ADDITIVE;
    x = pow(x, a) / (pow(x, a * d) * b + c);
    return x;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// https://github.com/dmnsgn/glsl-tone-map/blob/main/agx.glsl
// 感谢 Tahnass 提供的帮助
const mat3 AgXInsetMatrix = mat3(
    0.856627153315983, 0.137318972929847, 0.11189821299995,
    0.0951212405381588, 0.761241990602591, 0.0767994186031903,
    0.0482516061458583, 0.101439036467562, 0.811302368396859
);

const mat3 AgXOutsetMatrix = mat3(
    1.1271005818144368, -0.1413297634984383, -0.14132976349843826,
    -0.11060664309660323, 1.157823702216272, -0.11060664309660294,
    -0.016493938717834573, -0.016493938717834257, 1.2519364065950405
);

vec3 agxDefaultContrastApprox6(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    
    return  + 15.5     * x4 * x2
            - 40.14    * x4 * x
            + 31.96    * x4
            - 6.868    * x2 * x
            + 0.4298   * x2
            + 0.1191   * x
            - 0.00232;
}

vec3 agxDefaultContrastApprox7(vec3 x) {
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    vec3 x6 = x4 * x2;
    
    return  - 17.86     * x6 * x
            + 78.01     * x6
            - 126.7     * x4 * x
            + 92.06     * x4
            - 28.72     * x2 * x
            + 4.361     * x2
            - 0.1718    * x
            + 0.002857;
}

vec3 simpleFilter(vec3 color, vec3 slope, vec3 offset, vec3 power, float sat) {
    float luma = getLuminance(color);
    vec3 c = pow(color * slope + offset, power);
    return luma + sat * (c - luma);
}

vec3 AgX(vec3 color) {
    color *= AGX_ADDITIVE;

    // color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
    color = AgXInsetMatrix * color;

    // log曲线来自 iterationT 
    const float hev = AGX_EV * 0.5;
	const float middle_grey = 0.18;
	color = clamp(log2(color / middle_grey), -hev, hev);
	color = (color + hev) / AGX_EV;
    color = agxDefaultContrastApprox7(color);

    color = AgXOutsetMatrix * color;
    // color = LINEAR_REC2020_TO_LINEAR_SRGB * color;
    toLinear(color);
    
    return color;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 Neutral(vec3 color) {
    const float startCompression = 0.8 - 0.04;
    const float desaturation = 0.15;
    color *= NEUTRAL_ADDITIVE;

    float x = min(color.r, min(color.g, color.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    color -= offset;

    float peak = max(color.r, max(color.g, color.b));
    if (peak < startCompression) return color;

    const float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    color *= newPeak / peak;

    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(color, vec3(newPeak), g);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    vec3 w0 = vec3(1.0 - smoothstep(0.0, m, x));
    vec3 w2 = vec3(step(m + l0, x));
    vec3 w1 = vec3(1.0 - w0 - w2);

    vec3 T = vec3(m * pow(x / m, vec3(c)) + b);
    vec3 S = vec3(P - (P - S1) * fastExp(CP * (x - S0)));
    vec3 L = vec3(m + a * (x - m));

    return T * w0 + L * w1 + S * w2;
}

vec3 Uchimura(vec3 x) {
    const float P = 1.0;  // max display brightness
    const float a = 1.0;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.4;  // linear section length
    const float c = 1.33; // black
    const float b = 0.0;  // pedestal

    x *= UCHIMURA_ADDITIVE;
    return uchimura(x, P, a, m, l, c, b);
}



// TAA
float Luminance(vec3 color){
    return 0.25 * color.r + 0.5 * color.g + 0.25 * color.b;
}
vec3 ToneMap(vec3 color){
    return color / (1 + Luminance(color));
}

vec3 UnToneMap(vec3 color){
    return color / (1 - Luminance(color));
}