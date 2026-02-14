

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

void main() {
	vec4 CT1 = vec4(0.0, 0.0, 0.0, 1.0);
	vec4 CT3 = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
	vec2 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).rg;

	vec2 hrrUV_a = texcoord * 2.0 - 1.0;
	if(!outScreen(hrrUV_a)){
		float hrrZ = texture(depthtex1, hrrUV_a).x;
		vec4 hrrScreenPos = vec4(unTAAJitter(hrrUV_a), hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
		float hrrWorldDis1 = length(hrrWorldPos.xyz);
		vec3 hrrWorldDirO = normalize(hrrWorldPos.xyz);
		vec3 hrrWorldDir = normalize(vec3(hrrWorldPos.x, max(hrrWorldPos.y, 0.0), hrrWorldPos.z));

		float dirMixFactor = remapSaturate(camera.y, 10000.0, 10002.0, 0.0, 1.0);
		hrrWorldDir = normalize(mix(hrrWorldDir, hrrWorldDirO, dirMixFactor));

		if(isSkyHRR(hrrUV_a) > 0.5) {
			float d_p2a = RaySphereIntersection(earthPos, hrrWorldDir, vec3(0.0), earth_r + atmosphere_h).y;
			float d_p2e = RaySphereIntersection(earthPos, hrrWorldDir, vec3(0.0), earth_r).x;
			float d = d_p2a;
			d = d_p2e > 0.0 ? d_p2e : d;
			d = max(d, 0.0);

			mat2x3 atmosphericScattering = AtmosphericScattering(hrrWorldDir * d, hrrWorldDirO, sunWorldDir, IncomingLight * (1.0 - 0.3 * rainStrength), 1.0, ATMOSPHERE_SCATTERING_SAMPLES);
			atmosphericScattering += AtmosphericScattering(hrrWorldDir * d, hrrWorldDirO, moonWorldDir, IncomingLight_N, 1.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5)) * 0.2 * SKY_BASE_COLOR_BRIGHTNESS_N;
			CT1.rgb = atmosphericScattering[0] + atmosphericScattering[1];
		}
	}

	#ifndef PATH_TRACING
		vec2 hrrUV = texcoord * 2.0;
		float hrrZ = CT6.g;
		vec3 rsm = BLACK;
		float ao = 1.0;

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

			
			float rsmAO = 1.0;
			#ifdef RSM_ENABLED
				if(isNoon > 0.001 && isEyeInWater == 0.0) {
					vec3 mainDir = vec3(0.0);
					rsm = RSM(hrrWorldPos, hrrNormalW, mainDir);	
					#ifdef RSM_LEAK_FIX
						rsmAO = estimateRsmLeakAO(mainDir, hrrViewPos.xyz);
						// rsmAO = estimateRsmLeakAO_voxel(mainDir, hrrWorldPos.xyz, hrrNormalW);
						rsm *= rsmAO;
					#endif
				}
				rsm = max(BLACK, rsm);
			#endif

			#ifdef AO_ENABLED
				ao = saturate(1.0 - GTAO(hrrViewPos.xyz, hrrNormal, dhTerrainHrr));
			#endif

			vec4 gi = vec4(rsm, ao);
			#if defined RSM_ENABLED || defined AO_ENABLED
				gi = temporal_RSM(gi);
				gi = max(vec4(0.0), gi);
				CT3 = gi;
			#endif
		}
	#endif
	
/* DRAWBUFFERS:13 */
	gl_FragData[0] = CT1;
	gl_FragData[1] = CT3;
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