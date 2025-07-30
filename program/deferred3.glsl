varying vec2 texcoord;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"

#ifdef FSH
#include "/lib/lighting/RSM.glsl"

void main() {
	vec4 CT1 = texture(colortex1, texcoord);

	vec4 gi = vec4(BLACK, 1.0);
	vec2 uv = texcoord * 2;
	float hrrZ = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).a;

	#if defined RSM_ENABLED || defined AO_ENABLED
		if(!outScreen(uv) && hrrZ < 1.0){
			gi = JointBilateralFiltering_RSM_Vertical();
			CT1 = gi;
		}
	#endif
	
/* DRAWBUFFERS:1 */
	gl_FragData[0] = CT1;
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