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
#include "/lib/lighting/RSM.glsl"
#include "/lib/lighting/SSAO.glsl"

void main() {
	vec4 CT1 = vec4(0.0, 0.0, 0.0, 1.0);
	vec4 CT3 = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);

	vec2 hrrUV_a = texcoord * 2.0 - 1.0;
	if(!outScreen(hrrUV_a)){
		float hrrZ = texture(depthtex1, hrrUV_a).x;
		vec4 hrrScreenPos = vec4(unTAAJitter(hrrUV_a), hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
		float hrrWorldDis1 = length(hrrWorldPos.xyz);
		vec3 hrrWorldDirO = normalize(hrrWorldPos.xyz);
		vec3 hrrWorldDir = normalize(vec3(hrrWorldPos.x, max(hrrWorldPos.y, 0.0), hrrWorldPos.z));

		// vec2 prePos = getPrePos(viewPosToWorldPos(screenPosToViewPos(vec4(hrrUV_a, hrrZ, 1.0)))).xy * 0.5 + 0.5;

		if(isSkyHRR() > 0.5) {
			float d_p2a = RaySphereIntersection(earthPos, hrrWorldDir, vec3(0.0), earth_r + atmosphere_h).y;
			// float d_p2e = RaySphereIntersection(earthPos, hrrWorldDirO, vec3(0.0), earth_r).x;
			float d = d_p2a;
			d = max(d, 0.0);

			mat2x3 atmosphericScattering = AtmosphericScattering(hrrWorldDir * d, hrrWorldDirO, sunWorldDir, IncomingLight * (1.0 - 0.3 * rainStrength), 1.0, ATMOSPHERE_SCATTERING_SAMPLES);
			atmosphericScattering += AtmosphericScattering(hrrWorldDir * d, hrrWorldDirO, moonWorldDir, IncomingLight * getLuminance(IncomingLight), 1.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5)) * 0.0002 * SKY_BASE_COLOR_BRIGHTNESS_N;
			CT1.rgb = atmosphericScattering[0] + atmosphericScattering[1];
		}
	}

	vec2 hrrUV_c = texcoord * 2.0 - vec2(1.0, 0.0);
	if(!outScreen(hrrUV_c)){
		float hrrZ = texture(depthtex1, hrrUV_c).x;
		vec4 hrrScreenPos = vec4(hrrUV_c, hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
		float hrrWorldDis1 = length(hrrWorldPos.xyz);
		vec3 hrrWorldDirO = normalize(hrrWorldPos.xyz);
		vec3 hrrWorldDir = normalize(vec3(hrrWorldPos.x, max(hrrWorldPos.y, 0.0), hrrWorldPos.z));

		if(isSkyHRR1() > 0.5) {
			float d_p2a = RaySphereIntersection(earthPos, hrrWorldDir, vec3(0.0), earth_r + atmosphere_h).y;
			float d_p2e = RaySphereIntersection(earthPos, hrrWorldDirO, vec3(0.0), earth_r).x;
			float d = d_p2e > 0.0 ? d_p2e : d_p2a;
			float dist1 = hrrZ == 1.0 ? d : hrrWorldDis1;

			float cloudTransmittance = 1.0;
			vec3 cloudScattering = vec3(0.0);
			float cloudHitLength = 0.0;
			#ifdef VOLUMETRIC_CLOUDS
				cloudRayMarching(camera, hrrWorldDirO * dist1, cloudTransmittance, cloudScattering, cloudHitLength);
			#endif
			vec4 cloud = vec4(cloudScattering, cloudTransmittance);
			cloud = temporal_CLOUD3D(cloud);
			cloud.rgb = max(vec3(0.0), cloud.rgb);
			cloud.a = min(cloud.a, 1.0);

			CT1 = cloud;
			CT3 = cloud;
		}
	}


	vec2 hrrUV = texcoord * 2.0;
	float hrrZ = CT6.a;
	vec3 rsm = BLACK;
	float ao = 1.0;
	if(!outScreen(hrrUV) && hrrZ < 1.0){
		vec4 hrrScreenPos = vec4(unTAAJitter(hrrUV), hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);

		vec3 hrrNormalW = CT6.xyz;
		vec3 hrrNormal = normalize(mat3(gbufferModelView) * hrrNormalW);

		#ifdef RSM_ENABLED
			if(isNoon > 0.0) rsm = RSM(hrrWorldPos, hrrNormalW);
			rsm = max(BLACK, rsm);
		#endif

		#ifdef AO_ENABLED
			ao = saturate(1.0 - AO_TYPE(hrrViewPos.xyz, hrrNormal));
		#endif

		vec4 gi = vec4(rsm, ao);
		#if defined RSM_ENABLED || defined AO_ENABLED
			gi = temporal_RSM(gi);
			gi = max(vec4(0.0), gi);
			CT1 = gi;
			CT3 = gi;
		#endif
	}

/* DRAWBUFFERS:13 */
	gl_FragData[0] = CT1;
	gl_FragData[1] = CT3;
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

	isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	sunRiseSetS = saturate(1 - isNoonS - isNightS);

	sunColor = getSunColor();
	skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif