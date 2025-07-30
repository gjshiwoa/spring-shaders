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
    float iter = 0.5 * PI; // this will help generating well distributed wave directions
    float frequency = 1.0; // frequency of the wave, this will change every iteration
    float timeMultiplier = WAVE_SPEED; // time multiplier for the wave, this will change every iteration
    float weight = 1.0;// weight in final sum for the wave, this will change every iteration
    float sumOfValues = 0.0; // will store final sum of values
    float sumOfWeights = 0.0; // will store final sum of weights
    for(int i=0; i < iterations; i++) {
        // generate some wave direction that looks kind of random
        vec2 p = vec2(fastSin(iter), fastCos(iter));
        // calculate wave data
        vec2 res = wavedx(position, p, frequency, frameTimeCounter * timeMultiplier);

        // shift position around according to wave drag and derivative of the wave
        position += p * res.y * weight * DRAG_MULT;

        // add the results to sums
        sumOfValues += res.x * weight;
        sumOfWeights += weight;

        // modify next octave ;
        weight = mix(weight, 0.0, 0.2);
        frequency *= 1.18;
        timeMultiplier *= 1.07;

        // add some kind of random value to make next wave look random too
        iter += 1232.399963;
    }
  // calculate and return
    return sumOfValues / sumOfWeights;
}

float getWaveHeight(vec2 pos, const int quality){
    pos *= WAVE_FREQUENCY;
    float waveHeight = getwaves(pos,  quality);
    if(isEyeInWater == 1) waveHeight = 1.0 - waveHeight;

    return mix(1.0, waveHeight, WAVE_HEIGHT);
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
    vec2 du = vec2(0.05, 0.0);
    vec2 dv = vec2(0.0, 0.05);
    float p = getWaveHeight(uv, iterations);
    float p_u = getWaveHeight(uv + du, iterations);
    float p_v = getWaveHeight(uv + dv, iterations);
    float frac_dp_du = c * (p_u - p) / du.x;
    float frac_dp_dv = c * (p_v - p) / dv.y;

    vec3 normal = normalize(vec3(-frac_dp_du, -frac_dp_dv, 1.0));

    return normal;
}