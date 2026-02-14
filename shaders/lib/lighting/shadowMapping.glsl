float simpleShadowMapping(vec4 worldPos){
    vec4 shadowPos = getShadowPos(worldPos);
    float shadow = texture(shadowtex0, vec3(shadowPos.xy, shadowPos.z - 0.0005)).r;

    return shadow;
}

float PenumbraMask(vec2 uv){
    if(outScreen(uv)) return 0.0;

    vec2 offset[4] = {
        vec2(-1.0, 1.0),
        vec2(1.0, 1.0),
        vec2(-1.0, -1.0),
        vec2(1.0, -1.0)
    };

    float shadow = 0.0;
    for(int i = 0; i < 4; i++){
        vec2 curUV = uv + offset[i] * invViewSize;
        float depth = texture(depthtex1, curUV).r;
        vec4 viewPos = screenPosToViewPos(vec4(unTAAJitter(curUV), depth, 1.0));
	    vec4 worldPos = viewPosToWorldPos(viewPos);

        float curShadow = simpleShadowMapping(worldPos);
        shadow += curShadow;
    }
    shadow *= 0.25;

    return (shadow < 1.0 && shadow > 0.0) ? 1.0 : 0.0;
    // return shadow;
}

float PenumbraMaskBlur(vec2 uv, vec2 dir){
    if(outScreen(uv * 4.0)) return 0.0;
    float depth1 = texture(depthtex1, uv * 4.0).r;
    vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(uv * 4.0), depth1, 1.0));
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	float worldDis1 = length(worldPos1);

    float r = 2.5;
    float scale = clamp(1.0 / (worldDis1 * 0.08), 1.0, 20.0);
    float PenumbraMaskBlur = 0.0;
    for(float i = -r; i < r + 0.1; i++){
        vec2 curUV = uv + i * dir * scale;
        PenumbraMaskBlur = max(PenumbraMaskBlur, textureLod(colortex1, curUV, log(scale)).r);
    }
    return step(0.001, PenumbraMaskBlur);
}


#ifdef FSH
float blockerSearch(sampler2D shadowMap, vec3 shadowPos, float radius, float quality){
    float c = 0.0;
    float blocker = 0.0;

    float radiusStep = radius;

    float noise = temporalBayer64(gl_FragCoord.xy);
    float firstAngle = noise * _2PI * 17.3333333;
    vec2 curDir = vec2(cos(firstAngle), sin(firstAngle));

    float rotAngle = GOLDEN_ANGLE;
    float sinRot = sin(rotAngle);
    float cosRot = cos(rotAngle);
    mat2 rotMatrix = mat2(cosRot, -sinRot, sinRot, cosRot);

    radius *= noise;

    for (int i = 0; i < quality; i++) {
        vec2 offset = curDir * pow(radius, 0.75);

        float dBlocker = textureLod(shadowMap, shadowPos.xy + offset / shadowMapResolution, 0.0).r;
        if(shadowPos.z > dBlocker){
            blocker += dBlocker;
            c++;
        }

        radius += radiusStep;
        curDir = rotMatrix * curDir;
    }
    if(c <= 0.8) return -1.0;

    return blocker / c;
}

float PCF(sampler2DShadow shadowMap, vec3 shadowPos, float radius, float quality){
    float c = 0.0;
    float shade = 0.0;

    float radiusStep = radius;

    float noise = temporalBayer64(gl_FragCoord.xy);
    float firstAngle = noise * _2PI * 17.3333333;
    vec2 curDir = vec2(cos(firstAngle), sin(firstAngle));

    float rotAngle = GOLDEN_ANGLE;
    float sinRot = sin(rotAngle);
    float cosRot = cos(rotAngle);
    mat2 rotMatrix = mat2(cosRot, -sinRot, sinRot, cosRot);

    radius *= noise;

    for (int i = 0; i < quality; i++) {
        vec2 offset = curDir * pow(radius, 0.75);

        shade += textureLod(shadowMap, vec3(shadowPos.xy + offset / shadowMapResolution, shadowPos.z), 0.0).r;
        c++;

        radius += radiusStep;
        curDir = rotMatrix * curDir;
    }

    return shade / c;
}
#endif

#ifndef GBF
float shadowMapping(vec4 worldPos, vec3 normal, float sssWrap){
    #ifndef DISTANT_HORIZONS
        if(skyB > 0.5) return 1.0;
    #endif

    float worldDis = length(worldPos.xyz);
    vec4 shadowPos = getShadowPos(worldPos);

    float dReceiver = shadowPos.z;
    float dBlocker = blockerSearch(shadowtex1, shadowPos.xyz, 4 * shadowMapScale, BLOCKER_SEARCH_SAMPLES);
    float penumbra = max(0.0, 100 * (dReceiver - dBlocker) / dBlocker);

    float disFactor = saturate(worldDis / shadowDistance);
    float dirFactor = abs(dot(normal, lightWorldDir));

    float offset = 0.05;
    if(plants < 0.5) {
        offset = 0.05 + 1.0 * disFactor * (1 - dirFactor);
    }
    worldPos.xyz += normal * offset;
    shadowPos = getShadowPos(worldPos);

    penumbra += 0.5 * sssWrap;
    if(plants > 0.5){
        penumbra = 1.5;
    }
    shadowPos.z -= 0.00005;
    penumbra *= saturate(saturate(1.0 - disFactor) + 0.1);

    float shade = PCF(shadowtex0, shadowPos.xyz, (0.25 + penumbra + rainStrength) * shadowMapScale * SHADOW_SOFTNESS, SHADOW_SAMPLES);

    return saturate(shade);
}

vec3 getColorShadow(vec3 shadowPos, float shadow){  
    const float N_SAMPLE = COLOR_SHADOW_SAMPLES;

    vec3 colorShadow = vec3(0.0);

    if(shadow < 0.9){
        // 每次循环跨越的距离
        float radiusStep = 0.5;
        // 设置起点（初始角度，距离），应用noise
        float noise = temporalBayer64(gl_FragCoord.xy);
        float firstAngle = noise * _2PI * 13.333333;
        float radius = radiusStep * noise;

        for (int i = 0; i < N_SAMPLE; i++) {
            float angle = firstAngle + rotationArray[i];
            vec2 offset = vec2(cos(angle), sin(angle)) * pow(radius, 0.75);
            vec2 uv = shadowPos.xy + offset / shadowMapResolution;

            vec4 SC1 = textureLod(shadowcolor1, uv, 0);
            SC1.rgb = SC1.rgb * 2.0 - 1.0;
            bool isTranslucent = length(SC1.rgb) < 0.1;
            if(!isTranslucent) {
                radius += radiusStep;
                continue;
            }

            float z_sample = textureLod(shadowtex1, uv, 0).r;
            if(shadowPos.z - 0.0001 > z_sample){
                radius += radiusStep;
                continue;
            }

            vec4 SC0 = textureLod(shadowcolor0, uv, 0);
            colorShadow += toLinearR(SC0.rgb);

            radius += radiusStep;
        }
    }
    return colorShadow / N_SAMPLE;
}
#endif




float Chebychev(float t, float mean, float variance){
    return variance / (variance + (t - mean) * (t - mean));
}

float variance(vec4 shadowPos, out float mean, out float meanX2){
    mean = textureLod(shadowcolor1, shadowPos.xy, 3).b;
    float mean2 = mean * mean;

    meanX2 = textureLod(shadowcolor1, shadowPos.xy, 3).a;

    return meanX2 - mean2;
}

float VSSM(vec4 worldPos){
    vec4 shadowPos = getShadowPos(worldPos);
    float mean = textureLod(shadowcolor1, shadowPos.xy, 3).b;
    float meanX2 = textureLod(shadowcolor1, shadowPos.xy, 3).a;
    float variance = meanX2 - mean * mean;
    
    float t = shadowPos.z;
    float N1 = Chebychev(t, mean, variance);
    float N2 = 1.0 - N1;
    float z_occ = (mean - N1 * t) / N2;

    float penumbra = 120 * (t - z_occ) / z_occ;

    float lod = log2(penumbra);
    mean = textureLod(shadowcolor1, shadowPos.xy, lod).b;
    meanX2 = textureLod(shadowcolor1, shadowPos.xy, lod).a;
    variance = meanX2 - mean * mean;

    return saturate(Chebychev(t, mean, variance));
}