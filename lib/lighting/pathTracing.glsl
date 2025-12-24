vec3 coloredLight(vec3 worldPos, vec3 normalV, vec3 normalW){
    vec3 randomVec = rand2_3(texcoord + sin(frameTimeCounter)) * 2.0 - 1.0;

    vec3 tangent = normalize(randomVec - normalV * dot(randomVec, normalV));
    vec3 bitangent = normalize(cross(normalV, tangent));
    mat3 TBN = mat3(tangent, bitangent, normalV);

    vec3 color = vec3(0.0);
    const float DIR_SAMPLES = 4.0;
    for(int i = 0; i < DIR_SAMPLES; ++i){
        vec3 dir = rand2_3(texcoord + sin(frameTimeCounter) + i);
        dir.xy = dir.xy * 2.0 - 1.0;
        dir = normalize(TBN * dir);
        dir = normalize(viewPosToWorldPos(vec4(dir, 0.0)).xyz);

        float noise = temporalBayer64(gl_FragCoord.xy);
        float stepSize = 1.0;
        vec3 stepVec = dir * stepSize;
        ivec3 oriVp = relWorldToVoxelCoord(worldPos + normalW * 0.05);
        vec3 oriWp = worldPos;
        worldPos += stepVec * noise;
        worldPos += normalW * 0.05;
        const float N_SAMPLES = 8.0;

        for(int j = 0; j < N_SAMPLES; ++j){
            vec3 wp = worldPos + stepVec * float(j);
            ivec3 vp = relWorldToVoxelCoord(wp);
            vec4 sampleCol = texelFetch(customimg0, vp.xyz, 0);
            float dis = distance(vp, oriVp);
            if(abs(sampleCol.a - 0.5) < 0.05){
                float dis1 = distance(oriWp, wp) + 1.0;
                color += toLinearR(sampleCol.rgb) * saturate(dot(dir, normalW)) * 2.0;
                break;
            }
        }
    }

    return color / DIR_SAMPLES;
}

vec3 pathTracing(vec3 worldPos, vec3 normalV, vec3 normalW){
    vec3 randomVec = rand2_3(texcoord + sin(frameTimeCounter)) * 2.0 - 1.0;

    vec3 tangent = normalize(randomVec - normalV * dot(randomVec, normalV));
    vec3 bitangent = normalize(cross(normalV, tangent));
    mat3 TBN = mat3(tangent, bitangent, normalV);

    vec3 color = vec3(0.0);
    const float DIR_SAMPLES = 4.0;
    int isHit = 0;
    for(int i = 0; i < DIR_SAMPLES; ++i){
        vec3 dir = rand2_3(texcoord + sin(frameTimeCounter) + i);
        dir.xy = dir.xy * 2.0 - 1.0;
        dir = normalize(TBN * dir);
        dir = normalize(viewPosToWorldPos(vec4(dir, 0.0)).xyz);

        float noise = temporalBayer64(gl_FragCoord.xy);
        float stepSize = 1.0;
        vec3 stepVec = dir * stepSize;
        ivec3 oriVp = relWorldToVoxelCoord(worldPos + normalW * 0.05);
        vec3 oriWp = worldPos;
        worldPos += stepVec * noise;
        worldPos += normalW * 0.05;
        const float N_SAMPLES = 8.0;

        for(int j = 0; j < N_SAMPLES; ++j){
            vec3 wp = worldPos + stepVec * float(j);
            ivec3 vp = relWorldToVoxelCoord(wp);
            vec4 sampleCol = texelFetch(customimg0, vp.xyz, 0);
            float dis = distance(vp, oriVp);
            if(abs(sampleCol.a - 0.5) < 0.05){
                isHit++;
                float dis1 = distance(oriWp, wp) + 1.0;
                color += toLinearR(sampleCol.rgb) * saturate(dot(dir, normalW)) * 2.0;
                
                break;
            }
        }
    }

    return color / DIR_SAMPLES;
}