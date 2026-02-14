#define CLOUD3D

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
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"
#include "/lib/atmosphere/volumetricClouds.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;
#include "/lib/common/gbufferData.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/lighting/voxelization.glsl"
#include "/lib/lighting/RSM.glsl"

void main() {
	vec4 CT1 = texture(colortex1, texcoord);
	vec4 CT3 = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);

	#ifndef PATH_TRACING
		vec4 gi = vec4(BLACK, 1.0);
		vec2 uv = texcoord * 2;

		float dhTerrainHrr = 0.0;
		float depthHrr1 = texelFetch(depthtex1, ivec2(uv * viewSize), 0).r;
		#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
			dhTerrainHrr = depthHrr1 == 1.0 && texelFetch(dhDepthTex0, ivec2(uv * viewSize), 0).r < 1.0 ? 1.0 : 0.0;
		#endif

		float isTerrainHrr = depthHrr1 < 1.0 || dhTerrainHrr > 0.5 ? 1.0 : 0.0;

		#if defined RSM_ENABLED || defined AO_ENABLED
			if(!outScreen(uv) && isTerrainHrr > 0.5){
				gi = JointBilateralFiltering_RSM_Horizontal();
				CT1 = gi;
			}
		#endif
	#endif

	vec2 hrrUV_c = texcoord * 2.0 - vec2(1.0, 0.0);
	if(!outScreen(hrrUV_c)){
		float hrrZ = texture(depthtex1, hrrUV_c).x;
		vec4 hrrScreenPos = vec4(unTAAJitter(hrrUV_c), hrrZ, 1.0);
		vec4 hrrViewPos = screenPosToViewPos(hrrScreenPos);
		vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
		float hrrWorldDis1 = length(hrrWorldPos.xyz);
		vec3 hrrWorldDirO = normalize(hrrWorldPos.xyz);
		vec3 hrrWorldDir = normalize(vec3(hrrWorldPos.x, max(hrrWorldPos.y, 0.0), hrrWorldPos.z));

		vec4 intScattTrans = vec4(vec3(0.0), 1.0);
		if(isSkyHRR(texcoord * 2 - vec2(1.0, 0.0)) > 0.5 && camera.y < 5000.0) {
			float d_p2a = RaySphereIntersection(earthPos, hrrWorldDir, vec3(0.0), earth_r + atmosphere_h).y;
			float d_p2e = RaySphereIntersection(earthPos, hrrWorldDirO, vec3(0.0), earth_r).x;
			float d = d_p2e > 0.0 ? d_p2e : d_p2a;
			float dist1 = hrrZ == 1.0 ? d : hrrWorldDis1;

			
			float cloudHitLength = 0.0;
			#ifdef VOLUMETRIC_CLOUDS
				cloudRayMarching(camera, hrrWorldDirO * dist1, intScattTrans, cloudHitLength);
			#endif
			intScattTrans = temporal_cloud3D(intScattTrans);
			intScattTrans.rgb = max(vec3(0.0), intScattTrans.rgb);
			intScattTrans.a = saturate(intScattTrans.a);

			CT3 = intScattTrans;

		}
	}
	
/* DRAWBUFFERS:13 */
	gl_FragData[0] = CT1;
	gl_FragData[1] = CT3;
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
	sunRiseSetS = saturate(1 - isNoonS - isNightS);

	sunColor = getSunColor();
	skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif