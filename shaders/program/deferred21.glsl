#define VOXY_WATER

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

#include "/lib/surface/PBR.glsl"
#include "/lib/common/gbufferData.glsl"
#include "/lib/lighting/pathTracing.glsl"
#include "/lib/lighting/lightmap.glsl"
#include "/lib/water/waterFog.glsl"
#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/common/octahedralMapping.glsl"
#include "/lib/atmosphere/celestial.glsl"

void main() {
	vec4 color = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0);
	vec4 vxTransColor = texelFetch(colortex16, ivec2(gl_FragCoord.xy), 0);
	vec2 lmcoord = texelFetch(colortex18, ivec2(gl_FragCoord.xy), 0).rg;

	float vxdepth0 = texelFetch(vxDepthTexTrans, ivec2(gl_FragCoord.xy), 0).r;
	vec4 viewPos0 = screenPosToViewPosVX(vec4(unTAAJitter(texcoord), vxdepth0, 1.0));
	vec4 worldPos0 = viewPosToWorldPos(viewPos0);
	vec3 worldDir = normalize(worldPos0.xyz);
	float worldDis0 = length(worldPos0.xyz);
	
	float CT19 = texelFetch(colortex19, ivec2(gl_FragCoord.xy), 0).r;
	float depth1 = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
	float vxDepth1 = texelFetch(vxDepthTexOpaque, ivec2(gl_FragCoord.xy), 0).r;
	bool vxTemp = CT19 < 0.9;
	bool vxWater = abs(vxTransColor.a - 0.97) < 0.015 && vxTemp;
	bool vxTrans = vxTransColor.a < 0.96 && vxTransColor.a > 0.005 && vxTemp;

	bool isUnderwater = (isEyeInWater == 1);
	bool isAbovewater = (isEyeInWater == 0);

	vec4 vxTransData0 = texelFetch(colortex17, ivec2(gl_FragCoord.xy), 0);
	vec2 vxTransData1 = texelFetch(colortex18, ivec2(gl_FragCoord.xy), 0).rg;

	vec3 normalV = normalize(normalDecode(vxTransData0.rg));
	vec3 normalVO = normalize(normalDecode(vxTransData0.ba));
	vec3 normalW = mat3(gbufferModelViewInverse) * normalV;
	vec3 normalWO = mat3(gbufferModelViewInverse) * normalVO;

	if(vxWater){
		vec2 refractCoord = saturate(waterRefractionCoord(normalVO, normalV, worldDis0, WAVE_REFRACTION_INTENSITY));
		refractCoord = texcoord;
		float vxDepth1 = texelFetch(vxDepthTexOpaque, ivec2(refractCoord * viewSize), 0).r;
		vec4 viewPos1 = screenPosToViewPosVX(vec4(unTAAJitter(refractCoord), vxDepth1, 1.0));
		vec3 viewDir = normalize(viewPos1.xyz);
		vec4 worldPos1 = viewPosToWorldPos(viewPos1);
		float worldDis1 = length(worldPos1.xyz);
		vec3 worldDir1 = normalize(worldPos1.xyz);

		#ifdef WATER_REFRACTION
			bool useRefract =  dot(normalize(worldPos1.xyz - worldPos0.xyz), normalWO) < 0.0;
			vec2 sampleCoord = useRefract ? refractCoord : texcoord;
			color.rgb = textureLod(colortex0, sampleCoord, 0).rgb * 1.25;
		#endif


		float deep = worldDis1 - worldDis0;
		vec3 fogColor = waterFogColor * (mix(vec3(getLuminance(sunColor)), sunColor, 0.5) * 0.125 + NIGHT_VISION_BRIGHTNESS * nightVision);

		float lightmapY = 0.85;

		if (isAbovewater) {
			float depthFactor = saturate(deep / WATER_MIST_VISIBILITY);
			vec3 fogAttenuation = saturate(exp(-(vec3(1.0) - fogColor) * deep * WATER_FOG_TRANSMIT));
			
			color.rgb *= fogAttenuation;
			color.rgb = mix(color.rgb, fogColor * 0.25 * lightmapY, depthFactor);
		}



		float TIR = 0.0;
		vec3 reflectWorldDir = reflect(worldDir, normalW);
		vec3 reflectViewDir = reflect(viewDir, normalV);
	
		float underwaterFactor = isUnderwater ? 0.0 : 1.0;
		bool ssrTargetSampled = false;
		
		float cosTheta = dot(-worldDir, normalW);
		float fresnel = mix(pow(1.0 - saturate(cosTheta), REFLECTION_FRESNAL_POWER), 1.0, WATER_F0);

		#ifdef WATER_REFLECTION
			vec3 reflectColor = reflection(
				colortex2, 
				viewPos0.xyz, 
				reflectWorldDir, 
				reflectViewDir, 
				lightmapY * underwaterFactor, 
				normalVO, 
				1.0, 
				ssrTargetSampled
			);

			reflectColor *= saturate(dot(normalWO, upWorldDir) + 0.1);
			
			if (isAbovewater) {
				color.rgb = mix(color.rgb, reflectColor, fresnel);
			} else {
				color.rgb += fogColor * 0.2 * lightmapY * TIR;
				color.rgb = mix(color.rgb, reflectColor, saturate(float(ssrTargetSampled) * TIR));
			}
		#endif




		#ifdef WATER_REFLECT_HIGH_LIGHT
			MaterialParams params;
			params.roughness = 0.5;
			params.metalness = 0.5;
			vec3 BRDF = reflectPBR(viewDir, normalV, sunViewDir, params);
			float lightmapMask = remapSaturate(lightmapY, 0.5, 1.0, 0.0, 1.0);
			color.rgb += drawCelestial(reflectWorldDir, 1.0, false) * lightmapMask * WATER_REFLECT_HIGH_LIGHT_INTENSITY * 0.5 * float(!ssrTargetSampled);
		#endif

	}else if(vxTrans){
		vec4 texColor = toLinearR(vxTransColor);
		vec2 lightmap = AdjustLightmap(lmcoord);
		vec3 vxTrans = vec3(0.0);
		vxTrans += texColor.rgb * saturate(lightmap.y + 0.0005) * (sunColor * saturate(lightmap.y) * 0.5 + skyColor) * 0.5;
		vxTrans += nightVision * texColor.rgb * NIGHT_VISION_BRIGHTNESS / PI;
		color.rgb = mix(color.rgb, vxTrans, vxTransColor.a);
	}
	// color.rgb = vec3(vxWater);

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZY//////////////////////////////////////////////////////////////////////////////
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