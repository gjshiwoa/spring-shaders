#ifdef FSH
void waterFog(inout vec3 transmittance, inout vec3 scattering, vec4 startPos, vec4 endPos){
    const float N_SAMPLES = 5.0;

    vec3 s = endPos.xyz - startPos.xyz;
    vec3 stepDir = normalize(s);
    float ds = length(s) / N_SAMPLES;
    vec3 dStep = ds * stepDir;
    startPos.xyz += temporalBayer64(gl_FragCoord.xy) * dStep * 1.0;

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

vec3 underWaterFog(vec3 color, vec3 worldDir, float worldDis){
    const float numCount = UNDERWATER_FOG_SAMPLES;
    float stepSize = UNDERWATER_FOG_STEP_SIZE;
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
            float caustics = fastPow(textureLod(shadowcolor0, shadowPos.st, 0).g, 5);
            density += caustics;
        }
        
        ++c;
        p += stepVec;
    }
    density /= c + 0.01;
    // density = (density * min(worldDis, stepSum) + max(worldDis - stepSum, 0.0)) / worldDis;
    float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
    density = mix(1.0, density * UNDERWATER_FOG_LIGHT_BRI, 0.66);

    float phase0 = hgPhase1(dot(sunWorldDir, worldDir), UNDERWATER_FOG_G);
    float phase1 = hgPhase1(dot(sunWorldDir, worldDir), UNDERWATER_FOG_G2) * UNDERWATER_FOG_G2_BRI;
    float phase = phase0 + phase1;

    vec3 underWaterFogColor = UNDERWATER_FOG_BRI * density * phase * waterFogColor * sunColor * mix(1.0, eyeBrightness, 0.9);
    color.rgb = mix(color, underWaterFogColor, pow(saturate(worldDis / UNDERWATER_FOG_MIST), 1.0));

    color += rand2_1(texcoord + sin(frameTimeCounter)) / 512.0;
    return vec3(color);
}
#endif