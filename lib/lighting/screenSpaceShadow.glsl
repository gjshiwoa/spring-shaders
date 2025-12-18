float screenSpaceShadow(vec3 viewPos, vec3 normal, float shadowMappingResult){
    if(shadowMappingResult < 0.01) return 0.0; 
    float N_SAMPLE = SCREEN_SPACE_SHADOW_SAMPLES;
    float dist = length(viewPos);

    vec3 startPos = viewPos;
    vec3 rayDir = lightViewDir;
    float rayLength = remapSaturate(dist, 0.0, shadowDistance, 0.2, 10.0);

    float ds = rayLength / N_SAMPLE;
    vec3 dStep = ds * rayDir;

    startPos += (temporalBayer64(gl_FragCoord.xy)) * dStep;
    startPos += remapSaturate(dist, 0.0, shadowDistance, 0.01, 0.5) * rayDir;

    float shadow = 0.0;
    for(int i = 0; i < N_SAMPLE; i++){
        vec3 p = startPos + i * dStep;

        vec3 p_screen = viewPosToScreenPos(vec4(p, 1.0)).xyz;
        p_screen.xy += 0.5 * Halton_2_3[framemod8] * invViewSize * TAA_JITTER_AMOUNT;

        if(outScreen(p_screen)) break;
  
        #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
            float z_sample;
            if(dhTerrain < 0.5){
                z_sample = texture(depthtex1, p_screen.xy).r;
            }else{
                float z_sampleDH = texture(dhDepthTex0, p_screen.xy).r;
                vec4 viewPosDH = screenPosToViewPosDH(vec4(p_screen.xy, z_sampleDH, 1.0));
                z_sample = viewPosToScreenPos(viewPosDH).z;
            }
        #else
            float z_sample = texture(depthtex1, p_screen.xy).r;
        #endif

        vec4 posSample = screenPosToViewPos(vec4(p_screen.xy, z_sample, 1.0));
        float disSample = length(posSample.xyz);
        float disP = length(p);
        float disP_S = distance(posSample.xyz, p);

        if(disSample < disP && disP_S < remapSaturate(dist, 5, shadowDistance, 0.1, 10.0)){
            shadow = 1.0; 
            break;
        }
    }
    // shadow = saturate(shadow / N_SAMPLE);
    shadow = 1.0 - saturate(shadow);
    return saturate(shadow);
}