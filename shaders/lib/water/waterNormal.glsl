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

// FishMan: Lake in highland
// https://www.shadertoy.com/view/4sdfz8
float waterFBM( in vec3 p , int iterations){
    float n = 0.0;
    n += 0.53125*noise3DFrom2D( noisetex, noiseTextureResolution, p*1.0 );
    n += 0.25000*noise3DFrom2D( noisetex, noiseTextureResolution, p*2.0 );
    if(iterations > 11){
        n += 0.12500*noise3DFrom2D( noisetex, noiseTextureResolution, p*4.0 );
        n += 0.06250*noise3DFrom2D( noisetex, noiseTextureResolution, p*8.0 );
        // n += 0.03125*noise3DFrom2D( noisetex, noiseTextureResolution, p*16.0 );
    }
    
    return n/0.984375;
}

float getwaves1(vec2 position, int iterations) {
    float height = 0.0;
    float h = 10.0;
    
    position *= 0.175;
    position = rotate2D(position, -0.45);
    position.y *= 3.0;
    position -= vec2(0, frameTimeCounter * WAVE_SPEED * 0.35);

    height = waterFBM(vec3(position, frameTimeCounter * WAVE_SPEED * 0.3), iterations);
    // height = pow(height, 1.45);

    height = mix(1.0, height, 1.0);

    return height;
}

// Style 2: Multi-scale ocean
// 组合：尖峰定向涌浪(Gerstner-like) + 3D FBM 中尺度起伏 + 域扭曲高频毛刺
// 接口与 getwaves/getwaves1 一致：输出近似 [0,1]，由 getWaveHeight 统一 saturate
float getwaves2(vec2 position, int iterations){
    // -------- 基础坐标与时间 --------
    vec2 basePos = position * 0.55;                      // 主涌浪尺度
    float t = frameTimeCounter * WAVE_SPEED;

    // -------- 低频中尺度：3D FBM，提供大面起伏背景 --------
    vec2 midPos = position * 0.22;
    midPos = rotate2D(midPos, 0.37);
    midPos -= vec2(0.0, t * 0.18);
    float midSwell = waterFBM(vec3(midPos, t * 0.12), iterations);
    // FBM 输出约 [0,1]，中心化到 [-0.5, 0.5] 便于与峰波线性叠加
    midSwell = midSwell - 0.5;

    // -------- 主涌浪：两组方向不同的尖峰定向波(Gerstner-like) --------
    // 方向用黄金角步进，避免与坐标轴/彼此对齐
    float sumValues  = 0.0;
    float sumWeights = 0.0;
    float iter       = 0.0;
    float freq       = 1.0;
    float tMul       = WAVE_SPEED * 0.9;
    float weight     = 1.0;
    vec2  p2         = basePos;

    // 固定少量迭代做主涌浪(不受 iterations 直接控制，保持相对便宜)
    // 质量档降级时减少一次
    int mainIters = (iterations > 11) ? 5 : 3;
    for(int i = 0; i < mainIters; i++){
        vec2 dir = vec2(fastSin(iter), fastCos(iter));
        vec2 res = wavedx(p2, dir, freq, frameTimeCounter * tMul);

        // 域扭曲：让后续波看到被前面波扰动的坐标，形成非对称/交叉干涉
        p2 += dir * res.y * weight * DRAG_MULT * 0.6;

        sumValues  += res.x * weight;
        sumWeights += weight;

        weight  = mix(weight, 0.0, 0.22);
        freq   *= 1.27;
        tMul   *= 1.09;
        iter   += 2.39996323;   // 黄金角(弧度)，去对齐
    }
    float mainSwell = sumValues / max(sumWeights, 1e-5);   // ~[0,1]

    // -------- 高频毛刺：域扭曲 + 小尺度 FBM，仅在高质量时启用 --------
    float ripple = 0.0;
    if(iterations > 11){
        // 用中尺度 FBM 作为扭曲源，做一次 domain warp
        vec2 warp = vec2(midSwell, waterFBM(vec3(midPos * 1.7 + 3.1, t * 0.17), iterations) - 0.5);
        vec2 hiPos = position * 1.15 + warp * 0.6;
        hiPos = rotate2D(hiPos, -0.83);
        hiPos -= vec2(0.0, t * 0.55);
        ripple = waterFBM(vec3(hiPos, t * 0.45), iterations) - 0.5;
    }

    // -------- 加权合成 --------
    // 主涌浪为主，中尺度做慢速起伏，毛刺只贡献小幅细节
    float h = 0.0;
    h += mainSwell * 0.70;
    h += (midSwell + 0.5) * 0.22;       // 还原到 [0,1] 再按权重加
    h += (ripple   + 0.5) * 0.12;       // 同上

    // 轻微对比拉伸，让峰更清晰但避免截断
    h = saturate(h);
    h = mix(h, h * h * (3.0 - 2.0 * h), 0.35); // 对 [0,1] 做 smoothstep 式软压

    return h;
}

float getWaveHeight(vec2 pos, const int quality){
    pos *= WAVE_FREQUENCY;
    float waveHeight;
    #if WAVE_TYPE == 0
        waveHeight = getwaves(pos, quality);
        if(isEyeInWater == 1) waveHeight = 1.0 - waveHeight;
    #elif WAVE_TYPE == 1
        waveHeight = getwaves1(pos, quality);
    #else
        waveHeight = getwaves2(pos, quality);
    #endif
    waveHeight = saturate(waveHeight);
    
    return saturate(mix(1.0, waveHeight, WAVE_HEIGHT));
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

    // #if defined VOXY || defined DISTANT_HORIZONS
    //     float mixFactor = remapSaturate(worldDis, 1000.0, 2000.0, 0.0, 1.0);
    //     normalW = mix(normalW, vec3(0.0, 1.0, 0.0), mixFactor);
    // #endif

    return normalW;
}