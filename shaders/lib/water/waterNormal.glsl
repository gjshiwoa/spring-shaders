// afl_ext: Very fast procedural ocean 
// https://www.shadertoy.com/view/MdXyzX

#define DRAG_MULT 0.38

vec2 wavedx(vec2 position, vec2 direction, float frequency, float timeshift) {
    float x = dot(direction, position) * frequency + timeshift;
    float wave = fastExp(sin(x) - 1.0);
    float dx = wave * cos(x);
    return vec2(wave, -dx);
}

float getwaves(vec2 position, int iterations) {
    position *= 0.65;
    float iter = 0.5 * PI;
    float frequency = 1.0;
    float timeMultiplier = WAVE_SPEED;
    float weight = 1.0;
    float sumOfValues = 0.0;
    float sumOfWeights = 0.0;
    for(int i=0; i < iterations; i++) {
        vec2 p = vec2(fastSin(iter), fastCos(iter));

        vec2 res = wavedx(position, p, frequency, frameTimeCounter * timeMultiplier);

        position += p * res.y * weight * DRAG_MULT;

        sumOfValues += res.x * weight;
        sumOfWeights += weight;

        weight = mix(weight, 0.0, 0.2);
        frequency *= 1.18;
        timeMultiplier *= 1.07;

        iter += 1232.399963;
    }
    return mix(1.0, sumOfValues / sumOfWeights, 1.0);
}

// reinder: Misty Lake
// https://www.shadertoy.com/view/MsB3WR

const mat3 WAVE1_M3 = mat3( 0.00,  0.80,  0.60,
                           -0.80,  0.36, -0.48,
                           -0.60, -0.48,  0.64 );

float waterFBM( in vec3 p , int iterations){
    float f = 0.0;
    f += 0.5000*noise3DFrom2D( noisetex, noiseTextureResolution, p ); p = WAVE1_M3*p*2.02;
    f += 0.2500*noise3DFrom2D( noisetex, noiseTextureResolution, p ); p = WAVE1_M3*p*2.03;
    if(iterations > 10){
        f += 0.1250*noise3DFrom2D( noisetex, noiseTextureResolution, p ); p = WAVE1_M3*p*2.01;
        f += 0.0625*noise3DFrom2D( noisetex, noiseTextureResolution, p );
        return f/0.9375;
    }
    return f/0.75;
}

float getwaves1RoughnessMask(vec2 position) {
    float tM = frameTimeCounter * WAVE_SPEED * 0.06;

    vec2 mp0 = position * 0.018 + vec2(tM, tM * 0.7);
    vec2 mp1 = position * 0.045 - vec2(tM * 0.5, tM * 0.9) + vec2(53.1, 11.7);

    float m0 = textureN(noisetex, mp0 / noiseTextureResolution, noiseTextureResolution).x;
    float m1 = textureN(noisetex, mp1 / noiseTextureResolution, noiseTextureResolution).x;

    float mask = mix(m0, m1, 0.33);

    mask = remapSaturate(mask, 0.25, 0.75, 0.33, 1.0);
    return mask;
}

float getwaves1(vec2 position, int iterations) {
    float t = frameTimeCounter * WAVE_SPEED * 3.0;

    vec2 pA = position * 0.35;
    pA = rotate2D(pA, -0.75);
    pA.y *= 4.0;
    float tA = t * 0.3;
    pA -= vec2(0.0, tA);
    float hA = waterFBM(vec3(pA, tA * 0.5), 10);

    vec2 pB = position * 0.4;
    pB = rotate2D(pB, -0.3);
    pB.y *= 4.0;
    float tB = t * 0.35;
    pB -= vec2(0.0, tB);
    float hB = waterFBM(vec3(pB, tB * 0.5), 10);

    float height = mix(hA, hB, 0.33);
    float mask = getwaves1RoughnessMask(position);
    height = mix(1.0, height, mask);

    return height;
}

// Wave style 2: advected cross sea with swell modulation.

const vec2  WAVE2_ADVECT_DIR   = vec2(0.8660254, 0.5);     // 与 +X 成 30°
const float WAVE2_ADVECT_SPEED = 2.5;                      // 共同底速
const float WAVE2_DIR_BIAS     = 0.35;

