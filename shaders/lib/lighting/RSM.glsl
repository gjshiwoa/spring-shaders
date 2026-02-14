// 感谢 Tahnass、GeForceLegend 提供的帮助
// Temporal 思路参考了 iterationT
vec3 RSM(vec4 p_worldPos, vec3 p_worldNormal, out vec3 mainDir){
    vec4 p_s_clip = shadowMVP * p_worldPos;
    vec3 p_s_ndc = p_s_clip.xyz / p_s_clip.w;

    vec3 p_s_normal = (shadowMVP * vec4(p_worldNormal, 0.0)).xyz;
    p_s_normal = normalize(p_s_normal);

    vec3 L = vec3(0.0); 
    int N_SAMPLES = int(remapSaturate(length(p_worldPos), 0.0, shadowDistance, RSM_MAX_SAMPLES, RSM_MIN_SAMPLES));
    const float radius = RSM_SEARCH_RADIUS * shadowMapScale / shadowMapResolution;

    float noise = temporalBayer64(gl_FragCoord.xy);
    float firstStep = noise;
    float firstAngle = noise * _2PI * 17.333333;
    
    vec2 curDir = vec2(sin(firstAngle), cos(firstAngle));
    
    float rotAngle = GOLDEN_ANGLE;
    float sinRot = sin(rotAngle);
    float cosRot = cos(rotAngle);
    mat2 rotMatrix = mat2(cosRot, -sinRot, sinRot, cosRot);

    float curStep = (firstStep + 0.1) / float(N_SAMPLES);
    float dStep = 1.0 / float(N_SAMPLES);

    for(int i = 0; i < N_SAMPLES; ++i){    
        vec2 offsetUV = curStep * curDir * radius;
        curDir = rotMatrix * curDir;
        curStep += dStep;

        vec3 q_s_ndc = vec3(p_s_ndc.xy + offsetUV, 1.0);
        vec2 sampleUV = shadowDistort(q_s_ndc.xy) * 0.5 + 0.5;
        vec2 sampleTexel = sampleUV * shadowMapResolution;

        q_s_ndc.z = texelFetch(shadowtex1, ivec2(sampleTexel), 0).r;

        if(outScreen(sampleUV) || q_s_ndc.z == 1.0) continue;

        q_s_ndc.z = q_s_ndc.z * 2.0 - 1.0;
        q_s_ndc.z = (q_s_ndc.z - 0.4) * 5.0;

        vec4 SC1 = texelFetch(shadowcolor1, ivec2(sampleTexel), 0);
        vec3 q_s_normal = SC1.xyz * 2.0 - 1.0;
        if(length(q_s_normal) < 0.01 || SC1.a < 0.01) continue;
        q_s_normal = (shadowProjection * vec4(q_s_normal, 0.0)).xyz;
        q_s_normal = normalize(q_s_normal);

        vec3 pq = q_s_ndc - p_s_ndc;
        vec3 pq_dir = normalize(pq);

        #if RSM_NORMAL_WEIGHT_TYPE == 0
            float PQoPN = max(0.0, dot(pq_dir, p_s_normal));
        #else
            float PQoPN = 0.7 * smoothstep(-0.4, 1.0, dot(pq_dir, p_s_normal));
        #endif
        if(PQoPN <= 0.01) continue;

        #if RSM_NORMAL_WEIGHT_TYPE == 0
            float QPoQN = max(0.0, dot(-pq_dir, q_s_normal));
        #else
            float QPoQN = 0.7 * smoothstep(-0.4, 1.0, dot(-pq_dir, q_s_normal));
        #endif
        if(QPoQN <= 0.01) continue;

        float q_lm_y = SC1.a;
        q_lm_y = smoothstep(0.0, 0.25, q_lm_y);

        float worldDis = saturate(length(p_worldPos.xyz) / shadowDistance);
        float dist = length((shadowProjectionInverse * vec4(pq, 0.0)).xyz) + 0.05;

        vec3 q_albedo = texelFetch(shadowcolor0, ivec2(sampleTexel), 0).rgb;
        toLinear(q_albedo);

        #if RSM_DIST_WEIGHT_TYPE == 0
            dist *= dist;

            float a = (i + 1) * dStep;
            float a2 = a * a;
            float b = i * dStep;
            float b2 = b * b;
            float w_cur = (a2 - b2) * PI;
            w_cur = mix(PI / (N_SAMPLES * N_SAMPLES), w_cur, saturate(1.0 - worldDis));
        #else
            dist = 0.05 + pow(dist, 1.3);
            float w_cur = PI / 5.0 / N_SAMPLES;
        #endif

        float weight = w_cur * q_lm_y * PQoPN * QPoQN / dist;
        L += q_albedo * weight;
        mainDir += pq_dir * weight;
    }

    mainDir = normalize(mainDir);
    vec3 rsmColor =  L * 384.0;
    rsmColor *= RSM_SEARCH_RADIUS * RSM_SEARCH_RADIUS / 57600.0;

    return rsmColor;
}

float estimateRsmLeakAO(vec3 mainDir, vec3 hrrViewPos){
    mainDir = normalize((shadowMVPInverse * vec4(mainDir, 0.0)).xyz);
    mainDir = normalize(mat3(gbufferModelView) * mainDir);

    const int   MAX_STEPS         = 7;
    const float STEP_SIZE         = 0.5;
    const float STEP_GROWTH_BASE  = 1.5;
    const float FALLOFF_SCALE     = 0.1;
    const float HIT_FALLOFF_SCALE = 0.1;
    const float JITTER_SCALE      = 1.0;
    const float MAX_JITTER        = 0.95;

    float jitter = clamp(temporalBayer64(gl_FragCoord.xy) * JITTER_SCALE, 0.0, MAX_JITTER);

    float cumUnjittered = 0.0;
    float curStep = STEP_SIZE;
    vec3 prevP = hrrViewPos;
    bool isHit = false;
    vec3 hitP = vec3(0.0);
    float dist_p_sdp = 0.0;

    for (int i = 0; i < MAX_STEPS; ++i) {
        cumUnjittered += curStep;

        float adjustedDist = cumUnjittered - jitter * curStep;
        vec3 p = hrrViewPos + mainDir * adjustedDist;

        vec3 sp = viewPosToScreenPos(vec4(p, 1.0)).xyz;

        if (outScreen(sp.xy)) {
            return 1.0;
        }

        float depth = texture(depthtex2, sp.xy).x;

        if (depth < sp.z) {
            isHit = true;
            hitP = p;
            vec3 sdp = screenPosToViewPos(vec4(sp.xy, depth, 1.0)).xyz;     // screen depth pos
            dist_p_sdp = distance(hitP, sdp);
            break;
        }

        prevP = p;

        curStep *= STEP_GROWTH_BASE;
    }

    if (isHit) {
        vec3 worldPos = viewPosToWorldPos(vec4(prevP, 1.0)).xyz;
        vec3 shadowPos = getShadowPos(vec4(worldPos, 1.0)).xyz;
        float psd = texture(shadowtex1, shadowPos.xy).r;

        if (psd < shadowPos.z + 0.00005) {
            float dist = distance(hitP, hrrViewPos);
            float rsmAO = 1.0 - saturate(1.0 / (1.0 + FALLOFF_SCALE * dist + HIT_FALLOFF_SCALE * dist_p_sdp));
            return saturate(rsmAO);
        }
    }

    return 1.0;
}

float estimateRsmLeakAO_voxel(vec3 mainDir, vec3 worldPos, vec3 normalW){
    mainDir = normalize((shadowMVPInverse * vec4(mainDir, 0.0)).xyz);
    float ao = 1.0;
    vec3 dir = mainDir;

    float noise = temporalBayer64(gl_FragCoord.xy);
    float stepSize = 1.0;
    vec3 stepVec = dir * stepSize;
    worldPos += stepVec * noise;
    worldPos += normalW * 0.05;
    const float N_SAMPLES = 10.0;

    for(int j = 1; j < N_SAMPLES; ++j){
        vec3 wp = worldPos + stepVec * float(j);
        ivec3 vp = relWorldToVoxelCoord(wp);
        vec4 sampleCol = texelFetch(customimg0, vp.xyz, 0);
        if(abs(sampleCol.a - 0.5) < 0.05){
            wp -= 0.9 * stepVec;
            vec3 shadowPos = getShadowPos(vec4(wp, 1.0)).xyz;
            float psd = texture(shadowtex1, shadowPos.xy).r;
            if (psd < shadowPos.z + 0.00005) ao = 0.0;
            break;
        }
    }

    return ao;
}

vec4 temporal_RSM(vec4 color_c){
    vec2 uv = texcoord * 2;
    vec2 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).rg;
    float z = cur.g;
    vec4 viewPos = screenPosToViewPos(vec4(uv, z, 1.0));
    vec3 prePos = getPrePos(viewPosToWorldPos(viewPos));

    prePos.xy = prePos.xy * 0.5 * viewSize - 0.5;
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;
    
    vec3 normal_c = unpackNormal(cur.r);
    float depth_c = linearizeDepth(prePos.z);
    float fDepth = fwidth(depth_c);

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen(curUV * 2 * invViewSize)) continue;

        vec2 pre = texelFetch(colortex6, ivec2(curUV + 0.5 * viewSize), 0).rg;
        float depth_p = linearizeDepth(pre.g);   

        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));
        float depthWeight = exp(-abs(depth_p - depth_c) / (1.0 + fDepth * 2.0 + depth_p / 2.0));
        float normalWeight = saturate(dot(normal_c, unpackNormal(pre.r)));

        weight *= depthWeight;
        weight *= normalWeight;
        
        c_s += texelFetch(colortex3, ivec2(curUV), 0) * weight;
        w_s += weight;
    }
    }

    vec4 blend = vec4(0.95, 0.95, 0.95, 0.9);
    color_c = mix(color_c, c_s, w_s * blend);

    return color_c;
}

vec4 JointBilateralFiltering_RSM_Horizontal(){
    // return texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
    
    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec2 curGD = texelFetch(colortex6, pix, 0).rg;
    vec3  normal0 = unpackNormal(curGD.r);
    float z0      = linearizeDepth(curGD.g);

    const float radius  = DENOISER_RADIUS;
    const float quality = DENOISER_QUALITY;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);

    for (float dx = -radius; dx <= radius + 0.001; dx += d) {
        ivec2 offset = ivec2(dx, 0.0);
        ivec2 p = pix + offset;

        if (outScreen(vec2(p) * 2.0 * invViewSize)) continue;

        vec2 gd = texelFetch(colortex6, p, 0).rg;
        vec3  n  = unpackNormal(gd.r);
        float z  = linearizeDepth(gd.g);

        float wN = saturate(dot(n, normal0));             // 法线权重
        float wZ = saturate(1.2 - abs(z - z0) * 1.0);      // 深度权重
        vec4 w  = vec4(wN * wZ);
        w.a = abs(dx) < 3.0 ? w.a : 0.0;

        vec4 col = texelFetch(colortex3, p, 0);
        cSum += col * w;
        wSum += w;
    }

    return cSum / max(vec4(1e-4), wSum);
}

vec4 JointBilateralFiltering_RSM_Vertical(){
    // return texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

    ivec2 pix = ivec2(gl_FragCoord.xy);
    vec2 curGD = texelFetch(colortex6, pix, 0).rg;
    vec3  normal0 = unpackNormal(curGD.r);
    float z0      = linearizeDepth(curGD.g);

    const float radius  = DENOISER_RADIUS;
    const float quality = DENOISER_QUALITY;
    float d = 2.0 * radius / quality;

    vec4 wSum = vec4(vec3(0.0), 0.0);
    vec4  cSum = vec4(0.0);

    for (float dy = -radius; dy <= radius + 0.001; dy += d) {
        ivec2 offset = ivec2(0.0, dy);
        ivec2 p = pix + offset;

        if (outScreen(vec2(p) * 2.0 * invViewSize + vec2(1.0, 1.0) * invViewSize)) continue;

        vec2 gd = texelFetch(colortex6, p, 0).rg;
        vec3  n  = unpackNormal(gd.r);
        float z  = linearizeDepth(gd.g);

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
        weight *= max(0.0f, mix(1.0, dot(unpackNormal(curData.r), normal), 2.0));

        float curZ = linearizeDepth(curData.g);
        weight *= saturate(1.0 - abs(curZ - z) * 2.0);

        if(weight > w_max){
            w_max = weight;
            uv_closet = curUV;
        }
    }
    // return catmullRom(colortex1, uv_closet * invViewSize);
    return texelFetch(colortex1, uv_closet, 0);
}


// vec4 JointBilateralFiltering_RSM(){
//     vec4 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
//     vec3 normal = cur.xyz;
//     float z = cur.a;
//     z = linearizeDepth(z);

//     const float radius = DENOISER_RADIUS;
// 	const float quality = DENOISER_QUALITY;
// 	float d = 2.0 * radius / quality;
    
//     float w_s = 0.0;
//     vec4 c_s = vec4(0.0);

//     for(float i = -radius; i <= radius + 0.1; i += d){
// 	for(float j = -radius; j <= radius + 0.1; j += d){    
//         ivec2 offset = ivec2(i, j);
//         ivec2 curUV = ivec2(gl_FragCoord.xy) + offset;
//         if(outScreen(curUV * 2 * invViewSize)) continue;
        
//         vec4 curData = texelFetch(colortex6, curUV, 0);
//         vec3 curNormal = curData.xyz;
//         float curZ = curData.a;
//         curZ = linearizeDepth(curZ);

//         float normalWeight = saturate(mix(1.0, dot(curNormal, normal), 1.0));
//         float depthWeight = saturate(1.2 - abs(curZ - z) * 1.0);
//         float weight = normalWeight * depthWeight;
//         // if(weight < 0.001) continue;

//         vec4 curColor = texelFetch(colortex1, curUV, 0);

//         c_s += curColor * weight;
//         w_s += weight;
//     }
//     }
//     if(w_s <= 0.001) return vec4(vec3(0.0), 1.0);
//     return c_s / max(w_s, 0.001);
// }
