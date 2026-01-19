varying vec2 texcoord;

// varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
// varying vec3 sunViewDir, moonViewDir, lightViewDir;

// varying float isNoon, isNight, sunRiseSet;
// varying vec3 sunColor, skyColor;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

#include "/lib/common/position.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

void main() {
	vec4 CT7 = texture(colortex7, texcoord);
	
	ivec2 iTexcoord = ivec2(gl_FragCoord.xy);

	if(ivec2(gl_FragCoord.xy) == rightLitPreUV){
		vec4 newColor = texelFetch(colortex7, rightLitUV, 0);
		vec4 preColor = texelFetch(colortex7, rightLitPreUV, 0);
		CT7 = mix(preColor, newColor, 0.05);
	}
		
	if(ivec2(gl_FragCoord.xy) == LeftLitPreUV){
		vec4 newColor = texelFetch(colortex7, LeftLitUV, 0);
		vec4 preColor = texelFetch(colortex7, LeftLitPreUV, 0);
		CT7 = mix(preColor, newColor, 0.05);
	}


/* DRAWBUFFERS:7 */
	gl_FragData[0] = CT7;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	// sunViewDir = normalize(sunPosition);
	// moonViewDir = normalize(moonPosition);
	// lightViewDir = normalize(shadowLightPosition);

	// sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    // moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    // lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

	// isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	// isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	// sunRiseSet = saturate(1 - isNoon - isNight);

	// float isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	// float isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	// float sunRiseSetS = saturate(1 - isNoonS - isNightS);

	// float d1 = RaySphereIntersection(earthPos, upWorldDir, vec3(0.0), earth_r + atmosphere_h).y;
	// // vec3 worldPos, vec3 lightDir, vec3 I, float mieAmount, const int N_SAMPLES, const int lutSampleGap
	// mat2x3 atmosphericScattering = AtmosphericScattering(upWorldDir * d1, upWorldDir, sunWorldDir, IncomingLight, 0.0, ATMOSPHERE_SCATTERING_SAMPLES);
	// vec3 zenithColor = atmosphericScattering[0] + atmosphericScattering[1];
	// atmosphericScattering = AtmosphericScattering(upWorldDir * d1, upWorldDir, moonWorldDir, IncomingLight_N * 1.5, 0.0, int(ATMOSPHERE_SCATTERING_SAMPLES * 0.5));
	// zenithColor += atmosphericScattering[0] + atmosphericScattering[1];

	// sunColor = isNoon * TransmittanceToAtmosphere(earthPos, sunWorldDir) * IncomingLight;
	// sunColor += isNight * TransmittanceToAtmosphere(earthPos, moonWorldDir) * IncomingLight_N;
	// sunColor *= 1.0 - 0.75 * rainStrength;
	
	// skyColor = zenithColor;
	// skyColor *= 3.0;
	// skyColor *= 1.0 - 0.3 * rainStrength;
}

#endif