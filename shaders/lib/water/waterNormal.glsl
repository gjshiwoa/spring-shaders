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

// ---------------------------------------------------------------------------
// 波浪样式 1：iq 风格 FBM + 原项目的挤压/平移包装
//   - FBM 部分移植自 Shadertoy "Water Turbulence" (https://www.shadertoy.com/view/MdlXz8)，
//     使用 iq 的 m3 基底与 0.5/0.25/0.125/0.0625 权重；noise 替换为
//     项目的 noise3DFrom2D，时间项由调用方通过 p.z 传入。
//   - getwaves1 的坐标挤压/旋转/平移保持原样，仅更换 fbm 实现。
// ---------------------------------------------------------------------------

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

float getwaves1(vec2 position, int iterations) {
    float t = frameTimeCounter * WAVE_SPEED * 3.0;

    vec2 pA = position * 0.35;
    pA = rotate2D(pA, -0.65);
    pA.y *= 4.0;
    pA -= vec2(0.0, t * 0.33);
    float hA = waterFBM(vec3(pA, t * 0.3), 10);

    vec2 pB = position * 0.35;
    pB = rotate2D(pB, -0.25);
    pB.y *= 4.0;
    pB -= vec2(0.0, t * 0.28);
    float hB = waterFBM(vec3(pB, t * 0.25), 10);

    float height = mix(hA, hB, 0.66);

    height = mix(1.0, height, 1.0);

    return height;
}

// ---------------------------------------------------------------------------
// 波浪样式 2：复合海面
//   - Gerstner 式交叉海（2 个主风向 + 2 个交叉风向）
//   - 双层各向异性 FBM 涌浪包络（相乘式、domain warping）
//   - 波峰上的高频毛细波
//   - 非线性波峰锐化（波峰尖、波谷缓）
//   - 所有子层共享同一主风向平移，产生明显的行进梯度（海浪真的在推进），
//     同时各层速度不同以保持形状多样（不会锁相成条纹）。
// 计算量与样式 0/1 同数量级（主循环次数由 `iterations` 决定）。
// ---------------------------------------------------------------------------

// 统一主风向，已归一化；旋转这个向量即可改整体海流走向。
const vec2  WAVE2_ADVECT_DIR   = vec2(0.8660254, 0.5);     // 与 +X 成 30°
const float WAVE2_ADVECT_SPEED = 2.5;                      // 共同底速
// 内部各谐波方向朝主风向拉的强度（0..1）。
const float WAVE2_DIR_BIAS     = 0.35;

float gerstnerCross(vec2 position, int iterations) {
    // 四方向交叉海。方向固定，保证每个谐波形状连贯，
    // 不像 `getwaves` 那样每个 octave 都在旋转。
    vec2 dir0 = vec2( 0.8660254,  0.5);        // 主风向
    vec2 dir1 = vec2(-0.7071068,  0.7071068);  // 次风向
    vec2 dir2 = vec2( 0.3826834, -0.9238795);  // 交叉 1
    vec2 dir3 = vec2(-0.9238795, -0.3826834);  // 交叉 2

    // 把四个基方向都向主风向偏置：保留四种不同形状，但让传播轴
    // 朝 advect 方向收拢，从而让整个表面有更明显的行进梯度。
    dir0 = normalize(mix(dir0, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS));
    dir1 = normalize(mix(dir1, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS));
    dir2 = normalize(mix(dir2, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS * 0.6));
    dir3 = normalize(mix(dir3, WAVE2_ADVECT_DIR, WAVE2_DIR_BIAS * 0.6));

    float frequency = 1.0;
    float timeMul   = WAVE_SPEED;
    float weight    = 1.0;
    float sumV = 0.0;
    float sumW = 0.0;

    // 相位抖动，避免相邻 octave 对齐。
    float iter = 0.5 * PI;

    for (int i = 0; i < iterations; i++) {
        // 每个 octave 轮换四个基方向之一。
        vec2 d;
        int m = i & 3;
        if      (m == 0) d = dir0;
        else if (m == 1) d = dir1;
        else if (m == 2) d = dir2;
        else             d = dir3;

        // 每 octave 微旋转，打散四重对称。
        d = rotate2D(d, iter * 0.03);

        vec2 res = wavedx(position, d, frequency, frameTimeCounter * timeMul + iter);

        // drag 系数：主风向比交叉风向更强，产生不对称波峰
        // （波峰略向主风方向倾斜）。
        float drag = (m < 2) ? DRAG_MULT : DRAG_MULT * 0.55;
        position += d * res.y * weight * drag;

        sumV += res.x * weight;
        sumW += weight;

        weight    = mix(weight, 0.0, 0.18);
        frequency *= 1.22;
        timeMul   *= 1.06;
        iter      += 1232.399963;
    }
    return sumV / sumW;
}

float swellFBM(vec2 position, int iterations) {
    // 两层各向异性 FBM，使用不同的旋转角和漂移方向，相乘得到
    // 大尺度的"波浪群"包络。每层 FBM 仍沿各自轴向微漂移，让两层
    // 包络相对滑动；但外层 `basePos` 已经沿主风向做过 advect，
    // 所以净运动方向仍偏主风。
    vec2 pA = rotate2D(position, -0.45);
    pA.y *= 2.6;
    pA -= vec2(0.0, frameTimeCounter * WAVE_SPEED * 0.28);

    vec2 pB = rotate2D(position, 0.85);
    pB.y *= 1.7;
    pB += vec2(frameTimeCounter * WAVE_SPEED * 0.22, 0.0);

    float a = waterFBM(vec3(pA * 0.09, frameTimeCounter * WAVE_SPEED * 0.17), iterations);
    float b = waterFBM(vec3(pB * 0.13, frameTimeCounter * WAVE_SPEED * 0.23), iterations);

    // 映射到 [0.35, 1.15]，让包络仅作为调制，而不是在低值区域
    // 把表面压成死水。
    float env = a * b;
    return clamp(env * 1.6 + 0.35, 0.35, 1.15);
}

float capillaryRipples(vec2 position, int iterations) {
    // 附着在波峰上的小尺度毛细波，使用 domain warping 噪声。
    vec2 warp = vec2(
        noise3DFrom2D(noisetex, noiseTextureResolution, vec3(position * 0.6,               frameTimeCounter * WAVE_SPEED * 0.4)),
        noise3DFrom2D(noisetex, noiseTextureResolution, vec3(position * 0.6 + vec2(17.3),  frameTimeCounter * WAVE_SPEED * 0.4))
    );
    vec2 p = position * 1.8 + (warp - 0.5) * 1.4;
    // 叠加小幅的垂直漂移，避免毛细波退化成一维条纹；
    // 主风向位移由外层 `getwaves2` 统一施加。
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
    // 轻度压缩坐标，使主波长与其他样式在同一 WAVE_FREQUENCY 下对齐。
    vec2 basePos = position * 0.75;

    // 共同 advection：所有子层至少获得这一份沿主风向的位移，
    // 这是整体行进梯度的主要来源。
    float t = 0.2 * frameTimeCounter * WAVE_SPEED * WAVE2_ADVECT_SPEED;
    basePos -= 1.0 * WAVE2_ADVECT_DIR * t;

    // 1) 主干交叉海。在共同位移上再叠一份同向分量，
    //    让大浪明显顺风推进（而不是原地震荡）。
    vec2 primaryPos = -basePos - WAVE2_ADVECT_DIR * (t * 0.6);
    float h = gerstnerCross(primaryPos, iterations);

    // 2) 非线性波峰锐化（重力波特征：尖峰缓谷）。
    h = pow(saturate(h), 1.32);

    // 3) 涌浪包络：与主干同向但更慢，让波浪群跟在主干波峰之后，
    //    不会出现反向位移导致的"倒走"感。
    vec2 swellPos = -basePos - WAVE2_ADVECT_DIR * (t * 0.25);
    float env = swellFBM(swellPos, max(iterations / 2, 4));

    // 中心化调制：基准保持接近 1.0，由包络把波峰向上/向下推拉，
    // 形成可见的波群，同时避免出现大片死寂区域。
    float modulated = mix(h, h * env, 0.75);

    // // 4) 毛细波：与主风向同向但最快，叠在主表面上层。
    // vec2 ripplePos = basePos - WAVE2_ADVECT_DIR * (t * 1.8);
    // float ripple = capillaryRipples(ripplePos, iterations);
    // float crestMask = smoothstep(0.35, 0.9, h);
    // modulated += (ripple - 0.5) * 0.12 * crestMask;

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
        return saturate(mix(1.0, waveHeight, pow(WAVE_HEIGHT, 1.4)));
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

    // #if defined VOXY || defined DISTANT_HORIZONS
    //     float mixFactor = remapSaturate(worldDis, 1000.0, 2000.0, 0.0, 1.0);
    //     normalW = mix(normalW, vec3(0.0, 1.0, 0.0), mixFactor);
    // #endif

    return normalW;
}