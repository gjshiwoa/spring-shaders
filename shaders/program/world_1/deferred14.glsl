varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"

#include "/lib/camera/filter.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;
#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/pathTracing.glsl"
#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/surface/PBR.glsl"

void main() {
	vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
	
#ifdef PBR_REFLECTIVITY
	vec2 hrrUV = texcoord * 2.0 - 1.0;
	if(!outScreen(hrrUV)){
		vec4 hrrSpecularMap = unpack2x16To4x8(texelFetch(colortex4, ivec2(gl_FragCoord.xy * 2 - viewSize), 0).ba);
		MaterialParams params = MapMaterialParams(hrrSpecularMap);
		if(hrrSpecularMap.r > 0.5 / 255.0){
			CT1.rgb = JointBilateralFiltering_Refl_Vertical();
		}	

		CT1.rgb = max(vec3(0.0), CT1.rgb);
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
	sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
    moonWorldDir = sunWorldDir;
    lightWorldDir = sunWorldDir;

	sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
	moonViewDir = sunViewDir;
	lightViewDir = sunViewDir;

	sunColor = endColor * 1.5;
	skyColor = endColor * 0.2 + vec3(0.2);

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif