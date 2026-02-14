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
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"

#include "/lib/camera/filter.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

#include "/lib/common/gbufferData.glsl"
// #include "/lib/atmosphere/fog.glsl"
#include "/lib/common/materialIdMapper.glsl"
// #include "/lib/atmosphere/celestial.glsl"
// #include "/lib/atmosphere/volumetricClouds.glsl"




void main() {
	vec4 color = texture(colortex0, texcoord);

	float depth0 = texture(depthtex0, texcoord).r;
	vec4 viewPos0 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth0, 1.0));
	vec4 worldPos0 = viewPosToWorldPos(viewPos0);
	float worldDis0 = length(worldPos0);

	float depth1 = texture(depthtex1, texcoord).r;
    vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	float worldDis1 = length(worldPos1);

	vec3 viewDir = normalize(viewPos1.xyz);
	vec3 worldDir = normalize(worldPos1.xyz);

	vec3 fogColor = netherColor * 0.0045;
	color.rgb = mix(color.rgb, fogColor, 1.0 - exp(-worldDis1 / 66.0));
	if(skyB > 0.5) color.rgb = fogColor;


	// color.rgb = vec3(texture(colortex1, texcoord).rgb);
	color.rgb = max(color.rgb, BLACK);

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
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
	sunRiseSetS = saturate(1 - isNoon - isNight);

	// sunColor = getSunColor() * (1.0 - 0.95  * isNight);
	// skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif