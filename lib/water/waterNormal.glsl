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
    position += vec2(0, frameTimeCounter * WAVE_SPEED * 0.35);

    height = waterFBM(vec3(position, frameTimeCounter * WAVE_SPEED * 0.4), iterations);
    // height = pow(height, 1.45);

    height = mix(1.0, height, 1.0);

    return height;
}

float getWaveHeight(vec2 pos, const int quality){
    pos *= WAVE_FREQUENCY;
    float waveHeight;
    #if WAVE_TYPE == 0
        waveHeight = getwaves(pos, quality);
        if(isEyeInWater == 1) waveHeight = 1.0 - waveHeight;
    #else
        waveHeight = getwaves1(pos, quality);
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

vec3 getWaveNormalDH(vec2 centerXZ, const int quality){
    const float eps = 0.05;
    float hC = getWaveHeight(centerXZ, quality);
    float hX = getWaveHeight(centerXZ + vec2(eps, 0.0), quality);
    float hZ = getWaveHeight(centerXZ + vec2(0.0, eps), quality);

    return normalFromHeights(centerXZ, hC, hX, hZ, eps);
}