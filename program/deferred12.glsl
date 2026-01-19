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
	vec4 CT3 = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0);
	
#ifdef PBR_REFLECTIVITY
	vec2 hrrUV = texcoord * 2.0 - 1.0;
	vec3 reflectColor = BLACK;
	if(!outScreen(hrrUV)){
		vec4 hrrSpecularMap = unpack2x16To4x8(texelFetch(colortex4, ivec2(gl_FragCoord.xy * 2 - viewSize), 0).ba);
		MaterialParams params = MapMaterialParams(hrrSpecularMap);
		if(hrrSpecularMap.r > 0.5 / 255.0){
			vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy - 0.5 * viewSize), 0);
			float hrrZ = CT6.g;
			vec4 hrrViewPos = screenPosToViewPos(vec4(unTAAJitter(hrrUV), hrrZ, 1.0));
			vec3 hrrViewDir = normalize(hrrViewPos.xyz);
			vec4 hrrWorldPos = viewPosToWorldPos(hrrViewPos);
			vec3 hrrWorldDir = normalize(hrrWorldPos.xyz);

			vec3 hrrNormalW = unpackNormal(CT6.r);
			vec3 hrrNormalV = normalize(gbufferModelView * vec4(hrrNormalW, 0.0)).xyz;
			vec3 hrrNormalVO = normalize(normalDecode(texelFetch(colortex9, ivec2(gl_FragCoord.xy * 2.0 - viewSize), 0).ba));

			vec2 mcLightmap = texelFetch(colortex5, ivec2(gl_FragCoord.xy * 2 - viewSize), 0).ba;
			vec2 lightmap = AdjustLightmap(mcLightmap);

			float r = params.roughness;

			const int reflectionSamples = PBR_REFLECTION_DIR_COUNT;
			vec3 accumulatedReflectColor = vec3(0.0);
			for(int sampleIndex = 0; sampleIndex < reflectionSamples; ++sampleIndex){
				vec3 sampleReflectViewDir = normalize(reflect(hrrViewDir, hrrNormalV));
				sampleReflectViewDir = getScatteredReflection(sampleReflectViewDir, hrrNormalVO, r, sampleIndex);
				vec3 sampleReflectWorldDir = normalize(viewPosToWorldPos(vec4(sampleReflectViewDir.xyz, 0.0)).xyz);

				float NdotU = dot(upWorldDir, sampleReflectWorldDir);
				float sampleLightmapY = lightmap.y * smoothstep(-1.0, 1.0, NdotU);

				bool ssrTargetSampled = false;
				vec3 sampleColor = reflection(colortex2, hrrViewPos.xyz, sampleReflectWorldDir, sampleReflectViewDir, sampleLightmapY, hrrNormalVO, 1.0, ssrTargetSampled);
				sampleColor = clamp(sampleColor, 0.001, 10.0);
				accumulatedReflectColor += sampleColor;
			}

			reflectColor = accumulatedReflectColor / float(reflectionSamples);
			reflectColor = temporal_Reflection(reflectColor, reflectionSamples, r);
			
			CT3.rgb = reflectColor;
		}	

		CT3.rgb = max(vec3(0.0), CT3.rgb);
	}
#endif

/* DRAWBUFFERS:3 */
	gl_FragData[0] = CT3;
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

	sunColor = getSunColor();
	skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif