
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
const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

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

		float dhTerrainHrr = 0.0;
		float depthHrr = texelFetch(depthtex0, ivec2(hrrUV_c * viewSize), 0).r;
		#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
			float dhDepth = texture(dhDepthTex0, hrrUV_c).r;
			dhTerrainHrr = depthHrr == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
			if(dhTerrainHrr > 0.5){
				hrrViewPos = screenPosToViewPosDH(vec4(unTAAJitter(hrrUV_c), dhDepth, 1.0));
			}
		#endif

		float isTerrainHrr = depthHrr < 1.0 || dhTerrainHrr > 0.5 ? 1.0 : 0.0;


		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
		vec3 hrrWorldDir = normalize(hrrWorldPos.xyz);

		#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
			if(isTerrainHrr < 0.5){
				hrrWorldPos.xyz = hrrWorldDir * dhRenderDistance;
			}
		#endif
		float hrrWorldDis = length(hrrWorldPos.xyz);

		bool useTemporal = false;
		#ifdef UNDERWATER_FOG
			if(isEyeInWater == 1){
				fogColor.rgb = underWaterFog(hrrWorldDir, hrrWorldDis).rgb;
				useTemporal = true;
			}
		#endif

		if(isEyeInWater == 0){
			#ifdef VOLUMETRIC_FOG
				fogColor = volumtricFog(camera, hrrWorldPos.xyz);
				if(fogColor.a < 0.9999) useTemporal = true;
			#endif

			#ifdef ATMOSPHERIC_SCATTERING_FOG
				if(isTerrainHrr > 0.5){
					float fogVis = fogVisibility(hrrWorldPos);
					fogVis = (fogVis * min(shadowDistance, hrrWorldDis) + max(hrrWorldDis - shadowDistance, 0.0)) / hrrWorldDis;
					fogVis = saturate(fogVis * isNoon);

					mat2x3 AtmosphericScattering_Land = AtmosphericScattering(hrrWorldPos.xyz, normalize(hrrWorldPos.xyz),
														sunWorldDir, IncomingLight, 1.0, int(VOLUME_LIGHT_SAMPLES));
					fogColor.rgb += (AtmosphericScattering_Land[0] * fogVis + AtmosphericScattering_Land[1])
														 * ATMOSPHERIC_SCATTERING_FOG_DENSITY * fogColor.a;
					useTemporal = true;
				}
			#endif
		}

		if(useTemporal){
			fogColor = temporal_fog(fogColor);
		}
		fogColor.rgb = max(fogColor.rgb, vec3(0.0));
		fogColor.a = saturate(fogColor.a);
		CT3 = fogColor;
	}

	
/* DRAWBUFFERS:3 */
	gl_FragData[0] = CT3;
	
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZY//////////////////////////////////////////////////////////////////////////////
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

	#ifdef END
		sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
		moonWorldDir = sunWorldDir;
		lightWorldDir = sunWorldDir;

		sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
		moonViewDir = sunViewDir;
		lightViewDir = sunViewDir;
	#elif defined NETHER
		sunWorldDir = normalize(vec3(0.0, 1.0, 0.0));
		moonWorldDir = sunWorldDir;
		lightWorldDir = sunWorldDir;

		sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
		moonViewDir = sunViewDir;
		lightViewDir = sunViewDir;
	#endif

	#ifdef NETHER
		sunColor = vec3(0.0);
		skyColor = vec3(0.5, 0.4, 0.9) * 0.4;
	#elif defined END
		skyColor = endColor * 1.0;
		sunColor = endColor * vec3(0.9, 0.45, 0.65) * 3.0;
	#endif


	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	sunRiseSetS = saturate(1 - isNoonS - isNightS);

	#if defined NETHER && defined END
		isNoon = 0.0;
		isNight = 1.0;
		sunRiseSet = 0.0;
	#endif

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif