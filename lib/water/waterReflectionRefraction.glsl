#ifdef FSH
vec2 waterRefractionCoord(vec3 normalTex, vec3 worldNormal, float worldDis0){
    vec3 waterOriNormal = normalTex;
    worldNormal.xy -= waterOriNormal.xy;

    vec2 fragCoord = gl_FragCoord.xy * invViewSize;
    vec2 refractCoord = fragCoord - clamp(worldNormal.xy * WAVE_REFRACTION_INTENSITY / (worldDis0 + 0.0001), vec2(-1.0), vec2(1.0));
    if(outScreen(refractCoord)) 
        refractCoord = fragCoord;

    return refractCoord;
}
#include "/lib/atmosphere/octahedralMapping.glsl"

vec3 skyReflection(vec3 reflectWorldDir, vec3 worldPos){
    #ifndef GBF
        vec3 reflectSkyColor = texture(colortex7, directionToOctahedral(reflectWorldDir)).rgb;
    #else
        vec3 reflectSkyColor = texture(gaux4, directionToOctahedral(reflectWorldDir)).rgb;
    #endif

    return max(reflectSkyColor, vec3(0.0));
}

vec3 reflection(sampler2D tex, vec3 ViewPos, vec3 reflectWorldDir, vec3 reflectViewDir, 
                float lightmap, vec3 normalTex, float colorScale, inout int ssrTargetSampled){
    vec3 reflectColor = vec3(0.0);
    if(isEyeInWater == 0){
        reflectColor = skyReflection(reflectWorldDir, viewPosToWorldPos(vec4(ViewPos, 1.0)).xyz);

        reflectColor = reflectColor * lightmap;
        // reflectColor += drawCelestial(reflectWorldDir, 1.0);
    }

    float stepSize = REFLECTION_STEP_SIZE;
    vec3 stepVec = reflectViewDir * stepSize;

    vec3 waterOriNormal = normalTex;
    vec3 testPos = ViewPos;    
    #ifdef GBF
        testPos += waterOriNormal * 0.2; 
    #else
        testPos += waterOriNormal * clamp(length(ViewPos / 60.0), 0.01, 0.2); 
    #endif

    bool hit = false;
    vec3 testScreenPos;
    float noise = temporalBayer64(gl_FragCoord.xy);
    for(float i = 0.0; i < REFLECTION_SAMPLES; ++i){
        float powV = REFLECTION_STEP_POWER;
        vec3 ds = stepVec * pow(i + noise, powV);
        testPos += ds; 
        testScreenPos = viewPosToScreenPos(vec4(testPos, 1.0)).xyz;
        if(outScreen(testScreenPos.xyz)){
            return reflectColor;
        }

        // 初次碰撞
        float closest = texture(depthtex1, testScreenPos.xy).r;
        #ifdef DISTANT_HORIZONS
            float dhDepth = texture(dhDepthTex1, testScreenPos.xy).r;
            vec4 dhViewPos = screenPosToViewPosDH(vec4(testScreenPos.xy, dhDepth, 1.0));
            closest = min(closest, viewPosToScreenPos(dhViewPos).z);
        #endif
        if(testScreenPos.z > closest){
            hit = true;
            // 二分法精确碰撞位置
            float sig = -1.0;
            for(int j = 1; j <= 4; ++j){
                float n = pow(0.5, float(j));
                testPos = testPos + sig * n * ds;
                testScreenPos = viewPosToScreenPos(vec4(testPos, 1.0)).xyz;
                closest = texture(depthtex1, testScreenPos.xy).r;
                #ifdef DISTANT_HORIZONS
                    float dhDepth = texture(dhDepthTex1, testScreenPos.xy).r;
                    vec4 dhViewPos = screenPosToViewPosDH(vec4(testScreenPos.xy, dhDepth, 1.0));
                    closest = min(closest, viewPosToScreenPos(dhViewPos).z);
                #endif
                sig = sign(closest - testScreenPos.z);
            }
            // 根据阙值（碰撞点和测试点位置的差距）确定是否更新反射颜色
            vec3 newTestPos = screenPosToViewPos(vec4(vec3(testScreenPos.xy, closest), 1.0)).xyz;
            float zDiff = abs(testPos.z - newTestPos.z);
            if(zDiff > abs(ds.z)){
                break;
            }
            ssrTargetSampled = 1;
            reflectColor = textureLod(tex, testScreenPos.xy, 0).rgb * colorScale;
            break;
        }
    }
    if(!hit 
        #ifdef GBF
            && texture(depthtex1, testScreenPos.xy).r < 1.0
        #endif
    ){
        reflectColor = textureLod(tex, testScreenPos.xy, 0).rgb * colorScale;
    }

    return reflectColor;
}

vec3 getScatteredReflection(vec3 reflectDir, float roughness, vec3 normal) {
    if (roughness < 1e-6) {
        return normalize(reflectDir);
    }

    vec3 randVec = rand2_3(texcoord + sin(frameTimeCounter));
    
    vec3 tangent = normalize(cross(
        abs(reflectDir.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0), 
        reflectDir
    ));
    vec3 bitangent = cross(reflectDir, tangent);
    mat3 tbn = mat3(tangent, bitangent, reflectDir);

    float a = roughness * roughness;
    float phi = _2PI * randVec.x;
    
    float cosTheta = sqrt((1.0 - randVec.y) / (1.0 + (a*a - 1.0) * randVec.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    
    vec3 hemisphere = vec3(
        sinTheta * cos(phi),
        sinTheta * sin(phi),
        cosTheta
    );

    vec3 scatteredDir = tbn * hemisphere;

    return dot(scatteredDir, normal) > 0.0 
        ? normalize(scatteredDir)
        : reflect(scatteredDir, normal);
}

#ifndef GBF
vec3 temporal_Reflection(vec3 color_c, float r){
    vec2 uv = texcoord * 2;
    float z = texture(depthtex1, uv).r;
    vec4 screenPos = vec4(uv, z, 1.0);
    vec4 viewPos = screenPosToViewPos(screenPos);
    vec4 worldPos = viewPosToWorldPos(viewPos);
    vec3 prePos = getPrePos(worldPos);

    prePos.xy = prePos.xy * 0.5 * viewSize - vec2(0.5);
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;

    vec4 cur = textureLod(colortex6, texcoord, 0);
    vec3 normal_c = cur.xyz;
    float depth_c = linearizeDepth(prePos.z);
    float fDepth = fwidth(depth_c);

    float cameraDisplacementWeight = clamp(1.2 - length(cameraPosition - previousCameraPosition) * 20.0 / depth_c, 0.5, 1.0);

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen(curUV * 2 * invViewSize)) continue;

        vec4 pre = texelFetch(colortex6, ivec2(curUV + 0.5 * viewSize), 0);

        float depth_p = linearizeDepth(pre.a);   

        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));

        weight *= saturate(mix(1.0, dot(pre.xyz, normal_c), 1.0));
        weight *= saturate(1.2 - abs(depth_p - depth_c) / (1.0 + fDepth * 2.0));

        c_s += texelFetch(colortex3, ivec2(curUV + 0.5 * viewSize), 0) * weight;
        w_s += weight;
    }
    }

    color_c = mix(color_c.rgb, c_s.rgb, w_s * 0.95 * cameraDisplacementWeight);
    return color_c;
}

vec3 JointBilateralFiltering_Reflection(){
    // return texture(colortex1, texcoord).rgb;
    vec2 uv = texcoord * 2;
    
    vec4 cur = textureLod(colortex6, texcoord, 0);
    vec3 normal = cur.xyz;
    float z = cur.a;
    z = linearizeDepth(z);

    const float radius = 2.0;
	const float quality = 2.0;
	float d = 2.0 * radius / quality;
    
    float w_s = 0.0;
    vec3 c_s = vec3(0.0);

    for(float i = -radius; i <= radius + 0.1; i += d){
	for(float j = -radius; j <= radius + 0.1; j += d){    
        vec2 offset = vec2(i, j) * invViewSize;
        vec2 curUV = texcoord + offset;

        float weight = 1.0;
        if(outScreen(curUV * 2)) continue;

        vec4 curData = textureLod(colortex6, curUV, 0);

        vec3 curNormal = curData.xyz;
        weight *= max(0.0, mix(1.0, dot(curData.xyz, normal), 5.0));

        float curZ = curData.a;
        curZ = linearizeDepth(curZ);
        weight *= saturate(1.2 - abs(curZ - z) * 1.0);

        vec3 curColor = textureLod(colortex1, curUV, 0).rgb;

        c_s += curColor * weight;
        w_s += weight;
    }
    }
    if(w_s <= 0.001) return BLACK;
    return c_s / max(w_s, 0.001);
}

vec3 getReflectColor(float depth, vec3 normal){
    vec2 uv = texcoord * 0.5;
    float w_max = 0.0;
    vec2 uv_closet = uv;

    float z = linearizeDepth(depth);

    for(int i = 0; i < 5; i++){
        float weight = 1.0;
        vec2 offset = offsetUV5[i] * invViewSize;
        vec2 curUV = uv + offset;
        if(outScreen(curUV * 2)) weight = 0.0;

        vec4 curData = textureLod(colortex6, curUV, 0);
        weight *= max(0.0f, mix(1.0, dot(curData.xyz, normal), 2.0));

        float curZ = linearizeDepth(curData.a);
        weight *= saturate(1.0 - abs(curZ - z) * 2.0);

        if(weight > w_max){
            w_max = weight;
            uv_closet = curUV;
        }
    }

    return texture(colortex1, uv_closet).rgb;
}

#endif
#endif