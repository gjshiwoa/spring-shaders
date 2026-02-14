float SSAO(vec3 viewPos, vec3 normal){
    float noise = rand2_1(texcoord + sin(frameTimeCounter));
    vec3 randomVec = rand2_3(texcoord + sin(frameTimeCounter)) * 2.0 - 1.0;

    vec3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    vec3 bitangent = normalize(cross(normal, tangent));
    mat3 TBN = mat3(tangent, bitangent, normal);

    float N_SAMPLES = remapSaturate(length(viewPos), 0.0, 120.0, SSAO_MAX_SAMPLES, SSAO_MIN_SAMPLES);
    const float radius = SSAO_SEARCH_RADIUS;

    float ao = 0.0;
    for(int i = 0; i < N_SAMPLES; ++i){
        vec3 offset = rand2_3(texcoord + sin(frameTimeCounter) + i);
        offset.xy = offset.xy * 2.0 - 1.0;
            float scale = float(i) / N_SAMPLES;
            scale = lerp(0.1, 1.0, scale * scale);
            offset *= scale;
        offset = TBN * offset;

        vec3 sampleViewPos = viewPos.xyz + offset * radius;
        vec3 sampleScreenPos = viewPosToScreenPos(vec4(sampleViewPos, 1.0)).xyz;
        float sampleDepth = texture(depthtex2, sampleScreenPos.xy).r;

        sampleDepth = linearizeDepth(sampleDepth);
        sampleScreenPos.z = linearizeDepth(sampleScreenPos.z);

        float nowAO = 0.0;
        if(sampleDepth < sampleScreenPos.z){
            float weight = 1.0;            

            float rangeCheck = smoothstep(0.0, 1.0, radius / (sampleScreenPos.z - sampleDepth));
            weight *= rangeCheck;
            
            if(outScreen(sampleScreenPos.xy))
                weight = 0.0;

            nowAO = 1.0 * weight;
        }
        ao += (1.0 - nowAO);
    }

    ao /= N_SAMPLES;
    ao = pow(ao, SSAO_INTENSITY);
    return saturate(ao);
}

float HBAO(vec3 viewPos, vec3 normal){
    const int N_SAMPLES = 64;
    float dist = length(viewPos);
    float radius = 0.75;

    float ao = 0.0;
    for(int i = 0; i < N_SAMPLES; ++i){
        float rand1 = rand2_1(texcoord + sin(frameTimeCounter) + i);
        float rand2 = rand2_1(texcoord + sin(frameTimeCounter) + i + vec2(17.33333));
        float angle = rand2 * _2PI;
        vec2 offsetUV = vec2(rand1 * sin(angle), rand1 * cos(angle)) * radius / dist;

        vec2 curUV = texcoord + offsetUV;
            
        float z = texture(depthtex2, curUV).r;
        vec3 curViewPos = screenPosToViewPos(vec4(curUV, z, 1.0)).xyz;
        
        vec3 vector = curViewPos - viewPos + normalize(viewPos) * 0.1;

        float cosTheta = dot(normal, normalize(vector));
        // float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
        // if(sign(cosTheta) < 0.0)
        //     sinTheta = 0.0;

        float weight = max(0.0, 1.0 - length(vector) / radius);

        if(outScreen(curUV)) weight = 0.0;

        ao += saturate(cosTheta) * weight;
    }
    ao /= N_SAMPLES;

    return saturate(1.0 - 10.0 * ao);
}

// Practical Real-Time Strategies for Accurate Indirect Occlusion
// https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
float GTAO(vec3 viewPos, vec3 normal, float dhTerrain){
    float rand = temporalBayer64(gl_FragCoord.xy);
    float dist = length(viewPos);
    const int sliceCount = GTAO_SLICE_COUNT;
    const int directionSampleCount = GTAO_DIRECTION_SAMPLE_COUNT;
    float scaling = GTAO_SEARCH_RADIUS / dist;
    
    float visibility = 0.0;
    viewPos += normal * 0.05;
    vec3 viewV = normalize(-viewPos);
    
    for (int slice = 0; slice < sliceCount; slice++) {
        float phi = (PI / float(sliceCount)) * (float(slice) + rand * 17.3333);
        vec2 omega = normalize(vec2(cos(phi), sin(phi)));
        vec3 directionV = vec3(omega.x, omega.y, 0.0);
        
        vec3 orthoDirectionV = directionV - dot(directionV, viewV) * viewV;
        vec3 axisV = cross(directionV, viewV);
        
        vec3 projNormalV = normal - axisV * dot(normal, axisV);
        
        float sgnN = sign(dot(orthoDirectionV, projNormalV));
        float cosN = saturate(dot(projNormalV, viewV) / max(length(projNormalV), 0.0001));
        float n = sgnN * acos(cosN);
        
        for (int side = 0; side <= 1; side++) {
            float cHorizonCos = -1.0;
            for (int samples = 0; samples < directionSampleCount; samples++) {
                float s = (float(samples) + 0.1 + rand) / float(directionSampleCount);
                
                vec2 offset = (2.0 * float(side) - 1.0) * s * scaling * omega;
                vec2 sampleUV = texcoord * 2.0 + offset;
                if(outScreen(sampleUV))
                    continue;
                
                float sampleDepth = texture(depthtex2, sampleUV).r;
                vec4 sampleScreenPos = vec4(sampleUV, sampleDepth, 1.0);
                vec3 sPosV = screenPosToViewPos(sampleScreenPos).xyz;

                #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
                    if(dhTerrain > 0.5){
                        float dhSampleDepth = texture(dhDepthTex0, sampleUV).r;
                        sPosV = screenPosToViewPosDH(vec4(sampleUV, dhSampleDepth, 1.0)).xyz;
                    }
                #endif
                
                vec3 sHorizonV = normalize(sPosV - viewPos);
                float horizonCos = dot(sHorizonV, viewV);
                horizonCos = mix(-1.0, horizonCos, (smoothstep(0.0, 1.0, GTAO_SEARCH_RADIUS * 1.41 / distance(sPosV, viewPos))));
                cHorizonCos = max(cHorizonCos, horizonCos);
            } 

            float h = n + clamp((2.0 * float(side) - 1.0) * acos(cHorizonCos) - n, -PI/2.0, PI/2.0);
            visibility += length(projNormalV) * (cosN + 2.0 * h * sin(n) - cos(2.0 * h - n)) / 4.0;
        }
    }
    visibility /= float(sliceCount);
    return pow(visibility, GTAO_INTENSITY);
}

vec3 AOMultiBounce(vec3 BaseColor, float ao){
	vec3 a =  2.0404 * BaseColor - 0.3324;
	vec3 b = -4.7951 * BaseColor + 0.6417;
	vec3 c =  2.7552 * BaseColor + 0.6903;
	return max(vec3(ao), (( ao * a + b) * ao + c) * ao);
}