const vec3 upWorldDir = vec3(0.0, 1.0, 0.0);

vec4 screenPosToViewPosVX(vec4 screenPos){
    vec4 NDCPos = vec4(screenPos.xyz * 2.0 - 1.0, 1.0);
    vec4 clipPos = vxProjInv * NDCPos;
    return vec4(clipPos.xyz / clipPos.w, 1.0);
}

vec4 viewPosToWorldPos(vec4 viewPos){
    return gbufferModelViewInverse * viewPos;
}

#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/water/waterNormal.glsl"

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 gbufferData0;
layout(location = 2) out vec4 gbufferData1;

void voxy_emitFragment(VoxyFragmentParameters parameters){
    vec2 fragCoord = gl_FragCoord.xy * invViewSize;
    float vxDepth = gl_FragCoord.z;

    vec4 viewPos0 = screenPosToViewPosVX(vec4(fragCoord, vxDepth, 1.0));
    vec4 worldPos0 = viewPosToWorldPos(viewPos0);
    float worldDis0 = length(worldPos0.xyz);
    vec3 mcPos = worldPos0.xyz + cameraPosition;

    bool isWater = abs(parameters.customId - 8) < 0.5;

    vec4 color = vec4(0.0);

    vec3 normalW = normalize(vec3(uint((parameters.face>>1)==2), uint((parameters.face>>1)==0), 
                            uint((parameters.face>>1)==1)) * (float(int(parameters.face)&1)*2-1));
    vec3 normalV = mat3(vxModelView) * normalW;
    vec3 outNormal = normalV;

    if (isWater) {
        vec3 waveWorldNormal = getWaveNormalDH(mcPos.xz, WAVE_NORMAL_ITERATIONS, worldDis0);
        vec3 waveViewNormal = mat3(gbufferModelView) * waveWorldNormal;

        if(normalW.y > 0.9) outNormal = waveViewNormal;
        
        outColor = vec4(0.0, 0.0, 0.0, 0.97);
    } else {
        outColor = parameters.sampledColour * parameters.tinting;
        outColor.a = clamp(outColor.a, 0.01, 0.95);
    }

    gbufferData0.rg = normalEncode(normalize(outNormal));
    gbufferData0.ba = normalEncode(normalize(normalV));
    gbufferData1.rg = parameters.lightMap;
}