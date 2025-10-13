
#define CPS
#define PROGRAM_VLF

varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;

varying vec3 sunColor, skyColor;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/atmosphere/atmosphericScattering.glsl"


#ifdef FSH

#include "/lib/atmosphere/volumetricClouds.glsl"
#include "/lib/atmosphere/fog.glsl"
#include "/lib/water/waterFog.glsl"
#include "/lib/camera/equalWeightBlur.glsl"

void main() {
	vec4 CT3 = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
	vec2 hrrUV_c = texcoord * 2.0 - vec2(0.0, 1.0);
	vec4 fogColor = vec4(0.0, 0.0, 0.0, 1.0);
	if(!outScreen(hrrUV_c)){
		vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
		float hrrZ = CT6.g;

		vec4 hrrScreenPos = vec4(unTAAJitter(hrrUV_c), hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
		float hrrWorldDis = length(hrrWorldPos.xyz);
		vec3 hrrWorldDir = normalize(hrrWorldPos.xyz);

		#ifdef UNDERWATER_FOG
			if(isEyeInWater == 1){
				fogColor.rgb = underWaterFog(hrrWorldDir, hrrWorldDis).rgb;
			}
		#endif

		if(isEyeInWater == 0){
			fogColor = volumtricFog(camera, hrrWorldPos.xyz);

			#ifdef ATMOSPHERIC_SCATTERING_FOG
				if(isEyeInWater == 0 && hrrZ < 1.0){
					float fogVis = fogVisibility(hrrWorldPos);
					fogVis = (fogVis * min(shadowDistance, hrrWorldDis) + max(hrrWorldDis - shadowDistance, 0.0)) / hrrWorldDis;
					fogVis = saturate(fogVis * isNoon);

					mat2x3 AtmosphericScattering_Land = AtmosphericScattering(hrrWorldPos.xyz, normalize(hrrWorldPos.xyz), sunWorldDir, IncomingLight, 1.0, int(VOLUME_LIGHT_SAMPLES));
					fogColor.rgb += (AtmosphericScattering_Land[0] * fogVis + AtmosphericScattering_Land[1]) * ATMOSPHERIC_SCATTERING_FOG_DENSITY * fogColor.a;
				}
			#endif
		}

		fogColor = temporal_fog(fogColor);
		fogColor.rgb = max(fogColor.rgb, vec3(0.0));
		fogColor.a = saturate(fogColor.a);
		CT3 = fogColor;
	}

	
/* DRAWBUFFERS:3 */
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

	sunColor = getSunColor();
	skyColor = getSkyColor();

	#ifdef NETHER
		skyColor = vec3(0.5, 0.4, 0.9) * 0.3;
	#elif defined END
		skyColor = endColor * 1.0;
		sunColor = endColor * vec3(0.9, 0.45, 0.65) * 2.0;
	#endif


	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	sunRiseSetS = saturate(1 - isNoonS - isNightS);

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif