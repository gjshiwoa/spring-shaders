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
const int colortex7Format = RGBA8;

const int shadowcolor0Format = RGBA8;
const int shadowcolor1Format = RGBA16F;

const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool colortex6Clear = false;

/*
0: rgb:color
1: hrr data
2: rgb:TAA          		a:temporal data
3: rgba:temporal data(rsm/ao/ssr)
4: r:parallax shadow/ao		g:blockID/gbufferID		ba:specular			(df4)rg:albedo/ao	(df11)rgba:color
5: rg:normal				ba:lmcoord														(df11)rgba:CT1
6: normal/depth (pre/cur)
7: no used
*/

varying vec2 texcoord;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH

void main() {
	vec4 CT1 = vec4(BLACK, 1.0);
	ivec2 uv0 = T1_UV;
	vec2 uv00 = vec2(smoothstep(uv0.x, uv0.x + T1_RES.x, gl_FragCoord.x), 
					smoothstep(uv0.y, uv0.y + T1_RES.y, gl_FragCoord.y));
	if(!outScreen(uv00)) CT1 += texture(colortex1, uv00);

	ivec2 uv1 = MS_UV;
	vec2 uv11 = vec2(smoothstep(uv1.x, uv1.x + MS_RES.x, gl_FragCoord.x),
					smoothstep(uv1.y, uv1.y + MS_RES.y, gl_FragCoord.y));
	if(!outScreen(uv11)) CT1 += texture(depthtex2, uv11);

	vec4 CT6 = texture(colortex6, texcoord);
	vec2 uv2 = texcoord * 2.0;
	float curZ = 0.0;
	vec3 curNormalW = vec3(0.0);
	if(!outScreen(uv2)){
		curZ = texelFetch(depthtex1, ivec2(uv2 * viewSize), 0).r;
		curNormalW = normalize(viewPosToWorldPos(vec4(getNormal(uv2), 0.0)).xyz);
		CT6 = vec4(curNormalW, curZ);
	}
	
/* DRAWBUFFERS:16 */
	gl_FragData[0] = CT1;
	gl_FragData[1] = CT6;
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