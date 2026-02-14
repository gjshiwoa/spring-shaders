const vec2 cloudHeightEnd = vec2(-600.0, 4800.0);

float sampleCloudDensityLow(vec3 cameraPos, float height_fraction){
    vec4 weatherData = texture(noisetex, cameraPos.xz * 0.00004 + vec2(0.17325, 0.17325));
    float coverage = saturate(mix(weatherData.r, weatherData.g, 0.33));
    coverage = pow(coverage, remapSaturate(height_fraction, 0.1, 0.75, 0.6, 1.45));
    coverage = saturate(1.0 - 0.65 * coverage - 0.3 * rainStrength + 0.05);

    vec3 curl = vec3(0.0);
    float curlNoise = weatherData.b * 2.0 - 1.0;
    curl.xy = vec2(100.0 * curlNoise);
    curl.z = 200.0 * curlNoise * height_fraction;
    cameraPos += curl;

    vec4 low_frequency_noise = texture(colortex8, cameraPos * 0.001 + vec3(0.0, 0.9, 0.0));
    float perlin3d = low_frequency_noise.r;
    vec3 worley3d = low_frequency_noise.gba;
    float worley3d_FBM = worley3d.g * 0.66 + worley3d.b * 0.33;
    float base_cloud = remapSaturate(perlin3d, - worley3d_FBM, 1.0, 0.0, 1.0);
    base_cloud = remapSaturate(base_cloud, coverage, 1.0, 0.0, 1.0);

    return base_cloud;
}

float sampleCloudDensityHigh(vec3 cameraPos, float base_cloud, float height_fraction, vec3 wind_direction){
    float final_cloud = base_cloud;

    vec4 high_frequency_noises = texture(colortex2, cameraPos * 0.0075 - 0.045 * wind_direction * frameTimeCounter);
    float high_freq_FBM = high_frequency_noises.g * 0.5 + high_frequency_noises.b * 0.25 + high_frequency_noises.a * 0.125;
    float high_freq_noise_modifier = lerp(high_freq_FBM, 1.0 - high_freq_FBM, saturate(height_fraction * 10.0));    
    final_cloud = remapSaturate(final_cloud, high_freq_noise_modifier * 0.5, 1.0, 0.0, 1.0);
    
    return final_cloud;
}

float sampleCloudDensity(vec3 cameraPos, bool doCheaply){
    float height_fraction = getHeightFractionForPoint(cameraPos.y, cloudHeightEnd);
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
    final_cloud *= 0.05;

    return saturate(final_cloud);
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
        currentStepSize = mix(initialStepSize, initialStepSize * 5.0, t);
        currentPos += lightWorldDir * currentStepSize;

        if(i > 0.66 * N_SAMPLES) doCheaply = true;
        float currentDensity = sampleCloudDensity(currentPos, doCheaply);
        opticalDepth += 0.5 * (prevDensity + currentDensity) * currentStepSize;
        prevDensity = currentDensity;
    }

    return opticalDepth;
}

float GetInScatterProbability(float height_fraction, float ds_loded, float attenuation, float VoL){
    attenuation = saturate(attenuation);
    ds_loded = saturate(ds_loded - 0.15 * attenuation);
    
    float height_factor = remapSaturate(height_fraction, 0.3, 0.85, 0.5, 2.0);
    float attenuation_factor = remapSaturate(attenuation, 0.0, 1.0, 0.1, 1.0);
    float angle_factor = remapSaturate(VoL, 0.6, 1.0, 1.0, 0.5);
    float depth_probability = 0.05 + pow(ds_loded, attenuation_factor * height_factor * angle_factor);

    float vertical_probability = pow(max(0.0, remap(height_fraction, 0.07, 0.14, 0.5, 1.0)), 0.8);

    float in_scatter_probability = depth_probability * vertical_probability;
    return in_scatter_probability;
}

float GetDirectScatterProbability(float CosTheta, float eccentricity, float silverIntensity, float silverSpread){
    return max(hgPhase1(CosTheta, eccentricity), silverIntensity * hgPhase1(CosTheta, (0.99 - silverSpread)));
}

vec3 sunLuminance(vec3 pos, float VoL, float iVoL, float extinction){
    float density = extinction / 0.05;
    float height_fraction = getHeightFractionForPoint(pos.y, cloudHeightEnd);
    
    float lightPathOpticalDepth = computeLightPathOpticalDepth(pos, lightWorldDir, 60.0, 3);
    float attenuation = GetAttenuationProbability(lightPathOpticalDepth, 0.15, 0.7);

    float phase = GetDirectScatterProbability(VoL, 0.1, 0.5, 0.3);
    float phase1 = GetDirectScatterProbability(iVoL, 0.3, 0.0, 0.0) * 0.6;
    phase = max(phase, phase1);

    float inScatter = GetInScatterProbability(height_fraction, density, attenuation, VoL);

    vec3 direct = 20.0 * endColor * attenuation * inScatter * phase;

    float height_factor = remapSaturate(pow(height_fraction, 0.8), 0.0, 1.0, 0.5, 1.0);
    float depth_factor = pow(saturate(1.0 - density), 1.5);
    vec3 ambient = 1.0 * endColor * depth_factor * height_factor;

    vec3 luminance = direct;

    luminance *= extinction;

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

    vec2 dis = intersectHorizontalAABB(startPos, worldDir, cloudHeightEnd);
    
    const float CLOUD_MAX_DISTANCE_END = 1200.0;

    vec2 stepDis = calculateStepDistances(dis.x, dis.y, CLOUD_MAX_DISTANCE_END);
    stepDis.y = min(stepDis.y, CLOUD_MAX_DISTANCE_END);
    if(stepDis.y < 0.0001 || stepDis.x > CLOUD_MAX_DISTANCE_END){
        return;
    }
    float verticalness = abs(dot(worldDir, upWorldDir));
    int N_SAMPLES = int(remap(verticalness, 0.0, 1.0, 18, 9));
    #ifdef SKY_BOX
        N_SAMPLES = int(N_SAMPLES * 0.5);
    #endif

    float rayLength = stepDis.y;
    float stepSize = rayLength / float(N_SAMPLES);

    vec3 oriStartPos = startPos;
    startPos += worldDir * max(stepDis.x, far);
    startPos += worldDir * stepSize * temporalBayer64(gl_FragCoord.xy);

    vec3 hitPos = startPos;
    bool isHit = false;

    for(int i = 0; i < N_SAMPLES; i++){
        float t = float(i) * stepSize;
        if(stepDis.x + t > CLOUD_MAX_DISTANCE_END || t >= rayLength || intScattTrans.a < 0.05){
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
            
            vec3 luminance = sunLuminance(pos, VoL, iVoL, extinction);

            intScattTrans.rgb += intScattTrans.a * (luminance - luminance * transmittance) / max(extinction, 1e-5);
            intScattTrans.a *= transmittance;
        }
    }
    intScattTrans.rgb *= vec3(0.9, 0.45, 0.65) * 0.2;
    cloudHitLength = length(hitPos - oriStartPos);

    // if(isHit){
    //     intScattTrans.rgb *= Transmittance1(earthPos, earthPos + worldDir * cloudHitLength, 3.0);
    // }
}

#endif


vec3 drawStars(vec3 worldDir){
    vec3 uv = worldDir;
    uv *= STARS_DENSITY * 1.25;
    vec3 ipos = floor(uv);
    vec3 fpos = fract(uv);
    vec3 targetPoint = rand3_3(ipos + sin(frameTimeCounter * 0.5) * 0.00005);

    float dist = length(fpos - targetPoint);
    float size = STARS_SIZE;
    float isStar = 1.0 - step(size, dist);

    return 0.45 * endColor * vec3(0.9, 0.45, 0.65) * isStar;
}

float fakeCaustics(vec3 pos){
    float height = 64.0;

    float cosUpSunpos = abs(dot(vec3(0.0,1.0,0.0), lightWorldDir));
    float hDiff = abs(height - pos.y);

    float hyp = hDiff * (1 / cosUpSunpos + 0.01);
    float dist = sqrt(hyp * hyp - hDiff * hDiff);

    vec3 unit = normalize(vec3(lightWorldDir.x, 0.0, lightWorldDir.z));
    vec3 offset = dist * unit;

    vec2 waveUV = vec2(0.0);
    if(pos.y < 64){
        waveUV = pos.xz + offset.xz;
    }else{
        waveUV = pos.xz - offset.xz;
    }
    
    float caustics  = texture(colortex8, vec3(waveUV * 0.03, 0.0) + frameTimeCounter * 0.075).g;


    return caustics;
}

vec3 underWaterFog(vec3 color, vec3 worldDir, float worldDis){
    const float numCount = 20.0;
    float stepSize = 6.0;
    float stepSum = numCount * stepSize;
    vec3 stepVec = stepSize * worldDir;

    float density = 0.0;
    int c = 0;
    vec3 p = stepVec * temporalBayer64(gl_FragCoord.xy);
    for(int i = 0; i < numCount; ++i){
        if(length(p) > worldDis) break;
		
		vec3 shadowPos = getShadowPos(vec4(p, 1.0)).xyz;
        float z_sample = textureLod(shadowtex1, shadowPos.st, 0).r;
        if(shadowPos.z < z_sample){
            float caustics = pow(fakeCaustics(p + cameraPosition), 5.0);
        	density += caustics;
        }
        ++c;
        p += stepVec;
    }
    density /= c + 0.01;
    // density = (density * min(worldDis, stepSum) + max(worldDis - stepSum, 0.0)) / worldDis;
    // float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
    density = mix(1.0, density * 15.0, 0.66);

    float phase0 = hgPhase1(dot(sunWorldDir, worldDir), 0.25);
    float phase1 = hgPhase1(dot(sunWorldDir, worldDir), 0.55) * 0.5;
    float phase = phase0 + phase1;

    vec3 underWaterFogColor = 1.0 * density * phase * endColor;
    color.rgb = mix(color, underWaterFogColor, 0.5 * pow(saturate(worldDis / 120.0), 1.0));

    // color += rand2_1(texcoord + sin(frameTimeCounter)) / 102.0;
    return vec3(color);
}