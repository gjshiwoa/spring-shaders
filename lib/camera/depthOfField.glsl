// 异次元的归来: 用Unity实现景深效果
// https://zhuanlan.zhihu.com/p/565511249

float calculateCoC(){
    if(texture(depthtex0, vec2(0.5, 0.5)).r >= 0.99999) return 0.0;
    float depth = texture(depthtex0, texcoord).r;
    float linearDepth = min(far, linearizeDepth(depth));
    float focusDistance = min(far, linearizeDepth(centerDepthSmooth));
    float focusRange = focusDistance * DOF_FOCUSRANGE_DIST_FAC + DOF_FOCUSRANGE_BASE_DIST;
    float coc = (linearDepth - focusDistance) / focusRange;
    coc = clamp(coc, -1.0, 1.0);
    
    return fastPow(abs(coc), 1);
}

vec3 sampleWithKernel() {
    vec3 color = vec3(0.0);
    float coc = texture(colortex1, texcoord).r;
    float radius = coc * DOF_BOKEH_RADIUS;
    float w_s = 0.0;

    for (int k = 0; k < 16; k++) {
        vec2 offset = offsetUV16[k] * invViewSize * radius;
        #if DOF_BLUR_WEIGHT_MODE == 0
            float curCoC = texture(colortex1, texcoord + offset).r;
            float weight = 1.0 - saturate((coc - curCoC));
        #else
            float weight = 1.0;
        #endif
        color += texture(colortex0, texcoord + offset).rgb * weight;
        w_s += weight;
    }
    
    color /= max(w_s, 0.01);
    return color;
}

vec3 tentFilter(vec3 color) {
    vec3 c_s = vec3(0.0);
    float coc = texture(colortex1, texcoord).r;
    float radius = 1.0;
    float w_s = 0.0;

    for(int i = 0; i < 4; i++){
        vec2 offset = tentOffsetUV[i] * invViewSize * radius;
        #if DOF_BLUR_WEIGHT_MODE == 0
            float curCoC = texture(colortex1, texcoord + offset).r;
            float weight = 1.0 - saturate((coc - curCoC));
        #else
            float weight = 1.0;
        #endif
        c_s += texture(colortex0, texcoord + offset).rgb * weight;
        w_s += weight;
    }
    c_s /= max(w_s, 0.01);
    color = mix(color, c_s, coc);

    return color;
}