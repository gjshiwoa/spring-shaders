varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;
varying vec3 zenithColor, horizonColor;

varying float isNoon, isNight, sunRiseSet;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"

#include "/lib/camera/filter.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH
// #include "/lib/common/gbufferData.glsl"
// #include "/lib/common/materialIdMapper.glsl"
#include "/lib/lighting/lightmap.glsl"
// #include "/lib/atmosphere/celestial.glsl"
#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/surface/PBR.glsl"

void main() {
	vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
#ifdef PBR_REFLECTIVITY
	vec2 hrrUV = texcoord * 2.0;
	vec3 reflectColor = BLACK;

	if(!outScreen(hrrUV)){
		CT1.rgb = BLACK;
		vec4 hrrSpecularMap = unpack2x16To4x8(texelFetch(colortex4, ivec2(gl_FragCoord.xy * 2), 0).ba);
		MaterialParams params = MapMaterialParams(hrrSpecularMap);
		if(hrrSpecularMap.r + rainStrength > 0.001){
			float hrrZ = CT6.a;
			vec4 hrrViewPos = screenPosToViewPos(vec4(unTAAJitter(hrrUV), hrrZ, 1.0));
			vec3 hrrViewDir = normalize(hrrViewPos.xyz);
			vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
			vec3 hrrWorldDir = normalize(hrrWorldPos.xyz);

			vec3 hrrNormalW = CT6.xyz;
			vec3 hrrNormalV = normalize(gbufferModelView * vec4(hrrNormalW, 0.0)).xyz;

			vec2 mcLightmap = texelFetch(colortex5, ivec2(gl_FragCoord.xy * 2), 0).ba;
			vec2 lightmap = AdjustLightmap(mcLightmap);

			float r = saturate(1.0 * params.roughness - 0.90 * rainStrength * smoothstep(0.90, 0.95, mcLightmap.y));
			vec3 reflectViewDir = normalize(reflect(hrrViewDir, hrrNormalV));
			reflectViewDir = getScatteredReflection(reflectViewDir, r, hrrNormalV);
			vec3 reflectWorldDir = normalize(reflect(hrrWorldDir, hrrNormalW));	

			float NdotU = dot(upWorldDir, reflectWorldDir);
			lightmap.y *= smoothstep(-1.0, 1.0, NdotU);

			int ssrTargetSampled = 0;
			reflectColor = reflection(colortex0, hrrViewPos.xyz, reflectWorldDir, reflectViewDir, lightmap.y, hrrNormalV, 1.0, ssrTargetSampled);
			reflectColor = clamp(reflectColor, 0.001, 10.0);
			// reflectViewDir = normalize(
			// 					reflect(hrrViewDir, hrrNormalV) + 
			// 					1.9 * r * (rand2_3(texcoord + sin(frameTimeCounter) + vec2(96.317, 46.389135)) - 0.5));
			// reflectColor = 0.5 * (reflectColor + reflection(colortex0, hrrViewPos.xyz, reflectWorldDir, reflectViewDir, lightmap.y, vec3(0.0), 1.0));
			
			
			reflectColor = temporal_Reflection(reflectColor, params.roughness);
			
			CT1.rgb = reflectColor;
		}	

		CT1.rgb = max(vec3(0.0), CT1.rgb);
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
	zenithColor = getZenithColor();
	horizonColor = getHorizonColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif