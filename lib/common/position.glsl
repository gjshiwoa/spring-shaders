vec4 viewPosToScreenPos(vec4 viewPos){
    vec4 clipPos = gbufferProjection * viewPos;
    vec3 NDCPos = clipPos.xyz / clipPos.w;
    return vec4(NDCPos.xyz*0.5 + 0.5, 1.0);
}

vec4 screenPosToViewPos(vec4 screenPos){
    vec4 NDCPos = vec4(screenPos.xyz * 2.0 - 1.0, 1.0);
    vec4 clipPos = gbufferProjectionInverse * NDCPos;
    return vec4(clipPos.xyz / clipPos.w, 1.0);
}

#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
    vec4 screenPosToViewPosDH(vec4 screenPos){
        vec4 NDCPos = vec4(screenPos.xyz * 2.0 - 1.0, 1.0);
        vec4 clipPos = dhProjectionInverse * NDCPos;
        return vec4(clipPos.xyz / clipPos.w, 1.0);
    }
#endif

vec4 screenPosToViewPosVX(vec4 screenPos){
    vec4 NDCPos = vec4(screenPos.xyz * 2.0 - 1.0, 1.0);
    vec4 clipPos = vxProjInv * NDCPos;
    return vec4(clipPos.xyz / clipPos.w, 1.0);
}

vec4 viewPosToWorldPos(vec4 viewPos){
    return gbufferModelViewInverse * viewPos;
}

vec4 worldPosToViewPos(vec4 worldPos){
    return gbufferModelView * worldPos;
}



vec2 shadowDistort(vec2 sNDCPos){
    float sDist = length(sNDCPos.xy);
    float distortFactor = (1.0 - SHADOW_BIAS) + sDist * SHADOW_BIAS;
    return sNDCPos.xy / distortFactor;
}

float distort(float x, float b) {
    float c = exp(b) - 1.0;
    return log(c * x + 1.0) / log(c + 1.0);
}

vec2 shadowDistort1(vec2 ndcPos) {
    const float b = 4.0;
    vec2 signPos = sign(ndcPos);
    vec2 absPos = abs(ndcPos);
    vec2 distorted = vec2(distort(absPos.x, b), distort(absPos.y, b));
    return distorted * signPos;
}

vec4 getShadowPos(vec4 worldPos){
    vec4 sClipPos = shadowMVP * worldPos;
    vec4 sNDCPos = vec4(sClipPos.xyz / sClipPos.w, 1.0);
        sNDCPos.xy = shadowDistort(sNDCPos.xy);
        sNDCPos.z = mix(sNDCPos.z, 0.5, 0.8);
    vec4 sScreenPos = sNDCPos * 0.5 + 0.5;

    return sScreenPos;
}

vec4 shadowNDCPosToScreenPos(vec4 sNDCPos){
    float sDist = length(sNDCPos.xy);
    float distortFactor = (1.0 - SHADOW_BIAS) + sDist * SHADOW_BIAS;
    sNDCPos.xy /= distortFactor;
    sNDCPos.z = mix(sNDCPos.z, 0.5, 0.8);
    vec4 sScreenPos = sNDCPos * 0.5 + 0.5;

    return sScreenPos;
}



float exponentialDepth(float linDepth) {
    float z = (far + near - 2.0 * near * far / linDepth) / (far - near);
    return (z + 1.0) * 0.5;
}

float linearizeDepth(float expDepth) {
    float z = expDepth * 2.0 - 1.0;
    return (2.0 * near * far) / (far + near - z * (far - near));
    // return (near * far) / (expDepth * (near - far) + far);
}

float getLinearDepth(vec2 uv) {	
    float expDepth = texture(depthtex1, uv).r;
	return linearizeDepth(expDepth);
    // return (near * far) / (expDepth * (near - far) + far);
}



// 参考自 BSL
vec3 getPrePos(vec4 worldPos){
    vec3 cameraOffset = cameraPosition - previousCameraPosition;
    vec4 prePos = worldPos + vec4(cameraOffset, 0.0);
	prePos = gbufferPreviousModelView * prePos;
	prePos = gbufferPreviousProjection * prePos;
	return prePos.xyz / prePos.w * 0.5 + 0.5;
}

vec3 getClosestOffset(vec2 uv, float scale){
    float closestDepth = 1.0f;
    vec2 closestUV = uv;
    const vec2 offsetUV5[5] = vec2[](
        vec2(0.0, 0.0),
        vec2(1.0, 1.0),
        vec2(1.0, -1.0),
        vec2(-1.0, -1.0),
        vec2(-1.0, 1.0)
    );
    for(int i = 0; i < 5; i++){
        vec2 nowUV = uv + scale * invViewSize * offsetUV5[i];
        float nowDepth = texture(depthtex1, nowUV).r;

        float isCloser = step(nowDepth, closestDepth);
        closestUV = mix(closestUV, nowUV, isCloser);
        closestDepth = min(closestDepth, nowDepth);
    }
    return vec3(closestUV, closestDepth);
}

vec4 getClosestOffsetWithFarthest(vec2 uv, float scale){
    float closestDepth = 1.0f;
    float farthestDepth = 0.0f;
    vec2 closestUV = uv;
    const vec2 offsetUV5[9] = vec2[](
        vec2(0.0, 0.0),
        vec2(1.0, 1.0),
        vec2(1.0, -1.0),
        vec2(-1.0, -1.0),
        vec2(-1.0, 1.0),
        vec2(0.0, 1.0),
        vec2(0.0, -1.0),
        vec2(1.0, 0.0),
        vec2(-1.0, 0.0)
    );
    for(int i = 0; i < 9; i++){
        vec2 nowUV = uv + scale * invViewSize * offsetUV5[i];
        float nowDepth = texture(depthtex1, nowUV).r;

        float isCloser = step(nowDepth, closestDepth);
        closestUV = mix(closestUV, nowUV, isCloser);
        closestDepth = min(closestDepth, nowDepth);
        farthestDepth = max(farthestDepth, nowDepth);
    }
    return vec4(closestUV, closestDepth, farthestDepth);
}

#if !defined GBF && !defined SHD
vec2 getVelocity(){
    return texture(colortex9, getClosestOffset(texcoord.st, 1.0).st).rg;
}

vec2 getVelocity_R(){
    return texture(colortex9, texcoord).rg;
}
#endif