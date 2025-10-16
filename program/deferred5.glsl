varying vec2 texcoord;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH
#include "/lib/lighting/RSM.glsl"

void main() {
	vec4 CT1 = texture(colortex1, texcoord);

	vec4 gi = vec4(BLACK, 1.0);
	vec2 uv = texcoord * 2;

	float dhTerrain = 0.0;
	#ifdef DISTANT_HORIZONS
		vec4 CT4Hrr = texelFetch(colortex4, ivec2(uv * viewSize), 0);
		vec2 CT4GHrr = unpack16To2x8(CT4Hrr.g);
		float blockIDHrr = CT4GHrr.x * ID_SCALE;
		dhTerrain = blockIDHrr > DH_TERRAIN - 0.5 ? 1.0 : 0.0;
	#endif

	float isTerrainHrr = texelFetch(depthtex1, ivec2(uv * viewSize), 0).r < 1.0
						|| dhTerrain > 0.5 ? 1.0 : 0.0;

	#if defined RSM_ENABLED || defined AO_ENABLED
		if(!outScreen(uv) && isTerrainHrr > 0.5){
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