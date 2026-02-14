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

varying mat3 tbnMatrix;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"

#include "/lib/atmosphere/celestial.glsl"

#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/shadowMapping.glsl"

#include "/lib/water/waterNormal.glsl"
#include "/lib/water/waterFog.glsl"
#include "/lib/lighting/pathTracing.glsl"
#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/surface/PBR.glsl"

#ifdef FSH
#include "/lib/water/translucentLighting.glsl"
#include "/lib/surface/ripple.glsl"


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
	vec4 viewPos1O = screenPosToViewPos(vec4(fragCoord, depth1O, 1.0));
	#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
		float dhDepth = texture(dhDepthTex1, fragCoord).r;
		float dhTerrain = depth1O == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
		if(dhTerrain > 0.5){
			viewPos1O = screenPosToViewPosDH(vec4(fragCoord, dhDepth, 1.0));
		}
	#endif
	vec3 viewDir = normalize(viewPos1O.xyz);
	vec4 worldPos1O = viewPosToWorldPos(viewPos1O);
	vec3 worldDir = normalize(worldPos1O.xyz);

	vec4 mcPos = vMcPos;

	vec4 texColor = texture(tex, texcoord) * glcolor;
	if(texColor.a < 0.5 / 255.0) discard;
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
 
		#ifdef RIPPLE
			bool upFace = dot(normalVO, upViewDir) > 0.1;
			float wetFactor = smoothstep(0.88, 0.95, lmcoord.y) * rainStrength * float(biome_precipitation == 1);
			if(upFace && wetFactor > 0.001 && worldDis0 < RIPPLE_DISTANCE){
				waveWorldNormal = RipplePerturbNormalWS(waveParallaxUV, waveWorldNormal, worldDis0, wetFactor);
				waveViewNormal = mat3(gbufferModelView) * waveWorldNormal;
			}
		#endif



		// camera above water surface
		// underwater position with refraction offset
		vec2 refractCoord = saturate(waterRefractionCoord(normalVO, waveViewNormal, worldDis0, WAVE_REFRACTION_INTENSITY));
		float depth1 = texture(depthtex1, refractCoord).r;
		vec4 viewPos1 = screenPosToViewPos(vec4(refractCoord, depth1, 1.0));
		#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
			float dhDepth = texture(dhDepthTex1, refractCoord).r;
			float dhTerrain = depth1 == 1.0 && dhDepth < 1.0 ? 1.0 : 0.0;
			if(dhTerrain > 0.5){
				viewPos1 = screenPosToViewPosDH(vec4(refractCoord, dhDepth, 1.0));
			}
		#endif
		vec4 worldPos1 = viewPosToWorldPos(viewPos1);
		#if MC_VERSION < 11400
			worldPos1 -= vec4(0.0, 2.0, 0.0, 0.0);
		#endif
		float worldDis1 = length(worldPos1.xyz);
		vec3 worldDir1 = normalize(worldPos1.xyz);
		// vec4 fWorldPos1 = vec4(min(worldDis1, far) * worldDir, 1.0);

		

		// 全内反射判定
		float cosI = dot(-worldDir, waveWorldNormal);
		float sinT2 = WATER_REFRAT_IOR * WATER_REFRAT_IOR * (1.0 - cosI * cosI);
		#ifdef UNDERWATER_REFLECTION
			float TIR = step(1.0, sinT2);
		#else
			float TIR = 0.0;
		#endif

		#ifdef WATER_REFRACTION
			bool useRefract = dot(normalize(worldPos1.xyz - vWorldPos.xyz), normalWO) < -0.01;
			vec2 sampleCoord = useRefract ? refractCoord : fragCoord;
			vec3 colorRGB = textureLod(gaux1, sampleCoord, 1).rgb * 1.25;

			worldPos1 = mix(worldPos1O, worldPos1, float(useRefract));
			worldDis1 = mix(length(worldPos1O.xyz), worldDis1, float(useRefract));

			// 全内反射
			float TIRFactor = 1.0;
			if(isUnderwater) {
				TIRFactor = (1.0 - TIR) * eyeBrightnessSmooth.y / 240.0;
			}
			colorRGB *= TIRFactor;
			color = vec4(colorRGB * COLOR_UI_SCALE, 1.0);
		#endif
		


		float deep = worldDis1 - worldDis0;
		vec3 fogColor = waterFogColor * (mix(vec3(getLuminance(sunColor)), sunColor, 0.5) * 0.125 + NIGHT_VISION_BRIGHTNESS * nightVision);

		float lightmapY = saturate(lightmap.y + NIGHT_VISION_BRIGHTNESS * nightVision);

		if (isAbovewater) {
			float depthFactor = saturate(deep / WATER_MIST_VISIBILITY);
			vec3 fogAttenuation = saturate(fastExp(-(vec3(1.0) - fogColor) * deep * WATER_FOG_TRANSMIT));
			
			color.rgb *= fogAttenuation;
			color.rgb = mix(color.rgb, fogColor * 0.25 * lightmapY, depthFactor);
		}



		
		vec3 reflectWorldDir = reflect(worldDir, waveWorldNormal);
		vec3 reflectViewDir = reflect(viewDir, waveViewNormal);
	
		float underwaterFactor = isUnderwater ? 0.0 : 1.0;
		bool ssrTargetSampled = false;
		
		float cosTheta = dot(-worldDir, waveWorldNormal);
		float fresnel = mix(pow(1.0 - saturate(cosTheta), REFLECTION_FRESNAL_POWER), 1.0, WATER_F0);

		#ifdef WATER_REFLECTION
			vec3 reflectColor = reflection(
				gaux2, 
				vViewPos.xyz, 
				reflectWorldDir, 
				reflectViewDir, 
				lightmapY * underwaterFactor, 
				normalVO, 
				1.0, 
				ssrTargetSampled
			);
			
			if (isAbovewater) {
				color.rgb = mix(color.rgb, reflectColor, fresnel);
			} else {
				color.rgb += fogColor * 0.2 * lightmapY * TIR;
				color.rgb = mix(color.rgb, reflectColor, saturate(float(ssrTargetSampled) * TIR));
			}
		#endif
		


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
			#ifndef END
				color.rgb += drawCelestial(reflectWorldDir, 1.0, false) * lightmapMask * WATER_REFLECT_HIGH_LIGHT_INTENSITY * 0.5 * float(!ssrTargetSampled);
			#endif
			// vec3 waveWorldNormal_diffuse = normalize(vec3(waveWorldNormal.x, waveWorldNormal.y * 0.333, waveWorldNormal.z));
			// color.rgb *= 1.0 + 0.075 * sunColor * vec3(pow(saturate(dot(waveWorldNormal_diffuse, lightWorldDir)), 1.0)) * lightmap.y * lightmapMask * WATER_REFLECT_HIGH_LIGHT_INTENSITY;
		#endif



		// float d = texture(depthtex0, fragCoord).r;
		// float d1 = texture(depthtex1, fragCoord).r;
		// vec3 v0 = screenPosToViewPos(vec4(fragCoord, d, 1.0)).xyz;
		// vec3 v1 = screenPosToViewPos(vec4(fragCoord, d1, 1.0)).xyz;

		// color.rgb = max(vec3(length(v1.xyz - v0.xyz)), vec3(0.0));

	}else{
		vec3 albedo = toLinearR(texColor.rgb);
		vec3 diffuse = albedo / PI;

		MaterialParams materialParams = MapMaterialParams(specularMap);

		#ifdef TRANSLUCENT_USE_REASOURCESPACK_PBR
			if(dot(specularMap.rgb, vec3(1.0)) < 0.001){
		#endif
				materialParams.smoothness = TRANSLUCENT_ROUGHNESS;
				float perceptual_roughness = 1.0 - materialParams.smoothness;
				materialParams.roughness = perceptual_roughness * perceptual_roughness;
				materialParams.metalness = TRANSLUCENT_F0;
		#ifdef TRANSLUCENT_USE_REASOURCESPACK_PBR
			}
		#endif
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
			bool ssrTargetSampled = false;	
			vec3 reflectColor = reflection(gaux2, vViewPos.xyz, reflectWorldDir, reflectViewDir, 
											lightmap.y * upDirFactor, normalTexV, 1.0, ssrTargetSampled)
											+ drawCelestial(reflectWorldDir, 1.0, false) * shade;
			float NdotV = saturate(dot(normalTexV, -viewDir));

			vec3 F0 = mix(vec3(0.04), albedo, materialParams.metalness); 
			vec3 BRDF = EnvDFGLazarov(F0, materialParams.smoothness, NdotV) * pow(materialParams.smoothness, 1.0 / MIRROR_INTENSITY);

			c += reflectColor * BRDF;
			// c = mix(c, reflectColor + PBR[1] * shade * albedo * sunColor * cos_theta, F_Schlick(NdotV, F0));
			// c = reflectColor;
		}
		#endif

		#ifdef TRANSLUCENT_REFRACTION
			color.a = 1.0;
			vec2 refractCoord = saturate(waterRefractionCoord(normalVO, normalTexV, worldDis0, TRANSLUCENT_REFRACTION_INTENSITY));
			vec3 refractColor = texture(gaux1, refractCoord).rgb * COLOR_UI_SCALE;
			c = mix(refractColor, c, texColor.a);
		#else
			color.a = texColor.a;
		#endif



		#define TRANSLUCENT_MODE 1
		#if TRANSLUCENT_MODE == 0
			color.rgb = mix(texture(gaux1, fragCoord).rgb * COLOR_UI_SCALE, c, color.a);
			color.a = 1.0;
		#elif TRANSLUCENT_MODE == 1
			color = vec4(c, color.a);
		#elif TRANSLUCENT_MODE == 2
			color.rgb = albedo * lightmap.y * sunColor * 0.2;
		#endif
	}

	// color.rgb = texture(colortex8, fragCoord.xy).rgb;


/* RENDERTARGETS: 0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZY//////////////////////////////////////////////////////////////////////////////
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

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;

	// TBN Mat 参考自 BSL shader
	vec3 N = normalize(gl_NormalMatrix * gl_Normal);
	vec3 B = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	vec3 T = normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix = mat3(T, B, N);
	// T_tbnMatrix = transpose(tbnMatrix);

	normalVO = N;
	normalWO = normalize(viewPosToWorldPos(vec4(N, 0.0)).xyz);

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

	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}

#endif