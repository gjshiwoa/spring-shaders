// 面向GPT4编程: RayMarching实时体积云渲染入门(上)
// https://zhuanlan.zhihu.com/p/248406797

// 从巴洛克到浪漫的你: 《地平线：零之曙光》的体积云景实现
// https://zhuanlan.zhihu.com/p/638440336

// 体积云实时渲染光照简单原理
// https://zhuanlan.zhihu.com/p/629189750

// 异世界的魔法石: 生成连续的2D、3D柏林噪声（Perlin Noise），技术美术教程
// https://zhuanlan.zhihu.com/p/620107368
// 生成连续的2D、3D细胞噪声（Worley Noise），技术美术教程
// https://zhuanlan.zhihu.com/p/620316997

// 感谢 DavLand 提供的帮助！

float sampleLowFrequencyNoise(vec3 p){
    #ifdef GBF
        vec4 low_frequency_noises = texture(gaux4, p + vec3(0.0, VOLUME_CLOUD_NOISE_SEED, 0.0));
    #else
        vec4 low_frequency_noises = texture(depthtex2, p + vec3(0.0, VOLUME_CLOUD_NOISE_SEED, 0.0));
    #endif
    float low_freq_FBM = (low_frequency_noises.g * 0.5) + (low_frequency_noises.b * 0.25) + (low_frequency_noises.a * 0.125);
    float base_cloud = remapSaturate(low_frequency_noises.r, -1.0 * (1.0 - low_freq_FBM), 1.0, 0.0, 1.0);
    return base_cloud;
}

float sampleHighFrequencyNoise(vec3 p){
    #ifdef GBF
        vec4 high_frequency_noises = texture(gaux3, p + vec3(0.0, 0.2, 0.0));
    #else
        vec4 high_frequency_noises = texture(colortex2, p + vec3(0.0, 0.2, 0.0));
    #endif
    float high_freq_FBM = (high_frequency_noises.r * 0.5) + (high_frequency_noises.g * 0.25) + (high_frequency_noises.b * 0.125) + (high_frequency_noises.a * 0.0625);
    return high_freq_FBM;
}

vec2 sampleWeather(vec2 p){
    #ifdef GBF
        vec4 weatherData = texture(depthtex0, p);
    #else
        vec4 weatherData = texture(noisetex, p);
    #endif
    return weatherData.ra;
}

float sampleCloudDensity(vec3 cameraPos, bool doCheaply){
    float height_fraction = getHeightFractionForPoint(cameraPos.y, cloudHeight);
    if(height_fraction < 0.0 || height_fraction > 1.0) return 0.0;
    vec3 p = cameraPos;
    // p = floor(p * 0.005);
    // p /= 0.005;

    vec3 wind_direction = normalize(vec3(1.0, 0.0, 1.0));
    p += wind_direction * frameTimeCounter * CLOUD_SPEED_LOW;

    float base_cloud = sampleLowFrequencyNoise(p * CLOUD_LOW_FREQUENCY);
    vec2 weatherData = sampleWeather(p.xz * CLOUD_WEATHER_FREQUENCY);
    p += wind_direction * height_fraction * 100.0;
    float coverage = saturate(mix(weatherData.r, weatherData.g, CLOUD_WEATHER_SHAPE) - 0.08);
    base_cloud = remapSaturate(base_cloud, 
            saturate(1.0 - CLOUD_COVERAGE * coverage - 0.35 * rainStrength + 0.15 * pow(height_fraction, 1.0)), 1.0, 0.0, 1.0);

    float final_cloud = base_cloud;

    if(!doCheaply){
        float high_freq_FBM = sampleHighFrequencyNoise(p * CLOUD_HIGH_FREQUENCY - 0.025 * wind_direction * frameTimeCounter);
        #ifdef CLOUD_HIGHER_NOISE_ENABLE
                high_freq_FBM = high_freq_FBM + 1.0 * sampleHighFrequencyNoise(p * CLOUD_HIGH_FREQUENCY * 8.0 - 0.025 * wind_direction * frameTimeCounter) * 0.3;        
        #endif
        float high_freq_noise_modifier = lerp(high_freq_FBM, 1.0 - high_freq_FBM, saturate(height_fraction * 10.0));    
        final_cloud = remapSaturate(final_cloud, saturate(high_freq_noise_modifier * CLOUD_HIGH_FREQ_EROSION), 1.0, 0.0, 1.0);
    }

    final_cloud = pow(final_cloud, 1.0);
    coverage = remapSaturate(height_fraction, 0.0, 0.1, 0.0, 1.0) * remapSaturate(height_fraction, 0.7, 1.0, 1.0, 0.0);
    final_cloud *= coverage; 

    final_cloud *= CLOUD_DENSITY;
    return saturate(final_cloud > 0.007 ? final_cloud : 0.0);
}



float computeLightPathOpticalDepth(vec3 p, vec3 lightWorldDir) {
    float opticalDepth = 0.0;
    vec3 currentPos = p /*+ 0.5 * lightWorldDir * initialStepSize*/;
    float prevDensity = sampleCloudDensity(currentPos, true) * 0.33;
    const float initialStepSize = CLOUD_LIGHTPATH_STEP_SIZE;
    const int N_SAMPLES = CLOUD_LIGHTPATH_SAMPLES;
    float currentStepSize = initialStepSize;

    for (int i = 1; i <= N_SAMPLES; i++) {
        float t = float(i) / float(N_SAMPLES);
        currentStepSize = mix(initialStepSize, initialStepSize * 5.0, t);
        currentPos += lightWorldDir * currentStepSize;
    
        bool doCheaply = false;
        if(i > N_SAMPLES * 0.25) doCheaply = true;
        float currentDensity = sampleCloudDensity(currentPos, doCheaply);
        opticalDepth += 0.5 * (prevDensity + currentDensity) * currentStepSize;
        
        prevDensity = currentDensity;
    }
    
    return opticalDepth;
}

float computeUpPathOpticalDepth(vec3 p, vec3 lightWorldDir) {
    float opticalDepth = 0.0;
    vec3 currentPos = p /*+ 0.5 * lightWorldDir * initialStepSize*/;
    float prevDensity = sampleCloudDensity(currentPos, true);
    const float initialStepSize = 40;
    const int N_SAMPLES = 2;
    float currentStepSize = initialStepSize;

    for (int i = 1; i <= N_SAMPLES; i++) {
        float t = float(i) / float(N_SAMPLES);
        currentStepSize = mix(initialStepSize, initialStepSize * 5.0, t);
        currentPos += lightWorldDir * currentStepSize;
    
        bool doCheaply = true;
        float currentDensity = sampleCloudDensity(currentPos, doCheaply);
        opticalDepth += 0.5 * (prevDensity + currentDensity) * currentStepSize;
        
        prevDensity = currentDensity;
    }
    
    return opticalDepth;
}

float GetAttenuationProbability(float sampleDensity){
    return max(exp(-sampleDensity), (exp(-sampleDensity * CLOUD_ATTENUATION_SECOND_SPREAD) * (CLOUD_ATTENUATION_SECOND_INTENSITY)));
}



float powderEffect(float sampleDensity, float cos_angle){
    float powd = 1.0 - exp(-sampleDensity * 2.0);
    return lerp(1.0, powd, saturate((-cos_angle * 0.5) + 0.5)); // [-1,1]->[0,1]
}

float powderEffectNew(vec3 p, float VoL, float stepCloudDensity){
    float normalizeHeight = getHeightFractionForPoint(p.y, cloudHeight);
    float depthProbability = pow(
        clamp(stepCloudDensity * 10.0, 0.0, 1.0),       // clamp(stepCloudDensity * 10.0, 0.0, 1.0)
        remap(normalizeHeight, 0.3, 0.85, 0.5, 2.0));   // remapSaturate(normalizeHeight, 0.3, 0.85, 0.5, 2.0))
    depthProbability += 0.05;
    
    float verticalProbability = pow(remap(normalizeHeight, 0.0, 0.22, 0.1, 1.0), 0.8); // pow(remapSaturate(normalizeHeight, 0.07, 0.22, 0.1, 1.0), 0.8)
    float r = VoL * 0.5 + 0.5;
    r = r * r;
    verticalProbability = verticalProbability * (1.0 - r) + r;
    return depthProbability * verticalProbability;
}

float GetInScatterProbability(vec3 p, float ds_loded){
    float height_fraction = getHeightFractionForPoint(p.y, cloudHeight);
    ds_loded = saturate(pow(ds_loded, CLOUD_INSCATTER_POWER));
    float depth_probability = 0.05 + pow(ds_loded, remapSaturate(height_fraction, 0.1, 0.75, 1.5, 4.0));
    float vertical_probability = pow(remapSaturate(height_fraction, 0.07, 0.32, 0.25, 1.0), 0.75);
    float in_scatter_probability = depth_probability * vertical_probability;

    return in_scatter_probability;
}



float GetDirectScatterProbability(float CosTheta, float eccentricity, float SilverIntensity, float SilverSpread){
    return max(hgPhase1(CosTheta, eccentricity), SilverIntensity * hgPhase1(CosTheta, (0.99 - SilverSpread)));
}

float dualLobPhase(float g0, float g1, float w, float cosTheta, float attenuation){
    return mix(hgPhase1(cosTheta, g0 * attenuation), hgPhase1(cosTheta, g1 * attenuation), w);
}

vec3 computeScatteringIntegral(vec3 stepScattering, float density, float transmittance, float stepTransmittance) {
    float sigmaS = density;
    const float sigmaA = 0.0;
    vec3 sigmaE = max(vec3(1e-8f), sigmaA + sigmaS);
    vec3 scatterLitStep = stepScattering * sigmaS;
    scatterLitStep = transmittance * (scatterLitStep - scatterLitStep * stepTransmittance);
    return scatterLitStep / sigmaE;
}

#define VL_CLOUD_MODE 1
#if VL_CLOUD_MODE == 1 && defined FSH
void cloudRayMarching(vec3 startPos, vec3 worldPos, inout float transmittance, inout vec3 scattering, inout float cloudHitLength){
    transmittance = 1.0;
    scattering = vec3(0.0);

    vec3 worldDir = normalize(worldPos);
    float worldDis = length(worldPos);

    vec2 dis = intersectHorizontalAABB(startPos, worldDir, cloudHeight);
    vec2 stepDis = calculateStepDistances(dis.x, dis.y, worldDis);
    stepDis.y = min(stepDis.y, 20000.0);
    if(stepDis.y < 0.0001 || stepDis.x > 20000.0){
        return;
    }

    float verticalness = abs(dot(worldDir, upWorldDir));
    int N_SAMPLES = int(remap(verticalness, 0.0, 1.0, VOLUMETRIC_CLOUDS_MAX_SAMPLES, VOLUMETRIC_CLOUDS_MIN_SAMPLES));
    // #ifdef SKY_BOX
    //     N_SAMPLES = 12;
    // #endif

    float rayLength = stepDis.y;
    float stepSize = rayLength / float(N_SAMPLES);

    vec3 oriStartPos = startPos;
    startPos += worldDir * stepDis.x;
    startPos += worldDir * stepSize * temporalBayer64(gl_FragCoord.xy);

    vec3 hitPos = startPos;
    bool isHit = false;

    float stepN = CLOUD_STEP_ALL;
    for(int i = 0; i < N_SAMPLES * stepN; i++){
        float t = float(i) * stepSize;
        if(stepDis.x + t > 20000.0 || t >= rayLength || transmittance < 0.05){
            break;
        }
        
        vec3 pos = startPos + t * worldDir;
        float density = sampleCloudDensity(pos, false);
        
        if(density > 0.0001){
            if(!isHit){
                hitPos = pos;
                isHit = true;
            }

            float opticalDepth = 50.0 * density;
            float stepTransmittance = GetAttenuationProbability(opticalDepth);

            float VoL = dot(worldDir, lightWorldDir);
            float iVoL = dot(worldDir, -lightWorldDir);

            float lightPathOpticalDepth = computeLightPathOpticalDepth(pos, lightWorldDir);
            float attenuation = GetAttenuationProbability(lightPathOpticalDepth);

            float inScatter = GetInScatterProbability(pos, opticalDepth);

            float phase = GetDirectScatterProbability(VoL, 0.05, CLOUD_SILVER_INTENSITY, CLOUD_SILVER_SPREAD);
            float phase1 = GetDirectScatterProbability(iVoL, 0.3, 0.0, 0.0);
            phase = max(phase, 0.5 * phase1);

            vec3 stepScattering = attenuation * inScatter * phase * sunColor * (1.0 - 0.97 * isNight);


        #ifndef SKY_BOX
            float upPathOpticalDepth = computeUpPathOpticalDepth(pos, upWorldDir);
            float upAttenuation = GetAttenuationProbability(upPathOpticalDepth);
            stepScattering += 0.025 * upAttenuation * skyColor * (1.0 - 0.97 * isNightS);
        #endif
        
            scattering += transmittance * (stepScattering - stepScattering * stepTransmittance) / max(opticalDepth, 1e-5);
            transmittance *= stepTransmittance;
        }
    }
    
    scattering = pow(scattering, vec3(0.75));
    cloudHitLength = length(hitPos - oriStartPos);
}

#endif


vec4 temporal_CLOUD3D(vec4 color_c){
    vec2 uv = texcoord * 2 - vec2(1.0, 0.0);
    float z = 1.0;
    vec3 prePos = getPrePos(viewPosToWorldPos(screenPosToViewPos(vec4(uv, z, 1.0))));

    prePos.xy = (prePos.xy * 0.5 + vec2(0.5, 0.0)) * viewSize - 0.5;
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen(((curUV) * invViewSize) * 2.0 - vec2(1.0, 0.0))) continue;


        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));
        
        vec4 cc = texelFetch(colortex3, ivec2(curUV), 0);
        float wc = dot(cc, vec4(1.0)) > 0.01 ? 1.0 : 0.0;
        weight *= wc;

        vec4 pre = texelFetch(colortex6, ivec2(curUV + vec2(0.0, 0.5) * viewSize), 0);

        float zc = pre.a;
        weight *= pre.a < 1.0 ? 0.3 : 1.0;

        c_s += cc * weight;
        w_s += weight;
    }
    }

    vec4 blend = vec4(0.8);
    color_c = mix(color_c, c_s, w_s * blend);

    return color_c;
}



#if VL_CLOUD_MODE == 0
void cloudRayMarching(vec3 oriColor, vec3 startPos, vec3 worldPos, inout float transmittance, inout vec3 scattering, inout float cloudHitLength){
    transmittance = 1.0;
    scattering = vec3(0.0);

    vec3 worldDir = normalize(worldPos);
    float worldDis = length(worldPos);

    vec2 dis = intersectHorizontalAABB(startPos, worldDir, cloudHeight);    // 与云层交点的距离, 返回 vec2(min max)
    vec2 stepDis = calculateStepDistances(dis.x, dis.y, worldDis);    // 返回 到步进起点的距离，在起点后步进到终点的距离
    if(stepDis.y < 0.0001 || stepDis.x > 20000){
        // transmittance = 0.0;
        return;
    }

    float alpha = 0.0;

    float rayLength = stepDis.y;
    // float CLOUD_LARGE_STEP = max(rayLength, CLOUD_MAX_DISTANCE) / 15;
    // int CLOUD_EMPTY_STEPS = int(CLOUD_LARGE_STEP / CLOUD_SMALL_STEP) + 1;
    float stepSize = CLOUD_LARGE_STEP;
    float t = 0.0;
    int emptySteps = 0;
    bool inCloud = false;

    vec3 oriStartPos = startPos;
    startPos += worldDir * stepDis.x;
    startPos += worldDir * CLOUD_SMALL_STEP * temporalBayer64(gl_FragCoord.xy);

    vec3 hitPos = startPos;
    bool isHit = false;

    for(int i = 0; i < CLOUD_MAX_STEPS; i++){
        if(stepDis.x + t > 20000 || t >= rayLength + CLOUD_LARGE_STEP || t > CLOUD_MAX_DISTANCE || transmittance < 0.01){
            break;
        }
        vec3 pos = startPos + t * worldDir;
        float density;
        if(!inCloud){
            density = sampleCloudDensity(pos, true);
            if (density > 0.01){
                t -= stepSize;
                stepSize = CLOUD_SMALL_STEP;
                inCloud = true;
                emptySteps = 0;
                continue;
            }
        }else{
            density = sampleCloudDensity(pos, false);
            if(density > 0.0075){
                if(!isHit){
                    hitPos = pos;
                    isHit = true;
                }



                float opticalDepth = stepSize * density;
                float stepTransmittance = GetAttenuationProbability(opticalDepth, 0.6, 0.2);    // float sampleDensity, float secondInensity, float secondSpread
                transmittance *= stepTransmittance;

                float VoL = dot(worldDir, lightWorldDir);
                float iVoL = dot(worldDir, -lightWorldDir);

                float lightPathOpticalDepth = computeLightPathOpticalDepth(pos, 50, lightWorldDir, 3);
                // float attenuation = exp(-lightPathOpticalDepth);
                float attenuation = GetAttenuationProbability(lightPathOpticalDepth, 0.6, 0.2);
                // float attenuation = pow(1.0 + lightPathOpticalDepth * 1.2, -0.93); //pow(1.0 + lightPathOpticalDepth * 1.2, -0.93)

                // float upDirOpticalDepth = computeLightPathOpticalDepth(pos, stepSize, upWorldDir, 2);
                // float upAttenuation = GetAttenuationProbability(upDirOpticalDepth);
                // float upAttenuation = exp(-upDirOpticalDepth);
                // attenuation += 0.5 * upAttenuation;

                float inScatter = GetInScatterProbability(pos, opticalDepth, 1.5);  // vec3 p, float ds_loded, float ds_power
                // float inScatter = powderEffect(opticalDepth, VoL);
                // float inScatter = powderEffectNew(pos, VoL, opticalDepth);
                // float inScatter = GetInscatter(opticalDepth, VoL, lightPathOpticalDepth);

                float phase = GetDirectScatterProbability(VoL, 0.2, 0.6, 0.4);  // float CosTheta, float eccentricity, float SilverIntensity, float SilverSpread
                float phase1 = GetDirectScatterProbability(iVoL, 0.3, 0.0, 0.0);
                phase = max(phase, 0.5 * phase1);
                // float phase = dualLobPhase(0.3, -0.3, 0.2, -VoL, attenuation);
                // float phase = GetPhase(VoL, VoL, lightPathOpticalDepth);

                vec3 stepScattering = attenuation * inScatter * phase * sunColor;
                // stepScattering += 0.5 * attenuation * inScatter * phase * skyColor;
                
                // scattering += transmittance * stepScattering;
                float sigmaS = density;
                // float sigmaS = saturate(1.0 - exp2(-density * 20.0));
                scattering += computeScatteringIntegral(stepScattering, sigmaS, transmittance, stepTransmittance);



                emptySteps = 0;
            }else{
                emptySteps++;
                if(emptySteps >= CLOUD_EMPTY_STEPS){
                    stepSize = CLOUD_LARGE_STEP;
                    inCloud = false;
                }
            }
        }

        t += stepSize;
    }
    scattering = pow(scattering, vec3(0.75));
    cloudHitLength = length(hitPos - oriStartPos);
}
#endif