varying vec4 glcolor;

varying vec4 vViewPos, vWorldPos, vMcPos;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 normalVO, normalWO;

varying vec3 sunColor, skyColor;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/lighting/shadowMapping.glsl"

#ifdef FSH
flat in float isWater;

#include "/lib/surface/PBR.glsl"
#include "/lib/water/waterNormal.glsl"
#include "/lib/water/waterFog.glsl"
#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/water/translucentLighting.glsl"
#include "/lib/atmosphere/celestial.glsl"

void main() {
	vec2 fragCoord = gl_FragCoord.xy * invViewSize;
	float depth = texture(depthtex0, fragCoord).r;
	float worldDis0 = length(vWorldPos.xyz);
	if(depth < 1.0) {
		discard;
	}

	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);

	bool isUnderwater = (isEyeInWater == 1);
	bool isAbovewater = (isEyeInWater == 0);

	if(isWater > 0.5){
		vec3 waveWorldNormal = getWaveNormalDH(vMcPos.xz, WAVE_NORMAL_ITERATIONS);
		vec3 waveViewNormal = mat3(gbufferModelView) * waveWorldNormal;
		
		vec2 refractCoord = saturate(waterRefractionCoord(normalVO, waveViewNormal, worldDis0));
		float depth1 = texture(depthtex1, refractCoord).r;
		vec4 viewPos1;
		float dhDepth1 = texture(dhDepthTex1, refractCoord).r;
		float dhTerrain = depth1 == 1.0 && dhDepth1 < 1.0 ? 1.0 : 0.0;
		if(dhTerrain > 0.5){
			viewPos1 = screenPosToViewPosDH(vec4(refractCoord, dhDepth1, 1.0));
		}else{
			viewPos1 = screenPosToViewPos(vec4(refractCoord, depth1, 1.0));
		}
		vec3 viewDir = normalize(viewPos1.xyz);
		vec4 worldPos1 = viewPosToWorldPos(viewPos1);
		float worldDis1 = length(worldPos1.xyz);
		vec3 worldDir = normalize(worldPos1.xyz);
		vec4 fWorldPos1 = vec4(min(worldDis1, dhRenderDistance) * worldDir, 1.0);




		#ifdef WATER_REFRACTION
			bool useRefract =  dot(normalize(worldPos1.xyz - vWorldPos.xyz), normalWO) < 0.0;
			vec2 sampleCoord = useRefract ? refractCoord : fragCoord;
			color.rgb = textureLod(gaux1, sampleCoord, 1).rgb * 1.25 * COLOR_UI_SCALE;
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
		vec3 reflectWorldDir = reflect(worldDir, waveWorldNormal);
		vec3 reflectViewDir = reflect(viewDir, waveViewNormal);
	
		float underwaterFactor = isUnderwater ? 0.0 : 1.0;
		bool ssrTargetSampled = false;
		
		float cosTheta = dot(-worldDir, waveWorldNormal);
		float fresnel = mix(pow(1.0 - saturate(cosTheta), REFLECTION_FRESNAL_POWER), 1.0, WATER_F0);

		#ifdef WATER_REFLECTION
			vec3 reflectColor = reflection(
				colortex8, 
				vViewPos.xyz, 
				reflectWorldDir, 
				reflectViewDir, 
				lightmapY * underwaterFactor, 
				normalVO, 
				COLOR_UI_SCALE, 
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
			vec3 BRDF = reflectPBR(viewDir, waveViewNormal, sunViewDir, params);
			float lightmapMask = remapSaturate(lightmapY, 0.5, 1.0, 0.0, 1.0);
			color.rgb += drawCelestial(reflectWorldDir, 1.0, false) * lightmapMask * WATER_REFLECT_HIGH_LIGHT_INTENSITY * 0.5 * float(!ssrTargetSampled);
		#endif

		// float dhDepth0 = texture(dhDepthTex0, fragCoord).r;
		// vec4 viewPos0 = screenPosToViewPosDH(vec4(fragCoord, dhDepth0, 1.0));

		// dhDepth1 = texture(dhDepthTex1, fragCoord).r;
		// viewPos1 = screenPosToViewPosDH(vec4(fragCoord, dhDepth1, 1.0));
		// color.rgb = max(vec3(abs(length(viewPos1.xyz - viewPos0.xyz))), vec3(0.0));
	}else{
		color = vec4(glcolor.rgb * isNoon, 0.5);
	}

	
	
	

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
flat out float isWater;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

void main() {
	gl_Position = ftransform();
	
	isWater = dhMaterialId == DH_BLOCK_WATER ? 1.0 : 0.0;

	vViewPos = gl_ModelViewMatrix * gl_Vertex;
	vWorldPos = viewPosToWorldPos(vViewPos);
	vMcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

	normalVO = normalize(gl_NormalMatrix * gl_Normal);
	normalWO = viewPosToWorldPos(vec4(normalVO, 0.0)).xyz;

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;

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

	sunColor = texelFetch(gaux4, sunColorUV, 0).rgb;
	skyColor = texelFetch(gaux4, skyColorUV, 0).rgb;

	glcolor = gl_Color;
}

#endif