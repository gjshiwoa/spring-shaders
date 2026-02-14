
#define CPS

varying vec2 texcoord;

// varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
// varying vec3 sunViewDir, moonViewDir, lightViewDir;

// varying vec3 sunColor, skyColor;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
// #include "/lib/atmosphere/atmosphericScattering.glsl"


#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;
// #include "/lib/water/waterFog.glsl"
#include "/lib/camera/equalWeightBlur.glsl"

void main() {
	vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

	vec2 uv = texcoord * 2.0 - vec2(0.0, 1.0);
	vec4 fogColor = vec4(0.0, 0.0, 0.0, 1.0);

	#if defined UNDERWATER_FOG || defined ATMOSPHERIC_SCATTERING_FOG || defined VOLUMETRIC_FOG
		bool useFilter = false;
		useFilter = !outScreen(uv);
		
		if(useFilter){
			fogColor = JointBilateralFiltering_hrr_Vertical();
			fogColor.rgb = max(fogColor.rgb, vec3(0.0));
			fogColor.a = saturate(fogColor.a);
			CT1 = fogColor;
		}
	#endif
	
/* DRAWBUFFERS:1 */
	gl_FragData[0] = CT1;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa gjshiwoa////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	// sunViewDir = normalize(sunPosition);
	// moonViewDir = normalize(moonPosition);
	// lightViewDir = normalize(shadowLightPosition);

	// sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    // moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    // lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

	// sunColor = getSunColor();
	// skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif