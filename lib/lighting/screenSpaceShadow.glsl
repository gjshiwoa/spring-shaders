float screenSpaceShadow(vec3 viewPos, vec3 normal, float shadowMappingResult){
    if(shadowMappingResult < 0.1) return 0.0; 
    float N_SAMPLE = SCREEN_SPACE_SHADOW_SAMPLES;

    float dist = length(viewPos);

    vec3 startPos = viewPos;
    vec3 rayDir = lightViewDir;
    float rayLength = dist / 60.0;
    float ds = rayLength / N_SAMPLE;
    vec3 dStep = ds * rayDir;

    startPos += temporalBayer64(gl_FragCoord.xy) * dStep;

    float shadow = 0.0;
    for(int i = 1; i < N_SAMPLE; i++){
        vec3 p = startPos + i * dStep;

        vec3 p_screen = viewPosToScreenPos(vec4(p, 1.0)).xyz;
        p_screen.xy += 0.5 * Halton_2_3[framemod8] * invViewSize * TAA_JITTER_AMOUNT;

        if(outScreen(p_screen)) break;
  
        #ifdef DISTANT_HORIZONS
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

        float offset = 0.05 * fastPow(1 - saturate(dot(normal, lightWorldDir)), 1);
        z_sample = linearizeDepth(z_sample) + offset;
        float z_p = linearizeDepth(p_screen.z);

        if(z_sample < z_p){
            float weight = step(0.0, rayLength - abs(z_p - z_sample));
            shadow += 1.0 * weight;
        }
    }

    shadow /= N_SAMPLE * 0.5 / rayLength;
    shadow = 1.0 - shadow;

    return saturate(shadow);
}