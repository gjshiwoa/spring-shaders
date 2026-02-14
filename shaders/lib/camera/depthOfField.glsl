// 异次元的归来: 用Unity实现景深效果
// https://zhuanlan.zhihu.com/p/565511249

// 浊流: 游戏中的景深效果
// https://zhuanlan.zhihu.com/p/630570619

float calculateCoC(){
    // if(texture(depthtex0, vec2(0.5, 0.5)).r >= 0.99999) return 0.0;

    float depth = texture(depthtex0, texcoord).r;
    float linearDepth = min(far, linearizeDepth(depth));
    float focusDistance = min(far, linearizeDepth(centerDepthSmooth));

    float coc = (1.0 - focusDistance / linearDepth);

    // linearDepth /= far;
    // focusDistance /= far;
    // float dis = linearDepth - focusDistance;
    // float farCoC = saturate(dis / (dis + 1.0));
    // float nearCoC = remapSaturate(linearDepth, 0.0, focusDistance, -0.49, 0.0);
    // nearCoC = clamp(nearCoC / (nearCoC + 1.0), -1.0, 0.0);
    // coc = farCoC + nearCoC;
    // coc *= 2.0;

    coc = clamp(coc, -1.0, 1.0);
    
    return coc;
}

vec3 sampleWithKernel() {
    vec3 color = vec3(0.0);
    vec4 center = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0);
    float coc = center.a;
    float radius = saturate(abs(coc) - DOF_FOCUS_TOLERANCE) * DOF_BOKEH_RADIUS;
    if(radius < 1.0) return center.rgb;

    int N_SAMPLES = int(remapSaturate(radius * radius, 
            0.0, DOF_BOKEH_RADIUS * DOF_BOKEH_RADIUS, DOF_SAMPLES * 0.4, DOF_SAMPLES));

    float w_s = 0.0;

    float noise = temporalBayer64(gl_FragCoord.xy);
    float baseAngle = noise * _2PI * 17.3333;
    vec2 dir = vec2(cos(baseAngle), sin(baseAngle));
    vec2 rotStep = vec2(cos(GOLDEN_ANGLE), sin(GOLDEN_ANGLE));

    for (int k = 0; k < DOF_SAMPLES; k++) {
        float t = (float(k) + noise) / float(DOF_SAMPLES);
        float r = sqrt(t) * radius;
        vec2 offset = dir * r;
        vec4 curData = texture(colortex0, texcoord + offset * invViewSize);

        float curCoC = curData.a;
        float weight = 1.0;
        weight *= step(0.0, coc * curCoC);

        color += curData.rgb * weight;
        w_s += weight;

        dir = vec2(
            dir.x * rotStep.x - dir.y * rotStep.y,
            dir.x * rotStep.y + dir.y * rotStep.x
        );
    }
    
    color /= max(w_s, 0.01);
    return color;
}

vec3 tentFilter() {
    vec3 c_s = vec3(0.0);
    vec4 center = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0);
    float coc = center.a;
    float radius = 1.0;
    float w_s = 0.0;

    for(int i = 0; i < 4; i++){
        vec2 offset = tentOffsetUV[i] * invViewSize * radius;
        vec4 curData = texture(colortex1, texcoord + offset);

        float curCoC = curData.a;
        float weight = 1.0 - saturate(abs(coc - curCoC));

        c_s += curData.rgb * weight;
        w_s += weight;
    }
    c_s /= max(w_s, 0.01);

    return c_s;
}
