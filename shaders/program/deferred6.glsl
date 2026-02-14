

varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;
varying vec3 sunColor, skyColor;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

#include "/lib/common/gbufferData.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/lighting/voxelization.glsl"
#include "/lib/lighting/RSM.glsl"
#include "/lib/lighting/SSAO.glsl"
#include "/lib/lighting/pathTracing.glsl"

void main() {
	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
	vec4 CT10 = texelFetch(colortex10, ivec2(gl_FragCoord.xy), 0);

	vec2 hrrUV = texcoord * 2.0;
	float hrrZ = CT6.g;
	vec3 diffuse = BLACK;
	float accumSpeedPrev = 0.0;

	float dhTerrainHrr = 0.0;
	float depthHrr1 = texelFetch(depthtex1, ivec2(hrrUV * viewSize), 0).r;
	#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
		float dhDepth = texture(dhDepthTex0, hrrUV).r;
		dhTerrainHrr = depthHrr1 == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
	#endif

	bool isTerrainHrr = depthHrr1 < 1.0 || dhTerrainHrr > 0.5;

	if(!outScreen(hrrUV) && isTerrainHrr){
		vec4 hrrScreenPos = vec4(unTAAJitter(hrrUV), hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
			if(dhTerrainHrr > 0.5){
				hrrViewPos = screenPosToViewPosDH(vec4(unTAAJitter(hrrUV), dhDepth, 1.0));
			}
		#endif
		
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
		vec3 hrrNormalW = unpackNormal(CT6.r);
		vec3 hrrNormal = normalize(mat3(gbufferModelView) * hrrNormalW);

		#ifdef PATH_TRACING
			diffuse.rgb = pathTracing(hrrViewPos.xyz, hrrWorldPos.xyz, hrrNormal, hrrNormalW);
		#elif defined COLORED_LIGHT
			diffuse.rgb = coloredLight(hrrWorldPos.xyz, hrrNormal, hrrNormalW);
		#endif

		vec4 gi = max(vec4(diffuse, accumSpeedPrev), vec4(0.0));
		gi = temporal_RT(gi);
		gi = max(vec4(0.0), gi);
		CT10 = gi;
	}

/* RENDERTARGETS: 10 */
	gl_FragData[0] = CT10;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa gjshiwoa////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunViewDir = normalize(sunPosition);
	moonViewDir = normalize(moonPosition);
	lightViewDir = normalize(shadowLightPosition);

	sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	sunRiseSetS = saturate(1 - isNoonS - isNightS);

	sunColor = getSunColor();
	skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif