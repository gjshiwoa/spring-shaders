varying vec4 texcoord;
varying vec4 lmcoord;
varying vec4 glColor;
varying vec3 normal;

varying vec4 vMcPos;

#ifdef DH
    varying float vWorldDis;
#endif

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"

#ifdef FSH

flat in float isWater;

void main(){
    #ifdef DH
        // if(vWorldDis < shadowDistance){
            discard;
        // }
    #endif

    vec4 color = vec4(BLACK, 1.0);
    if(isWater > 0.5){
        #ifdef CAUSTICS
            float waterColor = 1.0 - texture(gaux4, vMcPos.xyz * CAUSTICS_FREQ + frameTimeCounter * CAUSTICS_SPEED).b;
            color.rgb = vec3(remap(pow(waterColor, CAUSTICS_POWER), 0.0, 1.0, CAUSTICS_BRI_MIN, CAUSTICS_BRI_MAX));
            color.a = 0.5;
        #else
            color.rgb = vec3(1.0);
        #endif
    }else{
        color = texture(tex, texcoord.st) * glColor;
        if(color.a < 0.005){
            discard;
        }
    }

    float isTranslucent = color.a > 0.01 && color.a < 0.99 ? 1.0 : 0.0;

    vec3 shadowNormal = normal * (1.0 - isTranslucent);

    gl_FragData[0] = vec4(color.rgb, 1.0);
    gl_FragData[1] = vec4(shadowNormal, lmcoord.y);
}
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#ifdef VSH
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

flat out float isWater;


#include "/lib/common/materialIdMapper.glsl"
#include "/lib/wavingPlants.glsl"

void main(){
    float blockID = IDMapping();
    float translucencyID = IDMappingT();

    vec4 vWorldPos = shadowModelViewInverse * shadowProjectionInverse * ftransform();
    vMcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

    isWater = translucencyID == WATER ? 1.0 : 0.0;

    // 水面剔除
    // if(translucencyID == WATER){
    //     vMcPos.xyz += 10000.0;
    // }
    #ifdef WAVING_PLANTS
        const float waving_rate = WAVING_RATE;
        if(blockID == PLANTS_SHORT && gl_MultiTexCoord0.t < mc_midTexCoord.t){
            // pos, normal, A, B, D_amount, y_waving_amount
            vMcPos.xyz = wavingPlants(vMcPos.xyz, PLANTS_SHORT_AMPLITUDE, waving_rate, 0.0, 0.0);
        }
        if(blockID == LEAVES){
            vMcPos.xyz = wavingPlants(vMcPos.xyz, LEAVES_AMPLITUDE, waving_rate, 0.0, 1.0);
        }
        if((blockID == PLANTS_TALL_L && gl_MultiTexCoord0.t < mc_midTexCoord.t) || blockID == PLANTS_TALL_U){
            vMcPos.xyz = wavingPlants(vMcPos.xyz, PLANTS_TALL_AMPLITUDE, waving_rate, 0.0, 0.0);
        }
    #endif

    vec4 sViewPos = shadowModelView * vec4(vMcPos.xyz - cameraPosition, 1.0);
    #ifdef DH
        vWorldDis = length(sViewPos.xy);
    #endif
    vec4 sClipPos = shadowProjection * sViewPos;
    vec4 sNDCPos = vec4(sClipPos.xyz / sClipPos.w, 1.0);
    gl_Position = sNDCPos;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
    gl_Position.xy = shadowDistort1(gl_Position.xy);
    gl_Position.z = mix(gl_Position.z, 0.5, 0.8);

    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
    lmcoord = (lmcoord * 33.05 / 32.0) - 1.05 / 32.0;
    glColor = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
}
#endif