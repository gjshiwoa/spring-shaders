// 感谢 Tahnass、GeForceLegend 提供的帮助
// Temporal 思路参考了 iterationT
vec3 RSM(vec4 p_worldPos, vec3 p_worldNormal){
    vec4 p_s_clip = shadowMVP * p_worldPos;
    vec3 p_s_ndc = p_s_clip.xyz / p_s_clip.w;

    vec3 p_s_normal = (shadowMVP * vec4(p_worldNormal, 0.0)).xyz;
    p_s_normal = normalize(p_s_normal);

    vec3 L = vec3(0.0); 
    int N_SAMPLES = int(remapSaturate(length(p_worldPos), 0.0, 120.0, RSM_MAX_SAMPLES, RSM_MIN_SAMPLES));
    const float radius = RSM_SEARCH_RADIUS * shadowMapScale / shadowMapResolution;
    // float w = 0.0;

    float noise = temporalBayer64(gl_FragCoord.xy);
    float firstStep = noise;
    float firstAngle = noise * _2PI * 17.333333;
    
    vec2 curDir = vec2(sin(firstAngle), cos(firstAngle));
    
    float rotAngle = GOLDEN_ANGLE;
    float sinRot = sin(rotAngle);
    float cosRot = cos(rotAngle);
    mat2 rotMatrix = mat2(cosRot, -sinRot, sinRot, cosRot);

    float curStep = firstStep / float(N_SAMPLES);
    float dStep = 1.0 / float(N_SAMPLES);

    for(int i = 0; i < N_SAMPLES; ++i){    
        vec2 offsetUV = curStep * curDir * radius;
        curDir = rotMatrix * curDir;
        curStep += dStep;

        vec3 q_s_ndc = vec3(p_s_ndc.xy + offsetUV, 1.0);
        vec2 sampleUV = shadowDistort1(q_s_ndc.xy) * 0.5 + 0.5;
        vec2 sampleTexel = sampleUV * shadowMapResolution;

        q_s_ndc.z = texelFetch(shadowtex1, ivec2(sampleTexel), 0).r;

        if(outScreen(sampleUV) || q_s_ndc.z == 1.0) continue;

        q_s_ndc.z = q_s_ndc.z * 2.0 - 1.0;
        q_s_ndc.z = (q_s_ndc.z - 0.4) * 5.0;

        vec4 SC1 = texelFetch(shadowcolor1, ivec2(sampleTexel), 0);
        vec3 q_s_normal = SC1.xyz;
        q_s_normal = (shadowProjection * vec4(q_s_normal, 0.0)).xyz;
        q_s_normal = normalize(q_s_normal);

        vec3 pq = q_s_ndc - p_s_ndc;
        vec3 pq_dir = normalize(pq);

        #if RSM_GEOMETRY_MODE == 0
            float PQoPN = max(0.0, dot(pq_dir, p_s_normal));
        #else
            float PQoPN = smoothstep(-0.4, 1.0, dot(pq_dir, p_s_normal));
        #endif
        if(PQoPN <= 0.0001) continue;

        #if RSM_GEOMETRY_MODE == 0
            float QPoQN = max(0.0, dot(-pq_dir, q_s_normal));
        #else
            float QPoQN = smoothstep(-0.4, 1.0, dot(-pq_dir, q_s_normal));
        #endif
        if(QPoQN <= 0.0001) continue;

        float q_lm_y = SC1.a;
        q_lm_y = smoothstep(0.0, 0.25, q_lm_y);
        // q_lm_y = 1.0;

        float dist = length((shadowProjectionInverse * vec4(pq, 0.0)).xyz) + 0.05;

        vec3 q_albedo = texelFetch(shadowcolor0, ivec2(sampleTexel), 0).rgb;
        toLinear(q_albedo);

        float a = (i + 1) * dStep;
        float a2 = a * a;
        float b = i * dStep;
        float b2 = b * b;
        float w_cur = (a2 - b2) * PI;
        L += w_cur * q_albedo * q_lm_y * PQoPN * QPoQN / (dist * dist + 0.05);
    }

    #if RSM_GEOMETRY_MODE == 0
        return L * 256.0 * 16 / N_SAMPLES;
    #else
        return L * 128.0 * 16 / N_SAMPLES;
    #endif
}

vec4 temporal_RSM(vec4 color_c){
    vec2 uv = texcoord * 2;
    vec4 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
    float z = cur.a;
    vec3 prePos = getPrePos(viewPosToWorldPos(screenPosToViewPos(vec4(uv, z, 1.0))));
    vec3 prePosO = prePos;

    prePos.xy = prePos.xy * 0.5 * viewSize - 0.5;
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;
    
    vec3 normal_c = cur.xyz;
    float depth_c = linearizeDepth(prePos.z);
    float fDepth = fwidth(depth_c);

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen(curUV * 2 * invViewSize)) continue;

        vec4 pre = texelFetch(colortex6, ivec2(curUV + 0.5 * viewSize), 0);
        float depth_p = linearizeDepth(pre.a);   

        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));
        // float depthWeight = saturate(1.2 - abs(depth_p - depth_c) / (1.0 + fDepth * 2.0 + depth_p / 10.0));
        float depthWeight = exp(-abs(depth_p - depth_c) / (1.0 + fDepth * 2.0 + depth_p / 2.0));
        weight *= depthWeight;
        weight *= saturate(step(0.5, dot(normal_c, pre.xyz)));
        
        c_s += texelFetch(colortex3, ivec2(curUV), 0) * weight;
        w_s += weight;
    }
    }

    vec4 blend = vec4(0.95, 0.95, 0.95, 0.90);
    color_c = mix(color_c, c_s, w_s * blend);

    return color_c;
}

