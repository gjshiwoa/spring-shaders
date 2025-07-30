varying vec2 lmcoord, texcoord;
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
	if(length(vViewPos.xyz) < far * 0.9) {
		discard;
		return;
	}

	vec4 color = glcolor;
	// vec4 texColor = texture(tex, texcoord);
	// color *= texColor;

	vec4 specularTex = vec4(BLACK, 1.0);

/* DRAWBUFFERS:045 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(vec2(blockID, DH_TERRAIN) / ID_SCALE), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(N), lmcoord);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
#include "/lib/common/noise.glsl"

flat out float blockID;

void main() {
	switch(dhMaterialId){
		case DH_BLOCK_LEAVES:	blockID = LEAVES;  	break;
		case DH_BLOCK_WOOD: 	blockID = LEAVES; 	break;

		default:				blockID = DH_TERRAIN;		break;
	}
	// float dhDepth1 = texture(dhDepthTex1, texcoord).r;
	// float dhDepth0 = texture(dhDepthTex0, texcoord).r;
	// if(dhDepth0 == 1.0 && dhDepth1 < 0.0) blockID = 0.0;

	vViewPos = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = ftransform();

	N = normalize(gl_NormalMatrix * gl_Normal);

	// vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	// jitter *= invViewSize;
	// gl_Position.xyz /= gl_Position.w;
    // gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    // gl_Position.xyz *= gl_Position.w;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}

#endif