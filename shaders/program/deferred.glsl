

varying vec2 texcoord;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;


void main() {
	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
	vec2 uv1 = texcoord * 2.0;
	float curZ = 0.0;
	vec3 curNormalW = vec3(0.0);
	if(!outScreen(uv1)){
		curZ = texelFetch(depthtex1, ivec2(uv1 * viewSize), 0).r;
		curNormalW = normalize(viewPosToWorldPos(vec4(getNormalH(uv1), 0.0)).xyz);

		#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
			float dhCurZ = texelFetch(dhDepthTex0, ivec2(uv1 * viewSize), 0).r;
			vec4 dhViewPos = screenPosToViewPosDH(vec4(uv1, dhCurZ, 1.0));
			dhCurZ = viewPosToScreenPos(dhViewPos).z;

			float dhTerrain = texture(dhDepthTex0, uv1).r < 1.0 && curZ == 1.0 ? 1.0 : 0.0;

			if(dhTerrain > 0.5){
				curZ = dhCurZ;
			}
		#endif

		CT6 = vec4(packNormal(curNormalW), curZ, 0.0, 0.0);
	}
	
/* DRAWBUFFERS:6 */
	gl_FragData[0] = CT6;
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