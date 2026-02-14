#define SKY_BOX
#define PROGRAM_VLF

varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/atmosphere/atmosphericScattering.glsl"
#include "/lib/atmosphere/celestial.glsl"
#include "/lib/atmosphere/volumetricClouds.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;


#include "/lib/common/gbufferData.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/common/octahedralMapping.glsl"
#include "/lib/atmosphere/fog.glsl"

void main() {
	vec4 CT7 = texelFetch(colortex7, ivec2(gl_FragCoord.xy), 0);

	vec2 uv = texcoord * 2.0;
	if(!outScreen(uv)){

		vec3 worldDirO = octahedralToDirection(uv);
		vec3 worldDir = normalize(vec3(worldDirO.x, max(worldDirO.y, 0.0), worldDirO.z));

		float d_p2a = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r + atmosphere_h).y;
		float d_p2e = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r).x;
		float d = d_p2e > 0.0 ? d_p2e : d_p2a;
		d = max(d, 0.0);

		mat2x3 atmosphericScattering = AtmosphericScattering(worldDir * d_p2a, worldDirO, sunWorldDir, IncomingLight * (1.0 - 0.3 * rainStrength), 1.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5));
		atmosphericScattering += AtmosphericScattering(worldDir * d_p2a, worldDirO, moonWorldDir, IncomingLight_N, 1.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5)) * 0.2 * SKY_BASE_COLOR_BRIGHTNESS_N;
		vec3 skyBaseColor = atmosphericScattering[0] + atmosphericScattering[1];
		skyBaseColor *= SKY_BASE_COLOR_BRIGHTNESS;
		float skyMixFac = remapSaturate(dot(worldDirO, upWorldDir), 0.0, 0.33, 1.0, 0.0);
		vec3 skyMixCol = mix(sunColor, skyColor, 0.9);
		skyBaseColor = mix(skyBaseColor, skyMixCol, skyMixFac * sunRiseSetS);
		skyBaseColor *= mix(vec3(1.0), vec3(1.25, 0.9, 1.0), sunRiseSetS);

		vec4 intScattTrans = vec4(vec3(0.0), 1.0);
		float cloudHitLength = 0.0;
		vec3 color = BLACK;
		#ifdef VOLUMETRIC_CLOUDS
			cloudRayMarching(camera, worldDir * d, intScattTrans, cloudHitLength);
		#endif
		float cloudTransmittance = intScattTrans.a;
		vec3 cloudScattering = intScattTrans.rgb;

		vec3 celestial = drawCelestial(worldDir, cloudTransmittance, false);

		color.rgb = skyBaseColor;	
		// color.rgb += celestial;
		cloudTransmittance = max(cloudTransmittance, 0.0);
		cloudScattering = max(cloudScattering, vec3(0.0));
		color.rgb = color.rgb * cloudTransmittance + cloudScattering;

		float VoL = saturate(dot(worldDir, sunWorldDir));
		float phase = saturate(hgPhase1(VoL, 0.66 - 0.56 * rainStrength));
		if(cloudTransmittance < 1.0){
			color.rgb = 
				mix((skyBaseColor + celestial), color.rgb, 
					saturate(
						pow(exp(-cloudHitLength / ((1.0 - 0.66 * sunRiseSetS) * CLOUD_FADE_DISTANCE * (1.0 + 1.0 * phase * sunRiseSetS))), 
								remapSaturate(1.0 - saturate(getLuminance(cloudScattering - 0.5) + 0.05)
											, 0.0, 1.0, 1.0, 2.0))
					)
				);
		}

		#if defined DISTANT_HORIZONS && !defined END && !defined NETHER
			float fogDis = dhRenderDistance;
		#else
			float fogDis = vxRenderDistance * 16.0;
		#endif

		vec4 fogColor = vec4(0.0, 0.0, 0.0, 1.0);
		#ifdef VOLUMETRIC_FOG
			fogColor = volumtricFog(camera, worldDirO * fogDis);
		#endif
		color.rgb *= fogColor.a;
		color.rgb += fogColor.rgb;
		
		CT7.rgb = max(color.rgb, vec3(0.0));

		if(!outScreen(texcoord * 2.0))
			CT7.rgb = mix(texture(colortex7, texcoord).rgb, CT7.rgb, 0.05);
	}

/* DRAWBUFFERS:7 */
	gl_FragData[0] = CT7;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////ZY/////////////////////////////////////////////////////////////////////////
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