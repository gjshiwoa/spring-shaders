varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;
varying vec3 zenithColor, horizonColor;

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
const bool shadowtex1Mipmap = true;
const bool shadowtex1Nearest = false;

const bool shadowcolor0Mipmap = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Mipmap = true;
const bool shadowcolor1Nearest = false;

#include "/lib/common/gbufferData.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/atmosphere/octahedralMapping.glsl"

void main() {
	vec4 CT7 = vec4(0.0, 0.0, 0.0, 1.0);

	
	// float Z = texture(depthtex1, texcoord).x;
	// vec4 screenPos = vec4(unTAAJitter(texcoord), Z, 1.0);
	// vec4 viewPos = screenPosToViewPos(screenPos);
	// vec4 worldPos = viewPosToWorldPos(viewPos);
	vec3 worldDirO = octahedralToDirection(texcoord);
	vec3 worldDir = normalize(vec3(worldDirO.x, max(worldDirO.y, 0.0), worldDirO.z));

	float d_p2a = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r + atmosphere_h).y;
	float d_p2e = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r).x;
	float d = d_p2e > 0.0 ? d_p2e : d_p2a;
	d = max(d, 0.0);

	mat2x3 atmosphericScattering = AtmosphericScattering(worldDir * d_p2a, worldDirO, sunWorldDir, IncomingLight * (1.0 - 0.3 * rainStrength), 1.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5));
	atmosphericScattering += AtmosphericScattering(worldDir * d_p2a, worldDirO, moonWorldDir, IncomingLight * getLuminance(IncomingLight), 1.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5)) * 0.0002 * SKY_BASE_COLOR_BRIGHTNESS_N;
	vec3 skyBaseColor = atmosphericScattering[0] + atmosphericScattering[1];

	float cloudTransmittance = 1.0;
	vec3 cloudScattering = vec3(0.0);
	float cloudHitLength = 0.0;
	vec3 color = vec3(0.0);
	#ifdef VOLUMETRIC_CLOUDS
		cloudRayMarching(color, camera, worldDir * d, cloudTransmittance, cloudScattering, cloudHitLength);
	#endif

	skyBaseColor *= SKY_BASE_COLOR_BRIGHTNESS;
	vec3 celestial = drawCelestial(worldDir, cloudTransmittance, false);

	color.rgb = skyBaseColor;	
	color.rgb += celestial;
	cloudTransmittance = max(cloudTransmittance, 0.0);
	cloudScattering = max(cloudScattering, vec3(0.0));
	color.rgb = color.rgb * cloudTransmittance + cloudScattering * CLOUD_BRIGHTNESS;

	if(cloudTransmittance < 1.0){
		color.rgb = mix(skyBaseColor + celestial, color.rgb, 
				mix(saturate(1.0 * pow(getLuminance(cloudScattering), 1.0)), exp(-cloudHitLength / (CLOUD_SKY_MIX * (1.0 + 1.0 * sunRiseSetS))) * 0.90, 0.60));
	}
	
	color.rgb = max(color.rgb, vec3(0.0));

	CT7.rgb = mix(texture(colortex7, texcoord).rgb, color, 0.05);
    

/* DRAWBUFFERS:7 */
	gl_FragData[0] = CT7;
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

	float isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	float isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	float sunRiseSetS = saturate(1 - isNoonS - isNightS);

	float d1 = RaySphereIntersection(earthPos, upWorldDir, vec3(0.0), earth_r + atmosphere_h).y;
	// vec3 worldPos, vec3 lightDir, vec3 I, float mieAmount, const int N_SAMPLES, const int lutSampleGap
	mat2x3 atmosphericScattering = AtmosphericScattering(upWorldDir * d1, upWorldDir, sunWorldDir, IncomingLight, 0.0, ATMOSPHERE_SCATTERING_SAMPLES);
	zenithColor = atmosphericScattering[0] + atmosphericScattering[1];
	atmosphericScattering = AtmosphericScattering(upWorldDir * d1, upWorldDir, moonWorldDir, IncomingLight_N * 1.5, 0.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5));
	zenithColor += atmosphericScattering[0] + atmosphericScattering[1];

	vec3 horizonDir = normalize(vec3(0.0, 0.0001, -1.0));
	float d2 = RaySphereIntersection(earthPos, horizonDir, vec3(0.0), earth_r + atmosphere_h).y;
	atmosphericScattering = AtmosphericScattering(horizonDir * d2, horizonDir, sunWorldDir, IncomingLight, 0.0, ATMOSPHERE_SCATTERING_SAMPLES);
	horizonColor = atmosphericScattering[0] + atmosphericScattering[1];
	atmosphericScattering = AtmosphericScattering(horizonDir * d2, horizonDir, moonWorldDir, IncomingLight_N * 1.5, 0.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5));
	horizonColor += atmosphericScattering[0] + atmosphericScattering[1];

	sunColor = isNoon * TransmittanceToAtmosphere(earthPos, sunWorldDir) * IncomingLight;
	sunColor += isNight * TransmittanceToAtmosphere(earthPos, moonWorldDir) * IncomingLight_N;
	sunColor *= 1.0 - 0.75 * rainStrength;
	// skyColor = GetMultiScattering(getHeigth(earthPos), upWorldDir, sunWorldDir) * IncomingLight * 3;
	// skyColor += GetMultiScattering(getHeigth(earthPos), upWorldDir, moonWorldDir) * IncomingLight_N * 3;
	skyColor = zenithColor;
	skyColor *= 3.0;
	skyColor *= 1.0 - 0.3 * rainStrength;

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif