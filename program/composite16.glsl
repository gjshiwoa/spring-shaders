

varying vec2 texcoord;
varying float curLum, preLum;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying float isNoon, isNight, sunRiseSet;
// varying float isNoonS, isNightS, sunRiseSetS;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/position.glsl"

#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;


#include "/lib/camera/depthOfField.glsl"

void main() {
	vec4 color = texture(colortex0, texcoord);

	#define BLOOM_UPSAMPLE
	vec3 blur = vec3(0.0);
	#ifdef BLOOM
		#include "/lib/camera/bloom1.glsl"
	#endif

	float bloomAmount = BLOOM_AMOUNT;
	#if defined NETHER
		bloomAmount += NETHER_ADDITIONAL_BLOOM;
	#elif defined END
		bloomAmount += END_ADDITIONAL_BLOOM;
	#else
		bloomAmount += rainStrength * RAIN_ADDITIONAL_BLOOM;
		bloomAmount += isNight * NIGHT_ADDITIONAL_BLOOM;
		// bloomAmount += max(isNight, 1.0 - eyeBrightnessSmooth.y/240.0) * 0.05;

		if(isEyeInWater == 1){
			bloomAmount += UNDERWATER_ADD_BLOOM;
		}
	#endif

	color.rgb += blur * bloomAmount;

	color.rgb = max(color.rgb, BLACK);
	


	vec4 CT2 = texture(colortex2, texcoord);
    if(ivec2(gl_FragCoord.xy) == vec2(0.0)){
        float AverageLum = mix(preLum, curLum, saturate(frameTime*2.0));
        CT2.a = AverageLum;
    }

	

	vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
	#ifdef DEPTH_OF_FIELD
		CT1.r = calculateCoC();
	#endif


/* DRAWBUFFERS:012 */
	gl_FragData[0] = color;
	gl_FragData[1] = CT1;
	gl_FragData[2] = CT2;

}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////ZYPanDa////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

#include "/lib/camera/bloom1.glsl"
#define CALCULATE_AVERAGE_LUMINANCE
#include "/lib/camera/exposure.glsl"

void main() {
	
	#if EXPOSURE_MODE == 0
		curLum = calculateAverageLuminance();
	#else
		curLum = calculateAverageLuminance1();
	#endif
	preLum = texelFetch(colortex2, averageLumUV, 0).a;

	sunViewDir = normalize(sunPosition);
	moonViewDir = normalize(moonPosition);
	lightViewDir = normalize(shadowLightPosition);

	sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

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

	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	// isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	// isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	// sunRiseSetS = saturate(1 - isNoonS - isNightS);

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif