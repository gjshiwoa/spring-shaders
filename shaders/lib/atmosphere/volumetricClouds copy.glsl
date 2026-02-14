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


float sampleCloudDensityLow(vec3 cameraPos, float height_fraction){
    vec4 weatherData = texture(noisetex, cameraPos.xz * 0.000025 + vec2(0.17325, 0.17325));
    float coverage = mix(weatherData.r, weatherData.g, 0.0);
    coverage = saturate(1.5 * coverage - 0.5 * height_fraction);
    coverage = saturate(1.0 - 0.5 * coverage - 0.3 * rainStrength + 0.05);

    // vec3 curl = vec3(0.0);
    // float curlNoise = weatherData.r * 2.0 - 1.0;
    // curl.xy = vec2(100.0 * curlNoise);
    // curl.z = 200.0 * curlNoise * height_fraction;
    // cameraPos += curl;

    vec4 low_frequency_noise = texture(colortex8, cameraPos * 0.00045 + vec3(0.0, 0.4, 0.0));
    float perlin3d = low_frequency_noise.r;
    vec3 worley3d = low_frequency_noise.gba;
    float worley3d_FBM = worley3d.r * 0.625 + worley3d.g * 0.25 + worley3d.b * 0.125;
    float base_cloud = remapSaturate(perlin3d, - 1.0 * worley3d_FBM, 1.0, 0.0, 1.0);
    base_cloud = remapSaturate(base_cloud, coverage, 1.0, 0.0, 1.0);

    return base_cloud;
}

float sampleCloudDensityHigh(vec3 cameraPos, float base_cloud, float height_fraction, vec3 wind_direction){
    float final_cloud = base_cloud;

    vec4 high_frequency_noises = texture(colortex2, cameraPos * 0.004 - 0.045 * wind_direction * frameTimeCounter);
    float high_freq_FBM = high_frequency_noises.r * 0.625 + high_frequency_noises.g * 0.25 + high_frequency_noises.b * 0.125;
    float high_freq_noise_modifier = lerp(high_freq_FBM * 4.0, 1.0 - high_freq_FBM, saturate(height_fraction * 5.0));  
    // float height_factor = remapSaturate(pow(height_fraction, 1.0), 0.0, 1.0, 0.66, 1.0);
    final_cloud = remapSaturate(pow(final_cloud, 0.6), high_freq_noise_modifier * 0.5, 1.0, 0.0, 1.0);
    
    return final_cloud;
}

float sampleCloudDensity(vec3 cameraPos, bool doCheaply){
    float height_fraction = getHeightFractionForPoint(cameraPos.y, cloudHeight);
    if(height_fraction < 0.0 || height_fraction > 1.0) return 0.0;

    vec3 wind_direction = normalize(vec3(1.0, 0.0, 1.0));
    cameraPos += wind_direction * frameTimeCounter * 10.0;
    cameraPos += wind_direction * height_fraction * 100.0;

    float base_cloud = sampleCloudDensityLow(cameraPos, height_fraction);
    float final_cloud = base_cloud;
    if(!doCheaply){
        final_cloud = sampleCloudDensityHigh(cameraPos, base_cloud, height_fraction, wind_direction);
    }

    final_cloud *= remapSaturate(height_fraction, 0.0, 0.1, 0.0, 1.0) * remapSaturate(height_fraction, 0.8, 1.0, 1.0, 0.0);
    final_cloud *= cloudSigmaE * (1.0 - 0.33 * rainStrength);

    return saturate(final_cloud > (0.01) ? final_cloud : 0.0);
}



float GetAttenuationProbability(float sampleDensity){
    return exp(-sampleDensity);
}

float GetAttenuationProbability(float sampleDensity, float secondSpread, float secondIntensity){
    return max(exp(-sampleDensity), (exp(-sampleDensity * secondSpread) * (secondIntensity)));
}

float GetAttenuationProbability(float sampleDensity, float VoL, 
        float secondIntensityMin, float secondIntensityMax, float secondSpreadMin, float secondSpreadMax){
    float secondIntensity = remapSaturate(VoL, 0.8, 1.0, secondIntensityMax, secondIntensityMin);
    float secondSpread = remapSaturate(VoL, 0.8, 1.0, secondSpreadMin, secondSpreadMax);
    return max(exp(-sampleDensity), (exp(-sampleDensity * secondSpread) * (secondIntensity)));
}

