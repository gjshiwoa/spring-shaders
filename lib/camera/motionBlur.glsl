vec3 motionBlur(vec3 color) {
    vec2 uv = texcoord;
    vec2 delta = getVelocity();
    float dist = length(delta);
    bool isHand = texture(depthtex1, texcoord).r < 0.7;
    if(dist > MOTIONBLUR_THRESHOLD && !isHand){
        delta = normalize(delta);
        dist = min(dist, MOTIONBLUR_MAX) - MOTIONBLUR_THRESHOLD;
        dist *= MOTIONBLUR_STRENGTH;
        delta *= dist / float(MOTIONBLUR_SAMPLE);
        uv += delta * temporalBayer64(gl_FragCoord.xy);
        int sampleNum = 1;
        for(int i = 0; i < MOTIONBLUR_SAMPLE; i++){
            // uv += delta;
            if(outScreen(uv))
                break;
            color += texture2D(colortex0, uv).rgb;
            sampleNum++;
            uv += delta;
        }
        color /= float(sampleNum);
    }
    return color;
}