vec4 JointBilateralFiltering_RSM(){
    vec4 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
    vec3 normal = cur.xyz;
    float z = cur.a;
    z = linearizeDepth(z);

    const float radius = DENOISER_RADIUS;
	const float quality = DENOISER_QUALITY;
	float d = 2.0 * radius / quality;
    
    float w_s = 0.0;
    vec4 c_s = vec4(0.0);

    for(float i = -radius; i <= radius + 0.1; i += d){
	for(float j = -radius; j <= radius + 0.1; j += d){    
        ivec2 offset = ivec2(i, j);
        ivec2 curUV = ivec2(gl_FragCoord.xy) + offset;
        if(outScreen(curUV * 2 * invViewSize)) continue;
        
        vec4 curData = texelFetch(colortex6, curUV, 0);
        vec3 curNormal = curData.xyz;
        float curZ = curData.a;
        curZ = linearizeDepth(curZ);

        float normalWeight = saturate(mix(1.0, dot(curNormal, normal), 1.0));
        float depthWeight = saturate(1.2 - abs(curZ - z) * 1.0);
        float weight = normalWeight * depthWeight;
        // if(weight < 0.001) continue;

        vec4 curColor = texelFetch(colortex1, curUV, 0);

        c_s += curColor * weight;
        w_s += weight;
    }
    }
    if(w_s <= 0.001) return vec4(vec3(0.0), 1.0);
    return c_s / max(w_s, 0.001);
}

vec4 JointBilateralFiltering_RSM_Horizontal(){
    // return texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
    
    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec4 curGD = texelFetch(colortex6, pix, 0);
    vec3  normal0 = curGD.xyz;
    float z0      = linearizeDepth(curGD.a);

    const float radius  = DENOISER_RADIUS;
    const float quality = DENOISER_QUALITY;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);

    for (float dx = -radius; dx <= radius + 0.001; dx += d) {
        ivec2 offset = ivec2(dx, 0.0);
        ivec2 p = pix + offset;

        if (outScreen(vec2(p) * 2.0 * invViewSize)) continue;

        vec4 gd = texelFetch(colortex6, p, 0);
        vec3  n  = gd.xyz;
        float z  = linearizeDepth(gd.a);

        float wN = saturate(dot(n, normal0));             // 法线权重
        float wZ = saturate(1.2 - abs(z - z0) * 1.0);      // 深度权重
        vec4 w  = vec4(wN * wZ);
        w.a = abs(dx) < 3.0 ? w.a : 0.0;

        vec4 col = texelFetch(colortex1, p, 0);
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec4(1e-4), wSum);
}

vec4 JointBilateralFiltering_RSM_Vertical(){
    // return texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec4 curGD = texelFetch(colortex6, pix, 0);
    vec3  normal0 = curGD.xyz;
    float z0      = linearizeDepth(curGD.a);

    const float radius  = DENOISER_RADIUS;
    const float quality = DENOISER_QUALITY;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);

    for (float dy = -radius; dy <= radius + 0.001; dy += d) {
        ivec2 offset = ivec2(0.0, dy);
        ivec2 p = pix + offset;

        if (outScreen(vec2(p) * 2.0 * invViewSize)) continue;

        vec4 gd = texelFetch(colortex6, p, 0);
        vec3  n  = gd.xyz;
        float z  = linearizeDepth(gd.a);

        float wN = saturate(dot(n, normal0));
        float wZ = saturate(1.2 - abs(z - z0) * 1.0);
        vec4 w  = vec4(wN * wZ);
        w.a = abs(dy) < 3.0 ? w.a : 0.0;

        vec4 col = texelFetch(colortex1, p, 0);
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec4(1e-4), wSum);
}

vec4 getGI(float depth, vec3 normal){
    // return catmullRom(colortex1, texcoord * 0.5);
    ivec2 uv = ivec2(gl_FragCoord.xy * 0.5);
    float w_max = 0.0;
    ivec2 uv_closet = uv;

    float z = linearizeDepth(depth);

    for(int i = 0; i < 5; i++){
        float weight = 1.0;
        ivec2 offset = ivec2(offsetUV5[i]);
        ivec2 curUV = uv + offset;
        if(outScreen(curUV * 2 * invViewSize)) continue;

        vec4 curData = texelFetch(colortex6, curUV, 0);
        weight *= max(0.0f, mix(1.0, dot(curData.xyz, normal), 2.0));

        float curZ = linearizeDepth(curData.a);
        weight *= saturate(1.0 - abs(curZ - z) * 2.0);

        if(weight > w_max){
            w_max = weight;
            uv_closet = curUV;
        }
    }
    // return catmullRom(colortex1, uv_closet * invViewSize);
    return texelFetch(colortex1, uv_closet, 0);
}