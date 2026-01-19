

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/water/waterNormal.glsl"
#include "/lib/water/waterCaustics.glsl"
#include "/lib/camera/filter.glsl"

#ifdef FSH
in vec4 texcoord;
in vec4 lmcoord;
in vec4 glColor;
in vec3 normal;
in vec4 mcPos;
flat in float isWater;

void main(){
    #ifdef DH
        discard;
    #endif

    vec4 color = vec4(BLACK, 1.0);
    if(isWater > 0.5){
        #ifdef CAUSTICS
            color.rgb = computeCausticsWithDispersion(mcPos.xyz);
            color.a = 0.5;
        #else
            color.rgb = vec3(1.0);
        #endif
    }else{
        color = textureLod(tex, texcoord.st, 0.0) * glColor;
    }

    if(color.a < 0.1){
        discard;
    }

    float isTranslucent = color.a > 0.01 && color.a < 0.99 ? 1.0 : 0.0;

    vec3 shadowNormal = normal * (1.0 - isTranslucent);

    gl_FragData[0] = vec4(color.rgb, 1.0);
    gl_FragData[1] = vec4(shadowNormal * 0.5 + 0.5, lmcoord.y);
}
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef GSH
layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in vec4 v_texcoord[];
in vec4 v_lmcoord[];
in vec4 v_glColor[];
in vec3 v_normal[];
in vec4 v_mcPos[];
in vec4 worldPos[];
in vec4 midBlock[];
in vec2 midTexCoord[];
flat in float v_isWater[], v_noVoxel[], v_useArtCol[];

out vec4 texcoord;
out vec4 lmcoord;
out vec4 glColor;
out vec3 normal;
out vec4 mcPos;
flat out float isWater;

#include "/lib/lighting/voxelization.glsl"

layout(rgba8) uniform image3D voxel;
layout(rgba8) uniform image3D voxelLitSky;

void main(){
    float maxLength = max3(distance(worldPos[0].xyz, worldPos[1].xyz), 
                            distance(worldPos[1].xyz, worldPos[2].xyz), 
                            distance(worldPos[2].xyz, worldPos[0].xyz));
    float avgLMC = (v_lmcoord[0].y + v_lmcoord[1].y + v_lmcoord[2].y) / 3.0;

    #if defined PATH_TRACING || defined COLORED_LIGHT
        if(maxLength > 0.5){
            vec3 relBlockCenter = worldPos[0].xyz + midBlock[0].xyz / 64.0;
            ivec3 vc = relWorldToVoxelCoord(relBlockCenter);
            bool is_terrain = any(equal(ivec3(renderStage), ivec3(MC_RENDER_STAGE_TERRAIN_SOLID, 
            /*MC_RENDER_STAGE_TERRAIN_TRANSLUCENT,*/ MC_RENDER_STAGE_TERRAIN_CUTOUT, MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED)));
            
            if (voxelInBounds(vc) && is_terrain) {
                float lightBri = (midBlock[0].w) / 15.0;

                vec2 bias = abs(v_texcoord[0].xy - midTexCoord[0]) * 0.5;
                const vec2 biasArr[7] = vec2[](
                    vec2(0.0, 0.0),
                    vec2(bias.x, bias.y),
                    vec2(-bias.x, bias.y),
                    vec2(-bias.x, -bias.y),
                    vec2(bias.x, -bias.y),
                    vec2(0.0, bias.y * 1.9),
                    vec2(0.0, -bias.y * 1.9)
                );
                vec3 lightCol = vec3(0.0);
                float spe = 0.0;
                float weight = 0.0;
                for(int j = 0; j < 7; j++){
                    vec2 sampleCoord = midTexCoord[0] + biasArr[j];
                    vec4 litTexCol = texture(tex, sampleCoord);
                    spe += texture(specular, sampleCoord).a;
                    lightCol += litTexCol.rgb * litTexCol.a;
                    weight += litTexCol.a;
                }
                lightCol /= max(weight, 0.01);
                spe /= max(weight, 0.01);
                lightBri = saturate(max(lightBri, spe < 254.1 / 255.0 ? spe : 0.0));

                vec3 outCol = lightCol * v_glColor[0].rgb;
                if(dot(outCol, vec3(0.3333)) < 0.01 && lightBri > 0.1)
                    outCol = vec3(0.66);
                
                lightBri = clamp(lightBri, 0.0, 0.94);

                if(lightBri > 0.1 && v_useArtCol[0] > 0.5)
                    outCol = artificial_color.rgb;

                if(v_noVoxel[0] < 0.5){
                    imageStore(voxel, vc, vec4(outCol, lightBri));
                    imageStore(voxelLitSky, vc, vec4(avgLMC, 0.0, 0.0, 0.0));
                }
            }
        }
    #endif

    for(int i = 0; i < 3; ++i){
        texcoord = v_texcoord[i];
        lmcoord = v_lmcoord[i];
        glColor = v_glColor[i];
        normal = v_normal[i];
        mcPos = v_mcPos[i];
        isWater = v_isWater[i];

        gl_Position = gl_in[i].gl_Position;
        EmitVertex();
    }
    EndPrimitive();
}

#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#ifdef VSH
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_midBlock;

out vec4 v_texcoord;
out vec4 v_lmcoord;
out vec4 v_glColor;
out vec3 v_normal;
out vec4 v_mcPos;
out vec4 worldPos;
out vec4 midBlock;
flat out float v_isWater, v_noVoxel, v_useArtCol;
out vec2 midTexCoord;


#include "/lib/common/materialIdMapper.glsl"
#include "/lib/wavingPlants.glsl"

void main(){
    v_texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    v_lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
    v_glColor = gl_Color;
    v_lmcoord = (v_lmcoord * 33.05 / 32.0) - 1.05 / 32.0;
    v_normal = normalize(gl_NormalMatrix * gl_Normal);
    midBlock = at_midBlock;
    midTexCoord = mc_midTexCoord.xy;


    float blockID = IDMapping();
    float translucencyID = IDMappingT();

    worldPos = shadowModelViewInverse * shadowProjectionInverse * ftransform();
    float worldDis = length(worldPos.xyz);
    v_mcPos = vec4(worldPos.xyz + cameraPosition, 1.0);

    v_isWater = translucencyID == WATER ? 1.0 : 0.0;
    v_noVoxel = abs(blockID - NO_VOXEL) < 0.1 ? 1.0 : 0.0;
    v_useArtCol = abs(blockID - USE_ART_COL) < 0.1 ? 1.0 : 0.0;

    #ifdef WAVING_PLANTS
        if(worldDis < 60.0){
            const float waving_rate = WAVING_RATE;
            if(blockID == PLANTS_SHORT && gl_MultiTexCoord0.t < mc_midTexCoord.t){
                v_mcPos.xyz = wavingPlants(v_mcPos.xyz, PLANTS_SHORT_AMPLITUDE, waving_rate, 0.0, WAVING_NOISE_SCALE);
            }
            if(blockID == LEAVES){
                v_mcPos.xyz = wavingPlants(v_mcPos.xyz, LEAVES_AMPLITUDE, waving_rate, 1.0, WAVING_NOISE_SCALE);    
            }
            if((blockID == PLANTS_TALL_L && gl_MultiTexCoord0.t < mc_midTexCoord.t) || blockID == PLANTS_TALL_U){
                v_mcPos.xyz = wavingPlants(v_mcPos.xyz, PLANTS_TALL_AMPLITUDE, waving_rate, 0.0, WAVING_NOISE_SCALE);
            }
        }
    #endif

    vec4 sViewPos = shadowModelView * vec4(v_mcPos.xyz - cameraPosition, 1.0);
    #ifdef DH
        vWorldDis = length(sViewPos.xy);
    #endif
    vec4 sClipPos = shadowProjection * sViewPos;
    vec4 sNDCPos = vec4(sClipPos.xyz / sClipPos.w, 1.0);
    gl_Position = sNDCPos;
    gl_Position.xy = shadowDistort(gl_Position.xy);
    gl_Position.z = mix(gl_Position.z, 0.5, 0.8);

}
#endif