varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;

varying float isNoon, isNight, sunRiseSet;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/position.glsl"
// #include "/lib/common/normal.glsl"

#include "/lib/camera/filter.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH
// #include "/lib/common/gbufferData.glsl"
// #include "/lib/common/materialIdMapper.glsl"
// #include "/lib/lighting/lightmap.glsl"
// #include "/lib/atmosphere/celestial.glsl"
const vec3 zenithColor = vec3(0.0);
const vec3 horizonColor = vec3(0.0);

#include "/lib/water/waterReflectionRefraction.glsl"
// #include "/lib/surface/PBR.glsl"


void main() {
	// vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
	vec4 CT3 = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);

#ifdef PBR_REFLECTIVITY
	// vec2 uv0 = texcoord * 2.0;
	// if(!outScreen(uv0)){
	// 	vec4 hrrSpecularMap = unpack2x16To4x8(texture(colortex4, uv0).ba);
	// 	if(hrrSpecularMap.r + rainStrength > 0.001){
	// 		vec3 reflectColor = JointBilateralFiltering_Reflection();
	// 		CT1.rgb = reflectColor;
	// 	}
	// }

	vec2 uv1 = texcoord * 2.0 - 1.0;
	if(!outScreen(uv1)){
		CT3 = texelFetch(colortex1, ivec2(gl_FragCoord.xy - 0.5 * viewSize), 0);
	}
	CT3.rgb = max(vec3(0.0), CT3.rgb);
#endif

/* DRAWBUFFERS:3 */
	// gl_FragData[0] = CT1;
	gl_FragData[0] = CT3;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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

	sunColor = getSunColor();
	skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif