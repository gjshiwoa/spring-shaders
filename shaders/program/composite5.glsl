
#define CPS
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
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/atmosphere/atmosphericScattering.glsl"
#include "/lib/water/waterFog.glsl"


#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;
#include "/lib/atmosphere/fog.glsl"

void main() {
	float depth = texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r;
	float skyB = depth == 1.0 ? 1.0 : 0.0;
	vec4 color = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0);

	#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
		bool isTerrain = skyB < 0.5;

		vec4 viewPos;
		float dhDepth = texelFetch(dhDepthTex0, ivec2(gl_FragCoord.xy), 0).r;
		float dhTerrain = depth == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
		if(dhTerrain > 0.5){ 
			viewPos = screenPosToViewPosDH(vec4(unTAAJitter(texcoord), dhDepth, 1.0));
			depth = viewPosToScreenPos(viewPos).z;
		}else{
			viewPos = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth, 1.0));	
		}

		isTerrain = isTerrain || dhTerrain > 0.5;
	#else 
		bool isTerrain = skyB < 0.5;

		vec4 viewPos = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth, 1.0));	
	#endif

	vec4 worldPos = viewPosToWorldPos(viewPos);
	float worldDis = length(worldPos);
	vec3 worldDir = normalize(worldPos.xyz);

	#if defined UNDERWATER_FOG || defined ATMOSPHERIC_SCATTERING_FOG || defined VOLUMETRIC_FOG
		vec4 fogColor = getFog(depth);
		// if(dot(fogColor.rgb, fogColor.rgb) < 1e-7){
		// 	fogColor.a = 1.0;
		// }
		#ifdef UNDERWATER_FOG
			if(isEyeInWater == 1){
				color.rgb = mix(color.rgb, fogColor.rgb, saturate(worldDis / UNDERWATER_FOG_MIST));
				color.rgb += waterFogColor * rand2_1(texcoord + sin(frameTimeCounter)) / 512.0;
			}
		#endif
		
		#ifdef ATMOSPHERIC_SCATTERING_FOG
			if(isEyeInWater == 0 && depth > 0.7){
				if(isTerrain){
					color.rgb *= Transmittance1(earthPos, earthPos + worldPos.xyz * ATMOSPHERIC_SCATTERING_FOG_DENSITY, VOLUME_LIGHT_SAMPLES);
				}
				color.rgb *= fogColor.a;
				color.rgb += fogColor.rgb;
			}
		#endif
		// color.rgb = vec3(fogColor.rgb);
	#endif

	// color.rgb = texture(colortex1, texcoord).rgb;
	
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

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif