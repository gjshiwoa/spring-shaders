#if defined FSH && defined CPS
void waterFog(inout vec3 transmittance, inout vec3 scattering, vec4 startPos, vec4 endPos){
    const float N_SAMPLES = 5.0;

    vec3 s = endPos.xyz - startPos.xyz;
    vec3 stepDir = normalize(s);
    float ds = length(s) / N_SAMPLES;
    vec3 dStep = ds * stepDir;
    startPos.xyz += temporalBayer64(texcoord) * dStep * 1.0;

    vec3 coe = vec3(0.1, 0.85, 0.9) * 1.0;

    for(int i = 0; i < N_SAMPLES; i++){
        vec3 transmittance = fastExp(-coe * ds * i);

        vec3 p = startPos.xyz + i * dStep;
        float visbility = 1.0;
        if(length(p) < shadowDistance){
            vec3 shadowPos = getShadowPos(vec4(p, 1.0)).xyz;
            float z_sample = textureLod(shadowtex1, shadowPos.xy, 0).r;
            visbility = z_sample > shadowPos.z ? 1.0 : 0.0;
        }
        
        float dP2Surface = max(0.0, intersectHorizontalPlane(p, lightWorldDir, startPos.y));
        vec3 lightPathOpticalDepth = (dP2Surface + 10 * (1 - visbility)) * coe;
        vec3 t1 = fastExp(-lightPathOpticalDepth);

        float cosTheta = dot(stepDir, lightWorldDir);
        float phase = hgPhase(cosTheta, 0.1);
        
        scattering += sunColor * t1 *  coe * phase * transmittance * 0.1 * ds;
    }
}

vec3 underWaterFog(vec3 worldDir, float worldDis){
    const float numCount = UNDERWATER_FOG_SAMPLES;
    float waterFogDist = UNDERWATER_FOG_DIST;
    float stepSize = waterFogDist / numCount;
    float stepSum = numCount * stepSize;
    vec3 stepVec = stepSize * worldDir;

    float density = 0.0;
    vec3 p = stepVec * temporalBayer64(gl_FragCoord.xy);
    float trans = 1.0;
    float coe = 0.1;
    for(int i = 0; i < numCount; ++i){
        if(length(p) > worldDis) break;

        vec3 shadowPos = getShadowPos(vec4(p, 1.0)).xyz;
        float z_sample = textureLod(shadowtex1, shadowPos.st, 0).r;
        if(shadowPos.z < z_sample){
            float caustics = fastPow(textureLod(shadowcolor0, shadowPos.st, 0).g, 5);
            density += caustics * trans;
            trans *= exp(-stepSize * coe);
        }
        
        p += stepVec;
    }

    float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
    vec3 scattering = mix(vec3(0.2, 0.6, 0.9), vec3(density * UNDERWATER_FOG_LIGHT_BRI) * waterFogColor, 0.5);

    float phase0 = hgPhase1(dot(sunWorldDir, worldDir), 0.15);
    float phase1 = hgPhase1(dot(sunWorldDir, worldDir), 0.75) * 0.2;
    float phase = phase0 + phase1;

    vec3 underWaterFogColor = UNDERWATER_FOG_BRI 
                            * scattering * phase * coe * stepSize 
                            * sunColor * mix(1.0, eyeBrightness, 0.9);

    return vec3(underWaterFogColor);
}

vec3 radialBlur_underWaterFog(){
    vec3 centerCol = texture(colortex1, texcoord).rgb;
    // return centerCol;
    // float centerDepth  = texture(depthtex0, texcoord).r;
    // vec3 centerNormal = getNormalH(texcoord);

    vec3 sd = viewPosToScreenPos(vec4(sunViewDir, 0.0)).xyz;
    vec2 dir = normalize(sd.xy);

    int N_SAMPLES = 8;
    vec3 accum = vec3(0.0);
    float wsum = 0.0;
    vec2 dStep = 3.141 * dir * max(invViewSize.x, invViewSize.y);

    for(int i = 0; i < N_SAMPLES; ++i){
        vec2 sampleUV = texcoord + dStep * float(i);

        if (outScreen(sampleUV)) {
            continue;
        }

        vec3 sampleCol = texture(colortex1, sampleUV).rgb;

        float radialWeight = 1.0;
        float w = radialWeight;
        accum += sampleCol * w;
        wsum += w;
    }

    vec3 blurred = accum / max(wsum, 0.001);

    return max(blurred, vec3(0.0));
}

vec4 getUnderWaterFog(float depth, vec3 normal){
    // return catmullRom(colortex1, texcoord * 0.5);
    ivec2 uv = ivec2(gl_FragCoord.xy * 0.5 + vec2(0.0, 0.5 * viewSize.y));
    float w_max = 0.0;
    ivec2 uv_closet = uv;

    float z = linearizeDepth(depth);

    for(int i = 0; i < 5; i++){
        float weight = 1.0;
        ivec2 offset = ivec2(offsetUV5[i]);
        ivec2 curUV = uv + offset;
        if(outScreen((curUV * invViewSize) * 2.0 - vec2(0.0, 1.0))) continue;

        vec4 curData = texelFetch(colortex6, curUV, 0);
        weight *= max(0.0f, mix(1.0, dot(unpackNormal(curData.r), normal), 2.0));

        float curZ = linearizeDepth(curData.g);
        weight *= saturate(1.0 - abs(curZ - z) * 2.0);

        if(weight > w_max){
            w_max = weight;
            uv_closet = curUV;
        }
    }
    vec4 waterFog = texelFetch(colortex3, uv_closet, 0);
    return waterFog;
}
#endif