float computeLightPathOpticalDepth(vec3 currentPos, vec3 lightWorldDir, float initialStepSize, int N_SAMPLES) {
    float opticalDepth = 0.0;
    bool doCheaply = false;
    float prevDensity = sampleCloudDensity(currentPos, doCheaply);
    float currentStepSize = initialStepSize;

    for (int i = 1; i <= N_SAMPLES; i++) {
        float t = float(i) / float(N_SAMPLES);
        currentStepSize = mix(initialStepSize, initialStepSize * 10.0, t);
        currentPos += lightWorldDir * currentStepSize;

        if(i > 0.5 * N_SAMPLES) doCheaply = true;
        float currentDensity = sampleCloudDensity(currentPos, doCheaply);
        opticalDepth += 0.5 * (prevDensity + currentDensity) * currentStepSize;
        prevDensity = currentDensity;
    }

    return opticalDepth;
}

float GetInScatterProbability(float height_fraction, float ds_loded, float attenuation, float VoL){
    attenuation = saturate(attenuation);
    ds_loded = saturate(ds_loded);
    
    float height_factor = remapSaturate(pow(height_fraction, 1.0), 0.0, 1.0, 0.7, 1.0);
    float attenuation_factor = remapSaturate(pow(attenuation, 1.0), 0.0, 1.0, 0.25, 1.0);
    // float angle_factor = remapSaturate(VoL, 0.6, 1.0, 1.0, 0.5);
    float depth_probability = 0.05 + pow(ds_loded, attenuation_factor * 1.5 * height_factor);

    // float vertical_probability = pow(max(0.0, remap(height_fraction, 0.07, 0.14, 0.5, 1.0)), 0.8);

    float in_scatter_probability = depth_probability;
    return in_scatter_probability;
}

float GetDirectScatterProbability(float CosTheta, float eccentricity, float silverIntensity, float silverSpread){
    return max(hgPhase1(CosTheta, eccentricity), silverIntensity * hgPhase1(CosTheta, (0.99 - silverSpread)));
}

vec3 sunLuminance(vec3 pos, float VoL, float iVoL, float extinction){
    float density = extinction / CLOUD_SIGMA_S;
    float height_fraction = getHeightFractionForPoint(pos.y, cloudHeight);
    
    float lightPathOpticalDepth = computeLightPathOpticalDepth(pos, lightWorldDir, 20.0, 3);
    float attenuation = GetAttenuationProbability(lightPathOpticalDepth, VoL, 0.7, 0.7, 0.25 + 0.0 * sunRiseSetS, 0.5);

    float upPathOpticalDepth = computeLightPathOpticalDepth(pos, upWorldDir, 20.0, 2);
    float upAttenuation = GetAttenuationProbability(upPathOpticalDepth, 0.15, 0.7);
    attenuation += 0.15 * upAttenuation * isNoonS;

    float phase = GetDirectScatterProbability(VoL, 0.1, 0.7, 0.3);
    float phase1 = GetDirectScatterProbability(iVoL, 0.3, 0.0, 0.0) * 0.6;
    phase = max(phase, phase1);

    float inScatter = GetInScatterProbability(height_fraction, density, attenuation, VoL);

    vec3 direct = 1.35 * sunColor * attenuation * phase * pow(max(0.0, remap(height_fraction, 0.07, 0.14, 0.9, 1.0)), 0.8);

    float height_factor = remapSaturate(pow(height_fraction, 0.5), 0.0, 1.0, 0.5, 1.0);
    float depth_factor = pow(saturate(1.0 - density), 2.0);
    vec3 ambient = 0.3 * skyColor * (depth_factor + upAttenuation) * height_factor;

    vec3 luminance = direct + ambient;

    luminance *= extinction * inScatter;

    return luminance;
}

#define VL_CLOUD_MODE 1
#if VL_CLOUD_MODE == 1 && defined FSH
void cloudRayMarching(vec3 startPos, vec3 worldPos, inout vec4 intScattTrans, inout float cloudHitLength){
    intScattTrans = vec4(0.0, 0.0, 0.0, 1.0);

    vec3 worldDir = normalize(worldPos);
    float worldDis = length(worldPos);
    float VoL = dot(worldDir, lightWorldDir);
    float iVoL = dot(worldDir, -lightWorldDir);

    vec2 dis = intersectHorizontalAABB(startPos, worldDir, cloudHeight);
    
    vec2 stepDis = calculateStepDistances(dis.x, dis.y, worldDis);
    stepDis.y = min(stepDis.y, CLOUD_MAX_DISTANCE);
    if(stepDis.y < 0.0001 || stepDis.x > CLOUD_MAX_DISTANCE){
        return;
    }

    float verticalness = abs(dot(worldDir, upWorldDir));
    int N_COARSE = int(remap(verticalness, 0.0, 1.0, 18, 9));
    #ifdef SKY_BOX
        N_COARSE = int(N_COARSE * 0.2);
    #endif

    float rayLength = stepDis.y;
    float coarseStep = rayLength / float(max(N_COARSE, 1));
    const float SMALL_STEP = 4.0;
    const float SMALL_STEP_FACTOR = 1.0 / SMALL_STEP;
    float smallStep = coarseStep * SMALL_STEP_FACTOR;

    vec3 oriStartPos = startPos;
    startPos += worldDir * stepDis.x;
    float dither = temporalBayer64(gl_FragCoord.xy);
    startPos += worldDir * coarseStep * dither;

    // vec3 hitPos = startPos;
    // bool isHit = false;

    const float COARSE_DETECT_THRESHOLD = 0.01; // 低质量噪声判断云的阈值（可调）
    const float MIN_DENSITY = 1e-4;             // 视为有效云密度的最小值（保留原阈值）
    const int FINE_MISS_LIMIT = int(SMALL_STEP) + 1;              // 小步内连续多少次未命中则回到粗步
    const int MAX_FINE_STEPS_PER_DETECTION = 48;// 单次进入精细区域样本上限（防止爆炸）
    const int MAX_TOTAL_STEPS = 256;            // 全过程样本上限（总预算保护）

    float traveled = 0.0;
    int totalSteps = 0;

    while(traveled < rayLength){
        if(stepDis.x + traveled > CLOUD_MAX_DISTANCE) break;
        if(intScattTrans.a < 0.05) break;
        if(totalSteps++ > MAX_TOTAL_STEPS) break;

        vec3 coarsePos = startPos + traveled * worldDir;
        float lowDens = sampleCloudDensity(coarsePos, true);

        if(lowDens > COARSE_DETECT_THRESHOLD){
            traveled = max(0.0, traveled - coarseStep);

            int fineMisses = 0;
            int fineSteps = 0;

            while(traveled < rayLength){
                if(stepDis.x + traveled > CLOUD_MAX_DISTANCE) break;
                if(intScattTrans.a < 0.05) break;
                if(fineSteps++ > MAX_FINE_STEPS_PER_DETECTION) break;
                if(totalSteps++ > MAX_TOTAL_STEPS) break;

                vec3 pos = startPos + (traveled + smallStep * dither) * worldDir;
                float ext = sampleCloudDensity(pos, false);

                if(ext > MIN_DENSITY){
                    // if(!isHit){
                    //     hitPos = pos;
                    //     isHit = true;
                    // }
                    float opticalDepth = smallStep * ext;
                    float transmittance = GetAttenuationProbability(opticalDepth);
                    vec3 luminance = sunLuminance(pos, VoL, iVoL, ext);

                    intScattTrans.rgb += intScattTrans.a * (luminance - luminance * transmittance) / max(ext, 1e-5);
                    intScattTrans.a *= transmittance;

                    fineMisses = 0;
                }else{
                    fineMisses++;
                    if(fineMisses >= FINE_MISS_LIMIT){
                        traveled += smallStep;
                        break;
                    }
                }

                traveled += smallStep;
            }
        }else{
            traveled += coarseStep;
        }
    }

    intScattTrans.rgb *= 5.5 * (1.0 - 0.75 * isNight) * (1.0 + 0.25 * sunRiseSetS);

    // cloudHitLength = length(hitPos - oriStartPos);
    // if(isHit){
    //     intScattTrans.rgb *= Transmittance1(earthPos, earthPos + worldDir * cloudHitLength, 3.0);
    // }
}


#endif

vec4 temporal_cloud3D(vec4 color_c){
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
        float wc = dot(cc, vec4(1.0)) > 0.01 ? 1.0 : 0.1;
        weight *= wc;

        vec4 pre = texelFetch(colortex6, ivec2(curUV + vec2(0.0, 0.5) * viewSize), 0);

        float zc = pre.g;
        weight *= pre.g < 1.0 ? 0.1 : 1.0;

        c_s += cc * weight;
        w_s += weight;
    }
    }

    vec4 blend = vec4(0.8);
    color_c = mix(color_c, c_s, w_s * blend);

    return color_c;
}




#if VL_CLOUD_MODE == 0
/*
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
                float attenuation = GetAttenuationProbability(lightPathOpticalDepth, 0.6, 0.2);
                float inScatter = GetInScatterProbability(pos, opticalDepth, 1.5);  // vec3 p, float ds_loded, float ds_power
                float phase = GetDirectScatterProbability(VoL, 0.2, 0.6, 0.4);  // float CosTheta, float eccentricity, float SilverIntensity, float SilverSpread
                float phase1 = GetDirectScatterProbability(iVoL, 0.3, 0.0, 0.0);
                phase = max(phase, 0.5 * phase1);

                vec3 stepScattering = attenuation * inScatter * phase * sunColor;
                float sigmaS = density;
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
*/
#endif