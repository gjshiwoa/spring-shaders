float screenSpaceShadow(vec3 viewPos, vec3 normal, float shadowMappingResult){
    if (shadowMappingResult < 0.01) return 0.0;

    float N_SAMPLE = SCREEN_SPACE_SHADOW_SAMPLES;
    float dist = length(viewPos);

    vec3 startPos = viewPos;
    vec3 rayDir = lightViewDir;
    float rayLength = remapSaturate(dist, 5.0, shadowDistance, 0.2, 10.0);

    const float STEP_GROWTH_BASE = 1.5;

    float g = STEP_GROWTH_BASE;

    float baseStep;
    if (abs(g - 1.0) < 1e-5) {
        baseStep = rayLength / N_SAMPLE;
    } else {
        float gPowN = pow(g, N_SAMPLE);
        baseStep = rayLength * (g - 1.0) / (gPowN - 1.0);
    }

    float curStep = baseStep;
    float cumDist = 0.0;

    float jitter = temporalBayer64(gl_FragCoord.xy);
    startPos += remapSaturate(dist, 5.0, shadowDistance, 0.01, 0.1) * rayDir;
    startPos += remapSaturate(dist, 5.0, shadowDistance, 0.01, 0.1) * normal;

    float shadow = 0.0;
    for (int i = 0; i < int(N_SAMPLE); ++i) {
        cumDist += curStep;
        float adjustedDist = cumDist - jitter * curStep;
        vec3 p = startPos + adjustedDist * rayDir;

        vec3 p_screen = viewPosToScreenPos(vec4(p, 1.0)).xyz;
        p_screen.xy += 0.5 * Halton_2_3[framemod8] * invViewSize * TAA_JITTER_AMOUNT;

        if (outScreen(p_screen)) break;

        float z_sample;
        #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
            if (dhTerrain < 0.5) {
                z_sample = texture(depthtex1, p_screen.xy).r;
            } else {
                float z_sampleDH = texture(dhDepthTex0, p_screen.xy).r;
                vec4 viewPosDH = screenPosToViewPosDH(vec4(p_screen.xy, z_sampleDH, 1.0));
                z_sample = viewPosToScreenPos(viewPosDH).z;
            }
        #else
            z_sample = texture(depthtex1, p_screen.xy).r;
        #endif

        vec4 posSample = screenPosToViewPos(vec4(p_screen.xy, z_sample, 1.0));
        float disSample = length(posSample.xyz);
        float disP = length(p);
        float disP_S = distance(posSample.xyz, p);

        if (disSample < disP && 
            disP_S < remapSaturate(pow(dist / shadowDistance, 4.0), 5.0 / shadowDistance, 1.0, 0.1, 20.0)) {
            shadow = 1.0;
            break;
        }

        curStep *= g;
    }

    shadow = 1.0 - saturate(shadow);
    return saturate(shadow);
}