float gerstnerCross(vec2 position, int iterations) {
    vec2 dir0 = vec2( 0.8660254,  0.5);        // 主风向
    vec2 dir1 = vec2(-0.7071068,  0.7071068);  // 次风向
    vec2 dir2 = vec2( 0.3826834, -0.9238795);  // 交叉 1
    vec2 dir3 = vec2(-0.9238795, -0.3826834);  // 交叉 2

    dir0 = normalize(mix(dir0, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS));
    dir1 = normalize(mix(dir1, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS));
    dir2 = normalize(mix(dir2, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS * 0.6));
    dir3 = normalize(mix(dir3, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS * 0.6));

    float frequency = 1.0;
    float timeMul   = WAVE_SPEED;
    float weight    = 1.0;
    float sumV = 0.0;
    float sumW = 0.0;

    float iter = 0.5 * PI;

    for (int i = 0; i < iterations; i++) {
        vec2 d;
        int m = i & 3;
        if      (m == 0) d = dir0;
        else if (m == 1) d = dir1;
        else if (m == 2) d = dir2;
        else             d = dir3;

        d = rotate2D(d, iter * 0.03);

        vec2 res = wavedx(position, d, frequency, frameTimeCounter * timeMul + iter);

        float drag = (m < 2) ? DRAG_MULT : DRAG_MULT * 0.55;
        position += d * res.y * weight * drag;

        sumV += res.x * weight;
        sumW += weight;

        weight    = mix(weight, 0.0, 0.23);
        frequency *= 1.22;
        timeMul   *= 1.06;
        iter      += 1232.399963;
    }
    return sumV / sumW;
}

float swellFBM(vec2 position, int iterations) {
    vec2 pA = rotate2D(position, -0.45);
    pA.y *= 2.6;
    pA -= vec2(0.0, frameTimeCounter * WAVE_SPEED * 0.28);

    vec2 pB = rotate2D(position, 0.85);
    pB.y *= 1.7;
    pB += vec2(frameTimeCounter * WAVE_SPEED * 0.22, 0.0);

    float a = waterFBM(vec3(pA * 0.09, frameTimeCounter * WAVE_SPEED * 0.17), iterations);
    float b = waterFBM(vec3(pB * 0.13, frameTimeCounter * WAVE_SPEED * 0.23), iterations);

    float env = a * b;
    return clamp(env * 1.6 + 0.35, 0.35, 1.15);
}

float capillaryRipples(vec2 position, int iterations) {
    vec2 warp = vec2(
        noise3DFrom2D(noisetex, noiseTextureResolution, vec3(position * 0.6,               frameTimeCounter * WAVE_SPEED * 0.4)),
        noise3DFrom2D(noisetex, noiseTextureResolution, vec3(position * 0.6 + vec2(17.3),  frameTimeCounter * WAVE_SPEED * 0.4))
    );
    vec2 p = position * 1.8 + (warp - 0.5) * 1.4;
    vec2 perp = vec2(-WAVE2_ADVECT_DIR.y, WAVE2_ADVECT_DIR.x);
    p -= perp * (frameTimeCounter * WAVE_SPEED * 0.18);

    float n  = noise3DFrom2D(noisetex, noiseTextureResolution, vec3(p,        frameTimeCounter * WAVE_SPEED * 0.6)) * 0.6;
          n += noise3DFrom2D(noisetex, noiseTextureResolution, vec3(p * 2.3,  frameTimeCounter * WAVE_SPEED * 0.9)) * 0.3;
    if (iterations > 11) {
          n += noise3DFrom2D(noisetex, noiseTextureResolution, vec3(p * 4.7,  frameTimeCounter * WAVE_SPEED * 1.3)) * 0.1;
    }
    return n;
}

float getwaves2(vec2 position, int iterations) {
    vec2 basePos = position * 0.75;

    // Shared advection for all layers.
    float t = 0.3 * frameTimeCounter * WAVE_SPEED * WAVE2_ADVECT_SPEED;
    basePos -= 1.0 * WAVE2_ADVECT_DIR * t;

    vec2 primaryPos = -basePos - WAVE2_ADVECT_DIR * (t * 0.6);
    float h = gerstnerCross(primaryPos, iterations);

    h = pow(saturate(h), 1.32);

    vec2 swellPos = -basePos - WAVE2_ADVECT_DIR * (t * 0.25);
    float env = swellFBM(swellPos, max(iterations / 2, 4));

    float modulated = mix(h, h * env, 0.75);

    return modulated;
}


float getWaveHeight(vec2 pos, const int quality){
    pos *= WAVE_FREQUENCY;
    float waveHeight;
    #if WAVE_TYPE == 0
        waveHeight = getwaves(pos, quality);
        if(isEyeInWater == 1) waveHeight = 1.0 - waveHeight;
        return saturate(mix(1.0, waveHeight, pow(WAVE_HEIGHT, 0.5)));
    #elif WAVE_TYPE == 1
        waveHeight = getwaves1(pos, quality);
        return saturate(mix(1.0, waveHeight, pow(WAVE_HEIGHT, 1.35)));
    #else
        waveHeight = getwaves2(pos, quality);
        if(isEyeInWater == 1) waveHeight = 1.0 - waveHeight;
        return saturate(mix(1.0, waveHeight, pow(WAVE_HEIGHT, 0.6)));
    #endif
}

vec2 waveParallaxMapping(vec2 uv, vec3 viewDirTS, out float currHeight){
    const float slicesMin = WAVE_PARALLAX_MIN_SAMPLES;
    const float slicesMax = WAVE_PARALLAX_MAX_SAMPLES;
    const int iterations = WAVE_PARALLAX_ITERATIONS;

    float slicesNum = ceil(lerp(slicesMax, slicesMin, abs(dot(vec3(0, 0, 1), viewDirTS))));
    float dHeight = 1.0 / slicesNum;
    float rayHeight = 1.0 - dHeight;
    vec2 dUV = WAVE_PARALLAX_HEIGHT * (viewDirTS.xy / viewDirTS.z) / slicesNum;
    vec2 currUVOffset = -dUV;
    
    float prevHeight = getWaveHeight(uv, iterations);
    currHeight = getWaveHeight(uv + currUVOffset, iterations);
    
    for(int i = 0; i < slicesNum; ++i){
        if(currHeight > rayHeight){
            break;
        }
        prevHeight = currHeight;
        currUVOffset -= dUV;
        rayHeight -= dHeight;
        currHeight = getWaveHeight(uv + currUVOffset, iterations);
    }

    float currDeltaHeight = currHeight - rayHeight;
    float prevDeltaHeight = rayHeight + dHeight - prevHeight;
    float weight = currDeltaHeight / (currDeltaHeight + prevDeltaHeight);

    vec2 parallaxUV = uv + currUVOffset + weight * dUV;
    return parallaxUV;
}

vec3 getWaveNormal(vec2 uv){
    const float c = 1.0;
    const int iterations = WAVE_NORMAL_ITERATIONS;
    const float dx = 0.2;
    vec2 du = vec2(dx, 0.0);
    vec2 dv = vec2(0.0, dx);
    float p = getWaveHeight(uv, iterations);
    float p_u = getWaveHeight(uv + du, iterations);
    float p_v = getWaveHeight(uv + dv, iterations);
    float frac_dp_du = c * (p_u - p) / du.x;
    float frac_dp_dv = c * (p_v - p) / dv.y;

    vec3 normal = normalize(vec3(-frac_dp_du, -frac_dp_dv, 1.0));

    return normal;
}

vec3 normalFrom3Points(vec3 pC, vec3 pX, vec3 pZ){
    vec3 tX = pX - pC;
    vec3 tZ = pZ - pC;

    vec3 n = normalize(cross(tZ, tX));

    if (dot(n, upWorldDir) < 0.0) n = -n;

    return n;
}

vec3 normalFromHeights(vec2 centerXZ, float hC, float hX, float hZ, float eps){
    vec3 pC = vec3(centerXZ.x,        hC, centerXZ.y);
    vec3 pX = vec3(centerXZ.x + eps,  hX, centerXZ.y);
    vec3 pZ = vec3(centerXZ.x,        hZ, centerXZ.y + eps);

    return normalFrom3Points(pC, pX, pZ);
}

vec3 getWaveNormalDH(vec2 centerXZ, const int quality, float worldDis){
    const float eps = 0.05;
    float hC = getWaveHeight(centerXZ, quality);
    float hX = getWaveHeight(centerXZ + vec2(eps, 0.0), quality);
    float hZ = getWaveHeight(centerXZ + vec2(0.0, eps), quality);

    vec3 normalW = normalFromHeights(centerXZ, hC, hX, hZ, eps);

    return normalW;
}
