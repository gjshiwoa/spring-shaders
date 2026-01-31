varying vec2 texcoord, lmcoord;
varying vec4 glcolor;

varying vec3 N;

varying vec4 vViewPos;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"



#ifdef FSH
flat in float blockID;

void main() {
	if(texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r < 1.0 || length(vViewPos.xyz) < far * 0.9 || outScreen(gl_FragCoord.xy * invViewSize)) {
		discard;
	}

	vec4 color = glcolor;
	vec4 specularTex = vec4(BLACK, 1.0);

/* DRAWBUFFERS:045 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(vec2(blockID / ID_SCALE, 0.0)), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(N), lmcoord);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
#include "/lib/common/noise.glsl"

attribute vec4 at_midBlock;

flat out float blockID;

void main() {
	switch(dhMaterialId){
		case DH_BLOCK_LEAVES:	blockID = DH_LEAVES;  	break;
		case DH_BLOCK_WOOD: 	blockID = DH_WOOD; 		break;

		default:				blockID = DH_TERRAIN;	break;
	}

	vViewPos = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = ftransform();

	N = normalize(gl_NormalMatrix * gl_Normal);

	vec2 jitter = Halton_2_3[framemod8];
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;
	glcolor = gl_Color;

	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	#if defined PATH_TRACING || defined COLORED_LIGHT
		lmcoord.x = ((at_midBlock.a - 1.0)) / 15.0;
	#endif
}

#endif