const int R11F_G11F_B10F = 0;
const int RGBA8 = 0;
const int RGBA16 = 0;
const int RGBA16F = 0;
const int RGBA32 = 0;
const int RGBA32F = 0;

const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16F;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA32F;
const int colortex7Format = RGBA16F;

const int shadowcolor0Format = RGBA16F;
const int shadowcolor1Format = RGBA16F;

const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool colortex6Clear = false;
const bool colortex7Clear = false;

/*
0: rgb:color
1: hrr data
2: rgb:TAA          		a:temporal data
3: rgba:temporal data(rsm/ao/sky/cloud/ssr)
4: r:parallax shadow/ao		g:blockID/gbufferID		ba:specular		(df4)rg:albedo/ao	(df11)rgba:color
5: rg:normal				ba:lmcoord																		(cp0)ba:velocity
6: hrr normal/depth (pre/cur)
7: sky box/T1/MS/sunColor/skyColor
*/

varying vec2 texcoord;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH

void main() {
	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
	vec2 uv2 = texcoord * 2.0;
	float curZ = 0.0;
	vec3 curNormalW = vec3(0.0);
	if(!outScreen(uv2)){
		curZ = texelFetch(depthtex1, ivec2(uv2 * viewSize), 0).r;
		curNormalW = normalize(viewPosToWorldPos(vec4(getNormalH(uv2), 0.0)).xyz);
		CT6 = vec4(curNormalW, curZ);
	}
	
/* DRAWBUFFERS:6 */
	gl_FragData[0] = CT6;
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