
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
#include "/lib/atmosphere/fog.glsl"

void main() {
	vec4 color = texture2D(colortex0, texcoord);
	float depth = texture2D(depthtex0, texcoord).r;
	vec4 viewPos = screenPosToViewPos(vec4(texcoord, depth, 1.0));
	vec4 worldPos = viewPosToWorldPos(viewPos);
	float worldDis = length(worldPos);
	vec3 worldDir = normalize(worldPos.xyz);

	vec4 fogColor = getFog(depth);
	// if(dot(fogColor.rgb, fogColor.rgb) < 1e-9){
	// 	fogColor.a = 1.0;
	// }

	// #if defined UNDERWATER_FOG || defined ATMOSPHERIC_SCATTERING_FOG
	// 	#ifdef UNDERWATER_FOG
	// 		if(isEyeInWater == 1){
	// 			color.rgb = mix(color.rgb, fogColor.rgb, pow(saturate(worldDis / UNDERWATER_FOG_MIST), 1.0));
	// 			color.rgb += waterFogColor * rand2_1(texcoord + sin(frameTimeCounter)) / 512.0;
	// 		}
	// 	#endif
		
	// 	#ifdef ATMOSPHERIC_SCATTERING_FOG
	// 		if(isEyeInWater == 0 && depth > 0.7){
	// 			if(depth < 1.0){
	// 				color.rgb *= Transmittance1(earthPos, earthPos + worldPos.xyz * ATMOSPHERIC_SCATTERING_FOG_DENSITY, VOLUME_LIGHT_SAMPLES);
	// 			}
	// 			color.rgb *= fogColor.a;
	// 			color.rgb += fogColor.rgb;
	// 		}
	// 	#endif
	// 	// color.rgb = fogColor.rgb;
	// #endif
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
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

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif