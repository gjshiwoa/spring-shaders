varying vec2 lmcoord, texcoord;

varying vec3 normalVO, normalWO;

varying vec4 glcolor;

varying float worldDis0;
varying vec4 vViewPos, vWorldPos, vMcPos;
varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;
varying vec3 zenithColor, horizonColor;

varying mat3 tbnMatrix;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"
#include "/lib/atmosphere/celestial.glsl"

#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/shadowMapping.glsl"

#include "/lib/water/waterNormal.glsl"
#include "/lib/water/waterFog.glsl"
#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/surface/PBR.glsl"

#ifdef FSH
#include "/lib/water/translucentLighting.glsl"
// #include "/lib/atmosphere/volumetricClouds.glsl"

const bool colortex5MipmapEnabled = true;

flat in float isWater, isIce;

void main() {
	bool isUnderwater = (isEyeInWater == 1);
	bool isAbovewater = (isEyeInWater == 0);
	
	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);
	vec2 parallaxUV = texcoord;
	vec2 fragCoord = gl_FragCoord.xy * invViewSize;
	// original underwater position
	float depth1O = texture(depthtex1, fragCoord).r;
	vec4 viewpos1O = screenPosToViewPos(vec4(fragCoord, depth1O, 1.0));
	vec3 viewDir = normalize(viewpos1O.xyz);
	vec4 worldPos1O = viewPosToWorldPos(viewpos1O);
	vec3 worldDir = normalize(worldPos1O.xyz);

	vec4 mcPos = vMcPos;

	vec4 texColor = texture(tex, texcoord) * glcolor;
	if(texColor.a < 0.005) discard;
	vec4 color = vec4(BLACK, 1.0);

	vec3 normalTexV = normalize(tbnMatrix * (textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0));
	vec3 normalTexW = normalize(gbufferModelViewInverse * vec4(normalTexV, 0.0)).xyz;
	vec4 specularMap = texture(specular, texcoord);

	vec2 lightmap = AdjustLightmap(lmcoord);
	
	if(isWater > 0.5){
		vec3 viewDirTS = normalize(vViewPos.xyz * tbnMatrix);
		float parallaxHeight = 1.0;
		vec2 waveParallaxUV = mcPos.xz;
		#ifdef WAVE_PARALLAX
			waveParallaxUV = waveParallaxMapping(mcPos.xz, viewDirTS, parallaxHeight);
		#endif
		vec3 waveViewNormal = normalize(tbnMatrix * getWaveNormal(waveParallaxUV));
		vec3 waveWorldNormal = viewPosToWorldPos(vec4(waveViewNormal, 0.0)).xyz;
 


		// camera above water surface
		// underwater position with refraction offset
		vec2 refractCoord = saturate(waterRefractionCoord(normalVO, waveViewNormal, worldDis0));
		float depth1 = texture(depthtex1, refractCoord).r;
		vec4 viewPos1 = screenPosToViewPos(vec4(refractCoord, depth1, 1.0));
		vec4 worldPos1 = viewPosToWorldPos(viewPos1);
		#if MC_VERSION < 11400
			worldPos1 -= vec4(0.0, 2.0, 0.0, 0.0);
		#endif
		float worldDis1 = length(worldPos1.xyz);
		vec3 worldDir = normalize(worldPos1.xyz);
		vec4 fWorldPos1 = vec4(min(worldDis1, far) * worldDir, 1.0);

		

		// 全内反射判定
		float cosI = dot(-worldDir, waveWorldNormal);
		float sinT2 = WATER_REFRAT_IOR * WATER_REFRAT_IOR * (1.0 - cosI * cosI);
		#ifdef UNDERWATER_REFLECTION
			float TIR = step(1.0, sinT2);
		#else
			float TIR = 0.0;
		#endif

		#ifdef WATER_REFRACTION
			// 折射（法线不朝上，或碰撞点低于水面时折射）
			bool useRefract = (worldPos1.y < vWorldPos.y || normalWO.y < 0.5);
			vec2 sampleCoord = useRefract ? refractCoord : fragCoord;
			vec3 colorRGB = textureLod(gaux1, sampleCoord, 1).rgb * 1.25;

			worldPos1 = mix(worldPos1O, worldPos1, float(useRefract));
			worldDis1 = mix(length(worldPos1O.xyz), worldDis1, float(useRefract));

			// 全内反射
			float TIRFactor = 1.0;
			if(useRefract && isUnderwater) {
				TIRFactor = (1.0 - TIR) * eyeBrightnessSmooth.y / 240.0;
			}
			colorRGB *= TIRFactor;
			color = vec4(colorRGB * COLOR_UI_SCALE, 1.0);
		#endif
		


		float deep = worldDis1 - worldDis0;
		vec3 fogColor = waterFogColor * (mix(vec3(getLuminance(sunColor)), sunColor, 0.5) * 0.125 + NIGHT_VISION_BRIGHTNESS * nightVision);

		float lightmapY = saturate(lightmap.y + NIGHT_VISION_BRIGHTNESS * nightVision + 0.015);

		if (isAbovewater) {
			float depthFactor = saturate(deep / WATER_MIST_VISIBILITY);
			vec3 fogAttenuation = saturate(fastExp(-(vec3(1.0) - fogColor) * deep * WATER_FOG_TRANSMIT));
			
			color.rgb *= fogAttenuation;
			color.rgb = mix(color.rgb, fogColor * 0.25 * lightmapY, depthFactor);
		}



		
		vec3 reflectWorldDir = reflect(worldDir, waveWorldNormal);
		vec3 reflectViewDir = reflect(viewDir, waveViewNormal);
	
		float underwaterFactor = isUnderwater ? 0.0 : 1.0;
		int ssrTargetSampled = 0;
		
		float cosTheta = dot(-worldDir, waveWorldNormal);
		float fresnel = mix(pow(1.0 - saturate(cosTheta), REFLECTION_FRESNAL_POWER), 1.0, WATER_F0);

		#ifdef WATER_REFLECTION
			vec3 reflectColor = reflection(
				gaux1, 
				vViewPos.xyz, 
				reflectWorldDir, 
				reflectViewDir, 
				lightmapY * underwaterFactor, 
				normalVO, 
				COLOR_UI_SCALE, 
				ssrTargetSampled
			);
			
			if (isAbovewater) {
				color.rgb = mix(color.rgb, reflectColor, fresnel);
			} else {
				color.rgb += fogColor * 0.2 * lightmapY * TIR;
				color.rgb = mix(color.rgb, reflectColor + vec3(0.005), saturate(float(ssrTargetSampled) * TIR));
			}
		#endif

		if (isUnderwater) {
			float phase = hgPhase1(dot(sunWorldDir, worldDir), UNDERWATER_FOG_G);
			float distanceFactor = saturate(worldDis0 / (UNDERWATER_FOG_MIST * 0.5));
			#ifndef UNDERWATER_REFLECTION
				distanceFactor = pow(saturate(distanceFactor + 0.1), 0.1);
			#endif
			float skyBrightness = eyeBrightnessSmooth.y / 240.0 + 0.1;
			color.rgb = mix(
				color.rgb, 
				fogColor * 2.0 * phase * lightmapY * skyBrightness, 
				distanceFactor
			);
		}
		


		#ifdef WATER_REFLECT_HIGH_LIGHT
			float shade = 1.0;
			#if MC_VERSION < 11400
				
			#else
				#ifdef TRANSLUCENT_SHADOW
					shade = shadowMappingTranslucent(vWorldPos, normalTexW, 0.5, 1.0);
				#endif
			#endif
			MaterialParams params;
			params.roughness = 0.5;
			params.metalness = 0.5;
			vec3 BRDF = reflectPBR(viewDir, waveViewNormal, sunViewDir, params);
			float lightmapMask = remapSaturate(lightmap.y, 0.5, 1.0, 0.0, 1.0) * shade;
			// color.rgb *= 1.0 + 1.0 *  sunColor * BRDF * pow(saturate(dot(waveViewNormal, lightViewDir)), 1.0) * lightmapMask * sunRiseSetS;
			color.rgb += drawCelestial(reflectWorldDir, 1.0, false) * lightmapMask * WATER_REFLECT_HIGH_LIGHT_INTENSITY * 0.5;
			// vec3 waveWorldNormal_diffuse = normalize(vec3(waveWorldNormal.x, waveWorldNormal.y * 0.333, waveWorldNormal.z));
			// color.rgb *= 1.0 + 0.075 * sunColor * vec3(pow(saturate(dot(waveWorldNormal_diffuse, lightWorldDir)), 1.0)) * lightmap.y * lightmapMask * WATER_REFLECT_HIGH_LIGHT_INTENSITY;
		#endif





	}else{
		color.a = texColor.a;
		vec3 albedo = toLinearR(texColor.rgb);
		vec3 diffuse = albedo / PI;

		MaterialParams materialParams = MapMaterialParams(specularMap);
		if(dot(specularMap.rgb, vec3(1.0)) < 0.001){
			materialParams.smoothness = TRANSLUCENT_ROUGHNESS;
			float perceptual_roughness = 1.0 - materialParams.smoothness;
    		materialParams.roughness = perceptual_roughness * perceptual_roughness;
			materialParams.metalness = TRANSLUCENT_F0;
		}
		#ifdef PBR_REFLECTIVITY
			mat2x3 PBR = CalculatePBR(viewDir, normalTexV, lightViewDir, albedo, materialParams);
			vec3 BRDF = PBR[0] + PBR[1];
			vec3 BRDF_D = vec3(1.0 - materialParams.metalness * 0.9) * diffuse;
		#else
			vec3 BRDF = diffuse;
			vec3 BRDF_D = BRDF;
		#endif

		float cos_theta_O = dot(normalTexW, lightWorldDir);
		float cos_theta = max(cos_theta_O, 0.0);



		float UoN = dot(normalTexW, upWorldDir);
		vec3 skyColorMix = mix(sunColor, skyColor, 0.98 - 0.05 * lightmap.y);
		float hemiWeight = mix(1.0, UoN * 0.5 + 0.5, 0.66);
		vec3 skyLight = lightmap.y * BRDF_D * skyColorMix * hemiWeight;

		float shade = 1.0;
		#if MC_VERSION < 11400
			
		#else
			#ifdef TRANSLUCENT_SHADOW
				shade = shadowMappingTranslucent(vWorldPos, normalTexW, TRANSLUCENT_SHADOW_SOFTNESS, TRANSLUCENT_SHADOW_QUALITY);
			#endif
		#endif
		#ifdef NETHER
			shade = 0.0;
		#endif
		vec3 direct = sunColor * BRDF * shade * cos_theta;
		


		vec3 artificial = lightmap.x * artificial_color * diffuse;
		artificial += saturate(materialParams.emissiveness) * diffuse * EMISSIVENESS_BRIGHTNESS;

		

		vec3 c = albedo * 0.005;
		c += skyLight * SKY_LIGHT_BRIGHTNESS * 1.0;
		c += nightVision * diffuse * NIGHT_VISION_BRIGHTNESS;
		c += direct * DIRECT_LUMINANCE * 1.0;
		c += artificial;



		#ifdef PBR_REFLECTIVITY
		{
			vec3 reflectWorldDir = reflect(worldDir, normalTexW);
			vec3 reflectViewDir = reflect(viewDir, normalTexV);
			float NdotU = dot(upWorldDir, reflectWorldDir);
			float upDirFactor = smoothstep(-1.0, 0.0, NdotU);
			int ssrTargetSampled = 0;	
			vec3 reflectColor = reflection(gaux1, vViewPos.xyz, reflectWorldDir, reflectViewDir, 
											lightmap.y * upDirFactor, normalTexV, COLOR_UI_SCALE, ssrTargetSampled);
			float NdotV = saturate(dot(normalTexV, -viewDir));

			vec3 F0 = mix(vec3(0.04), albedo, materialParams.metalness); 
			vec3 BRDF = EnvDFGLazarov(F0, materialParams.smoothness, NdotV) * pow(materialParams.smoothness, 1.0 / MIRROR_INTENSITY);

			c += reflectColor * BRDF;
			// c = mix(c, reflectColor + PBR[1] * shade * albedo * sunColor * cos_theta, F_Schlick(NdotV, F0));
			// c = reflectColor;
		}
		#endif



		#define TRANSLUCENT_MODE 1
		#if TRANSLUCENT_MODE == 0
			color.rgb = mix(texture(gaux1, fragCoord).rgb * COLOR_UI_SCALE, c, color.a);
			color.a = 1.0;
		#elif TRANSLUCENT_MODE == 1
			color.rgb = c;
		#elif TRANSLUCENT_MODE == 2
			color.rgb = albedo * lightmap.y * sunColor * 0.2;
		#endif
	}

	// color.rgb = texture(depthtex0, fragCoord.xy).rgb;

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
// #include "/lib/common/noise.glsl"
flat out float isWater, isIce;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

