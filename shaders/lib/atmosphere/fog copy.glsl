// 杨超wantnon: iq高度雾注解
// https://zhuanlan.zhihu.com/p/61138643

float fogVisibility(vec4 worldPos){
    float N_SAMPLE = VOLUME_LIGHT_SAMPLES;

    float dist = length(worldPos.xyz);
    dist = min(dist, shadowDistance);
    float ds = dist / N_SAMPLE;

    vec3 startPos = vec3(0.0);
    vec3 rayDir = normalize(worldPos.xyz);
    vec3 dStep = ds * rayDir;

    startPos += temporalBayer64(gl_FragCoord.xy) * dStep;

    float visibility = 0.0;
    for(int i = 0; i < N_SAMPLE; i++){
        vec3 p = startPos + i * dStep;
        p = getShadowPos(vec4(p, 1.0)).xyz;
        visibility += texture(shadowtex0, p).r;
    }
    visibility /= N_SAMPLE;

    return saturate(visibility);
}

float MiePhase_fog(float cos_theta, float g){
    float g2 = g * g;

    return (1 - g2) / (4.0 * PI * pow((1 + g2 - 2 * g * cos_theta), 3.0 / 2.0));
}

vec3 applyFog(vec3 oriColor, float worldDis, vec3 cameraPos, vec3 worldDir, float fogVis){
    vec3 rayOri_pie= cameraPos + worldDir * fog_startDis;

    vec2 data = vec2(-max(0, rayOri_pie.y - fog_startHeight) * fog_b, -max(0, worldDis - fog_startDis) * worldDir.y * fog_b);
    vec2 expData = fastExp(data);
    float opticalThickness = fog_a * mix(1.0, fogVis, 0.65) * expData.x * (1.0 - expData.y) / worldDir.y;
    float extinction = fastExp(-opticalThickness);
    float fogAmount = 1 - extinction;

    float cos_theta = dot(worldDir, lightWorldDir);

    vec3 fogColor = mix(skyColor * 3.0, 
                    sunColor * 0.45,
                    fogVis * MiePhase_fog(cos_theta, 0.45));

    // return oriColor + fogColor * fogAmount;
    return mix(oriColor, fogColor, fogAmount);
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

        float transmit = texture(colortex3, sampleUv * 0.5 + vec2(0.5, 0.0)).a;
        sum += transmit;
        ++c;
    }
    sum /= N_SAMPLES;

    return saturate(sum * VoL);
}

#ifdef PROGRAM_VLF
float sampleFogDensityLow(vec3 cameraPos, float height_fraction){
    vec4 weatherData = texture(noisetex, cameraPos.xz * 0.00045 + vec2(0.17325, 0.17325));
    float coverage = saturate(mix(weatherData.r, weatherData.g, 1.0));
    coverage = pow(coverage, remapSaturate(height_fraction, 0.1, 0.75, 0.6, 1.2));
    coverage = saturate(1.0 - 0.65 * coverage 
                        - 0.4 * saturate(rainStrength + 0.66 * isNightS + 0.66 * sunRiseSetS) 
                        + 0.15 * remapSaturate(pow(height_fraction, 0.8), 0.5, 1.0, 0.0, 1.0));

    cameraPos.y *= 1.33;

    vec4 low_frequency_noise = texture(colortex8, cameraPos * 0.0035 + vec3(0.0, 0.9, 0.0));
    float perlin3d = low_frequency_noise.r;
    vec3 worley3d = low_frequency_noise.gba;
    float worley3d_FBM = worley3d.g * 0.66 + worley3d.b * 0.33;
    float base = remapSaturate(perlin3d, - worley3d_FBM, 1.0, 0.0, 1.0);
    // base = worley3d_FBM;
    base = remapSaturate(base, coverage, 1.0, 0.0, 1.0);
    base = pow(saturate(base), 1.0);

    return base;
}

float sampleFogDensityHigh(vec3 cameraPos, float base, float height_fraction, vec3 wind_direction){
    float final = base;

    vec4 high_frequency_noises = texture(colortex2, cameraPos * 0.055 + 0.025 * wind_direction * frameTimeCounter);
    float high_freq_FBM = high_frequency_noises.r * 0.5 + high_frequency_noises.g * 0.25 + high_frequency_noises.b * 0.125;
    float high_freq_noise_modifier = lerp(high_freq_FBM, 1.0 - high_freq_FBM, saturate(height_fraction * 10.0));    
    final = remapSaturate(final, high_freq_noise_modifier * 0.5, 1.0, 0.0, 1.0);
    
    return final;
}

float sampleFogDensity(vec3 cameraPos, bool doCheaply){
    float height_fraction = getHeightFractionForPoint(cameraPos.y, fogHeight);
    if(height_fraction < 0.0 || height_fraction > 1.0) return 0.0;

    vec3 wind_direction = normalize(vec3(1.0, 0.0, 1.0));
    cameraPos += wind_direction * frameTimeCounter * 0.66;

    float base = sampleFogDensityLow(cameraPos, height_fraction);
    float final = base;
    if(!doCheaply){
        final = sampleFogDensityHigh(cameraPos, base, height_fraction, wind_direction);
    }

    final *= remapSaturate(height_fraction, 0.45, 1.0, 1.0, 0.0);
    final *= remapSaturate(height_fraction, 0.0, 0.2, 0.0, 1.0) * remapSaturate(height_fraction, 0.8, 1.0, 1.0, 0.0);

    return final;
}

float computeLightPathOpticalDepth_Fog(vec3 currentPos, vec3 lightWorldDir, float initialStepSize, int N_SAMPLES) {
    float opticalDepth = 0.0;
    bool doCheaply = false;
    float prevDensity = sampleFogDensity(currentPos, doCheaply);
    float currentStepSize = initialStepSize;

    for (int i = 1; i <= N_SAMPLES; i++) {
        float t = float(i) / float(N_SAMPLES);
        currentStepSize = mix(initialStepSize, initialStepSize * 5.0, t);
        currentPos += lightWorldDir * currentStepSize;

        // if(i > 0.5 * N_SAMPLES) doCheaply = true;
        float currentDensity = sampleFogDensity(currentPos, doCheaply);
        opticalDepth += 0.5 * (prevDensity + currentDensity) * currentStepSize;
        prevDensity = currentDensity;
    }

    return opticalDepth;
}

float GetAttenuationProbability_Fog(float sampleDensity, float secondSpread, float secondIntensity){
    return max(exp(-sampleDensity), (exp(-sampleDensity * secondSpread) * (secondIntensity)));
}

float GetInScatterProbability(float height_fraction, float density){
    float height_factor = remapSaturate(height_fraction, 0.3, 0.85, 0.25, 1.0);
    float depth_probability = 0.05 + pow(density, height_factor);

    float vertical_probability = pow(max(0.0, remap(height_fraction, 0.45, 1.0, 0.7, 1.0)), 0.8);

    return vertical_probability;
}

vec4 fogLuminance(inout vec4 intScattTrans, vec3 pos, vec3 oriStartPos, float stepSize, float density, float VoL, float iVoL, bool shadow){
    float attenuation = 1.0;
    vec4 worldPos = vec4(pos - oriStartPos, 1.0);
    float worldDis = length(worldPos.xyz);
    #if !defined NETHER
        if(shadow){
            vec4 shadowPos = getShadowPos(worldPos);
            float shade = 1.0;
            if(length(worldPos.xyz) < shadowDistance) shade = texture(shadowtex0, shadowPos.xyz).r;
            attenuation = mix(attenuation, shade, 1.0);
        }

        float stepSize_l = 10.0;
        float lightPathOpticalDepth = sampleFogDensity(pos + lightWorldDir * stepSize_l, true);
        float attenuation_lightPath = GetAttenuationProbability_Fog(lightPathOpticalDepth * fogSigmaE * stepSize_l * 10.0, 0.3, 0.4);
        attenuation = min(attenuation, attenuation_lightPath);
    #endif

    float height_fraction = getHeightFractionForPoint(pos.y, fogHeight);

    float phase = hgPhase1(VoL, 0.05);
    float phase1 = hgPhase1(VoL, 0.75) * 0.05;
    phase += phase1;

    float inScatter = GetInScatterProbability(height_fraction, density);

    // vec3 lightColor = mix(sunColor, skyColor * 8.0, saturate(0.05 + (1.0 - exp(-worldDis * FOG_SIGMA_S * 0.03))));
    vec3 lightColor = sunColor;
    vec3 direct = 8.0 * lightColor * attenuation * inScatter * phase;

    float height_factor = remapSaturate(pow(height_fraction, 1.5), 0.0, 1.0, 0.5, 1.0);
    float depth_factor = (1.0 - density);
    vec3 ambient = 4.0 * skyColor * depth_factor * height_factor * saturate(0.05 + saturate(eyeBrightnessSmooth.y / 240.0 - 0.33));

    vec3 luminance = direct + ambient;
    luminance *= FOG_SIGMA_S * density;

    float extinction = fogSigmaE * density;
    float opticalDepth = stepSize * extinction;
    float transmittance = exp(-opticalDepth);

    intScattTrans.rgb += intScattTrans.a * (luminance - luminance * transmittance) / max(extinction, 1e-5);
    intScattTrans.a *= transmittance;

    return intScattTrans;
}

