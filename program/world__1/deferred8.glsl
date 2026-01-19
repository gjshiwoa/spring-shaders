varying vec2 texcoord;
varying vec3 lightViewDir;
varying vec3 lightWorldDir;
varying vec3 sunColor;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

#include "/lib/lighting/voxelization.glsl"
#include "/lib/lighting/RSM.glsl"
#include "/lib/lighting/pathTracing.glsl"

void main() {
	vec4 CT11 = texture(colortex11, texcoord);

	vec4 gi = vec4(BLACK, 1.0);
	vec2 uv = texcoord * 2;

	float dhTerrainHrr = 0.0;
	float depthHrr1 = texelFetch(depthtex1, ivec2(uv * viewSize), 0).r;
	#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
		dhTerrainHrr = depthHrr1 == 1.0 && texelFetch(dhDepthTex0, ivec2(uv * viewSize), 0).r < 1.0 ? 1.0 : 0.0;
	#endif

	float isTerrainHrr = depthHrr1 < 1.0 || dhTerrainHrr > 0.5 ? 1.0 : 0.0;

	if(!outScreen(uv) && isTerrainHrr > 0.5){
		gi = JointBilateralFiltering_PT_Vertical();
		CT11 = gi;
	}
	
/* RENDERTARGETS: 11 */
	gl_FragData[0] = CT11;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif