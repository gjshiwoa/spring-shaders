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

float sampleCloudDensity(vec3 cameraPos, bool doCheaply){
    float height_fraction = getHeightFractionForPoint(cameraPos.y, cloudHeight);
    if(height_fraction < 0.0 || height_fraction > 1.0) return 0.0;

    vec3 wind_direction = normalize(vec3(1.0, 0.0, 1.0));
    cameraPos += wind_direction * frameTimeCounter * 10.0;
    cameraPos += wind_direction * height_fraction * 150.0;

    vec4 low_frequency_noise = texture(depthtex2, cameraPos * 0.00025 + vec3(0.0, 0.9, 0.0));
    float perlin3d = low_frequency_noise.r;
    vec3 worley3d = low_frequency_noise.gba;
    float perlin_worley = remapSaturate(perlin3d, -worley3d.r, 1.0, 0.0, 1.0);
    float worley3d_FBM = worley3d.g * 0.66 + worley3d.b * 0.33;
    float base_cloud = remapSaturate(perlin3d, -1.0 * (1.0 - worley3d_FBM), 1.0, 0.0, 1.0);

    vec4 weatherData = texture(noisetex, cameraPos.xz * 0.00004 + vec2(0.17325, 0.17325));
    float coverage = saturate(mix(weatherData.r, weatherData.g, 0.33));
    coverage = pow(coverage, remapSaturate(height_fraction, 0.1, 0.75, 0.55, 1.45));
    coverage = saturate(1.0 - 0.85 * coverage - 0.35 * rainStrength + 0.05);
    base_cloud = remapSaturate(base_cloud, coverage, 1.0, 0.0, 1.0);

    float final_cloud = base_cloud;
    if(!doCheaply){
        vec4 high_frequency_noises = texture(colortex2, cameraPos * 0.0055 - 0.045 * wind_direction * frameTimeCounter);
        float high_freq_FBM = (high_frequency_noises.r * 0.0) + (high_frequency_noises.g * 0.5) + (high_frequency_noises.b * 0.25) + (high_frequency_noises.a * 0.125);
        float high_freq_noise_modifier = lerp(high_freq_FBM, 1.0 - high_freq_FBM, saturate(height_fraction * 10.0));    
        final_cloud = remapSaturate(final_cloud, high_freq_noise_modifier * 0.5, 1.0, 0.0, 1.0);
    }

    final_cloud *= remapSaturate(height_fraction, 0.0, 0.1, 0.0, 1.0) * remapSaturate(height_fraction, 0.8, 1.0, 1.0, 0.0);
    final_cloud *= cloudSigmaE;

    return saturate(final_cloud > (0.003 + 0.007 * height_fraction) ? final_cloud : 0.0);
}



float GetAttenuationProbability(float sampleDensity){
    return exp(-sampleDensity);
}

float GetAttenuationProbability(float sampleDensity, float secondSpread, float secondIntensity){
    return max(exp(-sampleDensity), (exp(-sampleDensity * secondSpread) * (secondIntensity)));
}

float GetAttenuationProbability(float sampleDensity, float VoL, float secondSpread, float secondIntensityMin, float secondIntensityMax){
    float secondIntensity = remapSaturate(VoL, 0.9, 1.0, secondIntensityMax, secondIntensityMin);
    return max(exp(-sampleDensity), (exp(-sampleDensity * secondSpread) * (secondIntensity)));
}

float computeLightPathOpticalDepth(vec3 currentPos, vec3 lightWorldDir, float initialStepSize, int N_SAMPLES) {
    float opticalDepth = 0.0;
    bool doCheaply = false;

    float prevDensity = sampleCloudDensity(currentPos, doCheaply);
    float currentStepSize = initialStepSize;

    for (int i = 1; i <= N_SAMPLES; i++) {
        float t = float(i) / float(N_SAMPLES);
        currentStepSize = mix(initialStepSize, initialStepSize * 5.0, t);
        currentPos += lightWorldDir * currentStepSize;

        if(i > int(N_SAMPLES * 0.66)) doCheaply = true;
        float currentDensity = sampleCloudDensity(currentPos, doCheaply);
        opticalDepth += 0.5 * (prevDensity + currentDensity) * currentStepSize;
        prevDensity = currentDensity;
    }

    return opticalDepth;
}

float GetInScatterProbability(vec3 p, float ds_loded){
    float height_fraction = getHeightFractionForPoint(p.y, cloudHeight);
    float depth_probability = 0.05 + pow(saturate(ds_loded), remapSaturate(height_fraction, 0.3, 0.85, 0.5, 2.0));
    float vertical_probability = pow(max(0.0, remap(height_fraction, 0.07, 0.14, 0.6, 1.0)), 0.8);

    float in_scatter_probability = depth_probability * vertical_probability;
    return in_scatter_probability;
}

float GetDirectScatterProbability(float CosTheta, float eccentricity, float silverIntensity, float silverSpread){
    return max(hgPhase1(CosTheta, eccentricity), silverIntensity * hgPhase1(CosTheta, (0.99 - silverSpread)));
}

vec3 sunLuminance(vec3 pos, float VoL, float iVoL, float opticalDepth, float extinction){
    float lightPathOpticalDepth = computeLightPathOpticalDepth(pos, lightWorldDir, 20.0, 6);
    float attenuation = GetAttenuationProbability(lightPathOpticalDepth, VoL, 0.25, 0.1, 0.7);

    float upPathOpticalDepth = computeLightPathOpticalDepth(pos, upWorldDir, 50.0, 2);
    float upPathAttenuation = GetAttenuationProbability(upPathOpticalDepth, VoL, 0.25, 0.1, 0.7);

    float downPathOpticalDepth = computeLightPathOpticalDepth(pos, vec3(0.0, -1.0, 0.0), 50.0, 2);
    float downPathAttenuation = GetAttenuationProbability(downPathOpticalDepth, VoL, 0.25, 0.1, 0.7);

    float phase = GetDirectScatterProbability(VoL, 0.1, 0.6, 0.24);
    float phase1 = GetDirectScatterProbability(iVoL, 0.3, 0.0, 0.0) * 0.5;
    phase = max(phase, phase1);

    vec3 luminance = sunColor * attenuation * phase;
    luminance += skyColor * upPathAttenuation / _2PI;
    luminance += skyColor * downPathAttenuation / _2PI;

    float inScatter = GetInScatterProbability(pos, extinction * 40.0);
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
    int N_SAMPLES = int(remapSaturate(verticalness, 0.0, 1.0, 20, 12));
    #ifdef SKY_BOX
        N_SAMPLES = 6;
    #endif

    float rayLength = stepDis.y;
    float stepSize = rayLength / float(N_SAMPLES);

    vec3 oriStartPos = startPos;
    startPos += worldDir * stepDis.x;
    startPos += worldDir * stepSize * temporalBayer64(gl_FragCoord.xy);

    vec3 hitPos = startPos;
    bool isHit = false;

    for(int i = 0; i < N_SAMPLES; i++){
        float t = float(i) * stepSize;
        if(stepDis.x + t > CLOUD_MAX_DISTANCE || t >= rayLength || intScattTrans.a < 0.05){
            break;
        }
        
        vec3 pos = startPos + t * worldDir;
        float extinction = sampleCloudDensity(pos, false);
        
        if(extinction > 0.0001){
            if(!isHit){
                hitPos = pos;
                isHit = true;
            }

            float opticalDepth = stepSize * extinction;
            float transmittance = GetAttenuationProbability(opticalDepth);
            
            vec3 luminance = sunLuminance(pos, VoL, iVoL, opticalDepth, extinction);

            intScattTrans.rgb += intScattTrans.a * (luminance - luminance * transmittance) / max(extinction, 1e-5);
            intScattTrans.a *= transmittance;
        }
    }
    intScattTrans.rgb *= 4.5 * (1.0 - 0.66 * isNight);
    cloudHitLength = length(hitPos - oriStartPos);

    // if(isHit){
    //     intScattTrans.rgb *= Transmittance1(earthPos, earthPos + worldDir * cloudHitLength, 3.0);
    // }
}

float computeCrepuscularLight(vec4 viewPos){
    const float N_SAMPLES = 4.0;

    vec2 uv = texcoord;
    vec2 sunUv = viewPosToScreenPos(vec4(sunPosition, 1.0)).xy;

    vec2 delta = (uv - sunUv) * (1.0 / float(N_SAMPLES));
    vec2 sampleUv = uv;
    sampleUv += temporalBayer64(gl_FragCoord.xy) * delta;

    float sum = 0.0;
    int c = 0;
    float VoL = mix(1.0, dot(normalize(vec3(0.0, 0.0, -1.0)), sunViewDir), 0.5);
    for (int i = 0; i < N_SAMPLES; ++i) {
        sampleUv -= delta;
        if (outScreen(sampleUv) || texture(depthtex1, sampleUv).r < 1.0)
            break;

        float transmit = texture(colortex1, sampleUv * 0.5 + vec2(0.5, 0.0)).a;
        sum += transmit;
        ++c;
    }
    sum /= N_SAMPLES;

    return saturate(sum * VoL);
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
        weight *= pre.a < 1.0 ? 0.0 : 1.0;

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
#endif