vec4 volumtricFog(vec3 startPos, vec3 worldPos){
    vec4 intScattTrans = vec4(0.0, 0.0, 0.0, 1.0);
    // return intScattTrans;

    vec3 worldDir = normalize(worldPos);
    float worldDis = length(worldPos);
    float VoL = dot(worldDir, lightWorldDir);
    float iVoL = dot(worldDir, -lightWorldDir);

    vec2 dis = intersectHorizontalAABB(startPos, worldDir, fogHeight);
    vec2 stepDis = calculateStepDistances(dis.x, dis.y, worldDis);
    float fogMaxDistance = far;
    #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
        fogMaxDistance = dhRenderDistance;
    #endif
    stepDis.y = min(stepDis.y, fogMaxDistance);
    if(stepDis.y < 0.0001 || stepDis.x > fogMaxDistance){
        return intScattTrans;
    }

    float jitter = temporalBayer64(gl_FragCoord.xy);

    float tStart = stepDis.x;
    float tLen   = stepDis.y;
    float tEnd   = tStart + tLen;
    float boundary = shadowDistance;

    float nearEnd = min(tEnd, boundary);
    float nearLen = max(0.0, nearEnd - tStart);
    float farLen  = max(0.0, tEnd - nearEnd);

    const float NEAR_UNIT = 30.0;
    const float FAR_UNIT  = 120.0;

    int nNear = (nearLen > 0.01) ? int(ceil(nearLen / NEAR_UNIT)) : 0;
    int nFar  = (farLen  > 0.01) ? int(ceil(farLen  / FAR_UNIT))  : 0;

    vec3 oriStartPos = startPos;
    startPos += worldDir * tStart;

    if(nNear > 0.01){
        float stepSize = nearLen / float(nNear);
        vec3 stepVec = worldDir * stepSize;
        vec3 pos = startPos + jitter * stepVec;
        
        for(int i = 0; i < nNear; ++i){
            if(intScattTrans.a < 0.01 || distance(oriStartPos, pos) > stepDis.x + stepDis.y){
                break;
            }   
            float density = sampleFogDensity(pos, false);
            
            if(density > 0.05){
                intScattTrans = fogLuminance(intScattTrans, pos, oriStartPos, stepSize, density, VoL, iVoL, true);
            }
            pos += stepVec;
        }
    }

    startPos += nearLen * worldDir;

    if(nFar > 0.01){
        float stepSize = farLen / float(nFar);
        vec3 stepVec = worldDir * stepSize;
        vec3 pos = startPos + jitter * stepVec;

        for(int i = 0; i < nFar; ++i){
            if(intScattTrans.a < 0.01 || distance(oriStartPos, pos) > stepDis.x + stepDis.y){
                break;
            }
            float density = sampleFogDensity(pos, false);

            if(density > 0.05){
                intScattTrans = fogLuminance(intScattTrans, pos, oriStartPos, stepSize, density, VoL, iVoL, false);
            }
            pos += stepVec;
        }
    }
    intScattTrans.rgb *= (1.0 - isNightS * 0.65);
    return intScattTrans;
}


vec4 temporal_fog(vec4 color_c){
    vec2 uv = texcoord * 2 - vec2(0.0, 1.0);
    vec4 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
    float z = cur.g;
    vec4 viewPos = screenPosToViewPos(vec4(uv, z, 1.0));
    vec3 prePos = getPrePos(viewPosToWorldPos(viewPos));
    vec3 prePosO = prePos;

    prePos.xy = (prePos.xy * 0.5 + vec2(0.0, 0.5)) * viewSize - 0.5;
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;
    
    // vec3 normal_c = unpackNormal(cur.r);
    float depth_c = linearizeDepth(prePos.z);
    float fDepth = fwidth(depth_c);

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen((curUV * invViewSize) * 2.0 - vec2(0.0, 1.0))) continue;

        vec4 pre = texelFetch(colortex6, ivec2(curUV + vec2(0.5, -0.5) * viewSize), 0);
        float depth_p = linearizeDepth(pre.g);   

        vec4 c = texelFetch(colortex3, ivec2(curUV), 0);

        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));
        float depthWeight = exp(-abs(depth_p - depth_c) / (1.0 + fDepth * 2.0 + depth_p / 2.0));
        // float normalWeight = saturate(dot(normal_c, unpackNormal(pre.r)));

        if(isEyeInWater == 0){
            depthWeight = mix(1.0, depthWeight, mix(1.0, c.a, rainStrength));
            // normalWeight = mix(normalWeight, 1.0, c.a);
        }

        weight *= saturate(depthWeight);
        // weight *= saturate(normalWeight);

        c_s += c * weight;
        w_s += weight;
    }
    }

    vec4 blend = vec4(0.9);
    color_c = mix(color_c, c_s, w_s * blend);

    return color_c;
}

vec4 getFog(float depth){
    ivec2 uv = ivec2(gl_FragCoord.xy * 0.5 + vec2(0.0, 0.5 * viewSize.y));
    float w_max = 0.0;
    ivec2 uv_closet = uv;

    float z = linearizeDepth(depth);

    for(int i = 0; i < 5; i++){
        float weight = 1.0;
        ivec2 offset = ivec2(offsetUV5[i]);
        ivec2 curUV = uv + offset;
        if(outScreen((curUV * invViewSize) * 2.0 + vec2(0.0, -1.0) + vec2(1.0, -1.0) * invViewSize)) continue;

        vec4 curData = texelFetch(colortex6, curUV, 0);

        float curZ = linearizeDepth(curData.g);
        weight *= saturate(1.0 - abs(curZ - z) * 2.0);

        if(weight > w_max){
            w_max = weight;
            uv_closet = curUV;
        }
    }
    return texelFetch(colortex1, uv_closet, 0);
}

#endif