void main() {
	gl_Position = ftransform();
	isWater = mc_Entity.x == 8 ? 1.0 : 0.0;
	isIce = mc_Entity.x == 79 ? 1.0 : 0.0;

	vViewPos = gl_ModelViewMatrix * gl_Vertex;
	vWorldPos = viewPosToWorldPos(vViewPos);
	#if MC_VERSION < 11400
		vWorldPos -= vec4(0.0, 2.0, 0.0, 0.0);
	#endif
	worldDis0 = length(vWorldPos.xyz);
	vMcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

	// vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	// jitter *= invViewSize;
	// gl_Position.xyz /= gl_Position.w;
    // gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    // gl_Position.xyz *= gl_Position.w;

	// TBN Mat 参考自 BSL shader
	vec3 N = normalize(gl_NormalMatrix * gl_Normal);
	vec3 B = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	vec3 T = normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix = mat3(T, B, N);
	// T_tbnMatrix = transpose(tbnMatrix);

	normalVO = N;
	normalWO = viewPosToWorldPos(vec4(N, 0.0)).xyz;

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

	sunColor = texelFetch(gaux2, SUN_COLOR_UV, 0).rgb;
	skyColor = texelFetch(gaux2, SKY_COLOR_UV, 0).rgb;
	zenithColor = texelFetch(gaux2, ZENITH_COLOR_UV, 0).rgb;
	horizonColor = texelFetch(gaux2, HORIZON_COLOR_UV, 0).rgb;

	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}

#endif