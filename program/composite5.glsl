varying vec2 texcoord;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/position.glsl"

#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/toneMapping.glsl"
#include "/lib/camera/filter.glsl"

#include "/lib/antialiasing/TAA.glsl"

#ifdef FSH

void main() {
	vec3 nowColor = texture(colortex0, texcoord).rgb;
	TAA(nowColor);
	nowColor = max(nowColor, BLACK);

	vec4 CT2 = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0);
	CT2.rgb = nowColor;

/* DRAWBUFFERS:02 */
	gl_FragData[0] = vec4(nowColor, 1.0);
	gl_FragData[1] = CT2;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif