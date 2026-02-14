#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/common/normal.glsl"

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 gbufferData0;
layout(location = 2) out vec4 gbufferData1;
layout(location = 3) out vec4 gbufferData2;
layout(location = 4) out vec4 gbufferData3;

void voxy_emitFragment(VoxyFragmentParameters parameters){
    vec4 texColor = parameters.sampledColour;
    texColor *= parameters.tinting;
    outColor = texColor;

    float blockID = IDMapping(parameters.customId);

    gbufferData0.r = pack2x8To16(1.0, 0.0);
    gbufferData0.g = pack2x8To16(blockID/ID_SCALE, 0.0);
    gbufferData0.ba = pack4x8To2x16(vec4(0.0, 0.0, 0.0, 1.0));

    vec3 normalW = normalize(vec3(uint((parameters.face>>1)==2), uint((parameters.face>>1)==0), 
                            uint((parameters.face>>1)==1)) * (float(int(parameters.face)&1)*2-1));
    vec3 normalV = mat3(vxModelView) * normalW;

    gbufferData1.rg = normalEncode(normalV);
    gbufferData1.ba = parameters.lightMap;
    // #ifdef PATH_Tracing
    //     gbufferData1.b = pow(gbufferData1.b, 10.0);
    // #endif
    gbufferData2 = vec4(0.0, 0.0, gbufferData1.rg);
}