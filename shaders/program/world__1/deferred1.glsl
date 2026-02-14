varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

// varying vec3 sunColor, skyColor;
// varying vec3 zenithColor, horizonColor;

varying float isNoon, isNight, sunRiseSet;



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

const vec3 sunColor = vec3(0.0);
#include "/lib/lighting/pathTracing.glsl"

void main() {
	vec4 CT1 = texture(colortex1, texcoord);
	vec4 CT3 = texture(colortex3, texcoord);

	vec2 hrrUV = texcoord * 2.0;
	float hrrZ = texture(depthtex1, hrrUV).x;
	vec3 diffuse = BLACK;
	float ao = 1.0;
	if(!outScreen(hrrUV) && hrrZ < 1.0){
		vec4 hrrScreenPos = vec4(unTAAJitter(hrrUV), hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);

		vec3 hrrNormal = getNormal(hrrUV);
		vec3 hrrNormalW = normalize(viewPosToWorldPos(vec4(hrrNormal, 0.0)).xyz);

		#ifdef AO_ENABLED
			ao = AO_TYPE(hrrViewPos.xyz, hrrNormal, 0.0);
		#endif

		vec4 gi = vec4(diffuse, ao);
		#if defined RSM_ENABLED || defined AO_ENABLED
			gi = temporal_RSM(gi);
			gi = max(vec4(0.0), gi);
			CT3 = gi;
		#endif
	}

	// if(ivec2(gl_FragCoord.xy) == SUN_COLOR_UV){
	// 	CT1.rgb = sunColor;
	// }

	// if(ivec2(gl_FragCoord.xy) == SKY_COLOR_UV){
	// 	CT1.rgb = skyColor;
	// }

	// if(ivec2(gl_FragCoord.xy) == ZENITH_COLOR_UV){
	// 	CT1.rgb = zenithColor;
	// }

	// if(ivec2(gl_FragCoord.xy) == HORIZON_COLOR_UV){
	// 	CT1.rgb = horizonColor;
	// }


/* DRAWBUFFERS:3 */
	gl_FragData[0] = CT3;
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

	// sunColor = isNoon * TransmittanceToAtmosphere(earthPos, sunWorldDir) * IncomingLight;
	// sunColor += isNight * TransmittanceToAtmosphere(earthPos, moonWorldDir) * IncomingLight_N;
	// sunColor *= 1.0 - 0.75 * rainStrength;
	// skyColor = GetMultiScattering(getHeigth(earthPos), upWorldDir, sunWorldDir) * IncomingLight * 3;
	// skyColor += GetMultiScattering(getHeigth(earthPos), upWorldDir, moonWorldDir) * IncomingLight_N * 3;

	float d1 = RaySphereIntersection(earthPos, upWorldDir, vec3(0.0), earth_r + atmosphere_h).y;
	

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif