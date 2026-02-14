varying vec2 lmcoord;
varying vec2 texcoord;

varying vec4 glcolor;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH

void main() {
	vec4 color = texture(tex, texcoord) * glcolor;
	vec4 specularTex = vec4(0.0, 0.0, 0.0, 0.0);
	vec4 CT4 = texture(gaux1, gl_FragCoord.xy * invViewSize);
	vec4 CT5 = texture(gaux2, gl_FragCoord.xy * invViewSize);
	if(color.a > 254.0 / 255.0) {
		CT4 = vec4(pack2x8To16(1.0, 0.0), 0.0, pack4x8To2x16(vec4(0.0, 0.0, 0.0, 254.0/255.0)));
		CT5 = vec4(normalEncode(normalize(shadowLightPosition)), vec2(0.0, 1.0));
	}

#ifdef VOXY
/* RENDERTARGETS: 0,4,5,19 */
#else
/* RENDERTARGETS: 0,4,5 */
#endif
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = CT4;
	gl_FragData[2] = CT5;
#ifdef VOXY
	gl_FragData[3] = vec4(1.0, 0.0, 0.0, 1.0);
#endif
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
#include "/lib/common/noise.glsl"

void main() {
	gl_Position = ftransform();

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}

#endif
