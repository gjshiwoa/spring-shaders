varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;

varying vec3 sunColor, skyColor;
varying vec3 LeftLitDiff, RightLitDiff;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;



#include "/lib/common/gbufferData.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/shadowMapping.glsl"
#include "/lib/lighting/screenSpaceShadow.glsl"
#include "/lib/lighting/voxelization.glsl"
#include "/lib/lighting/RSM.glsl"
#include "/lib/lighting/SSAO.glsl"
#include "/lib/surface/PBR.glsl"

#include "/lib/atmosphere/fog.glsl"
#include "/lib/atmosphere/celestial.glsl"
#include "/lib/lighting/pathTracing.glsl"



void main() {
	vec4 CT2 = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0);
	vec4 color = texture(colortex0, texcoord);	// albedo
	vec3 texColor = color.rgb;
	vec3 albedo = pow(texColor, vec3(2.2));
	vec3 diffuse = albedo / PI;

	vec3 normalV = normalize(normalDecode(normalEnc));
	vec3 normalW = normalize(viewPosToWorldPos(vec4(normalV, 0.0)).xyz);

	vec3 L2 = BLACK;
	vec3 ao = vec3(1.0);

	#if defined DISTANT_HORIZONS && !defined NETHER && !defined END
		bool isTerrain = skyB < 0.5;

		float depth1;
		vec4 viewPos1;
		if(dhTerrain > 0.5){ 
			float dhDepth = texture(dhDepthTex0, texcoord).r;
			viewPos1 = screenPosToViewPosDH(vec4(unTAAJitter(texcoord), dhDepth, 1.0));
			depth1 = viewPosToScreenPos(viewPos1).z;
		}else{
			depth1 = texture(depthtex1, texcoord).r;
			viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));	
		}
	#else 
		bool isTerrain = skyB < 0.5;

		float depth1 = texture(depthtex1, texcoord).r;
		vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));	
	#endif

	vec3 viewDir = normalize(viewPos1.xyz);
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	vec3 worldDir = normalize(worldPos1.xyz);
	vec3 shadowPos = getShadowPos(worldPos1).xyz;
	float worldDis1 = length(worldPos1);

	vec4 viewPos1R = screenPosToViewPos(vec4(texcoord, depth1, 1.0));
	vec4 worldPos1R = viewPosToWorldPos(viewPos1R);
	vec2 prePos = getPrePos(worldPos1R).xy;
	vec2 velocity = texcoord - prePos;

	if(isTerrain){	
		vec2 lightmap = AdjustLightmap(mcLightmap);
		float lightMask = pow(smoothstep(0.0, 0.1, lightmap.y), 0.45);
		

		MaterialParams materialParams = MapMaterialParams(specularMap);
		#ifdef PBR_REFLECTIVITY
			mat2x3 PBR = CalculatePBR(viewDir, normalV, lightViewDir, albedo, materialParams);
			vec3 BRDF = PBR[0] + PBR[1];
			vec3 BRDF_D = reflectDiffuse(viewDir, normalV, albedo, materialParams);
		#else
			vec3 BRDF = albedo / PI;
			vec3 BRDF_D = BRDF;
		#endif



		float cos_theta_O = dot(normalW, lightWorldDir);
		float cos_theta = max(cos_theta_O, 0.0);

		// bzyzhang: 练习项目(十一)：次表面散射的近似实现
		// https://zhuanlan.zhihu.com/p/348106844
		float sssWrap = SSS_INTENSITY * materialParams.subsurfaceScattering;
		if(plants > 0.5) sssWrap = 20.0;
		cos_theta = saturate((cos_theta_O + sssWrap) / (1 + sssWrap));

		#ifndef PATH_TRACING
			float noRSM = hand > 0.5 ? 1.0 : 0.0;
			float UoN = dot(normalW, upWorldDir);
			vec3 skyLight = lightmap.y * BRDF_D
						* mix(sunColor, skyColor, SUN_SKY_BLEND - 0.05 * noRSM * lightmap.y)
						* mix(1.0, UoN * 0.5 + 0.5, 0.75);
			

			vec4 gi = getGI(depth1, normalW);
			gi.a = 1.0 - gi.a;
			if(noRSM < 0.5) {
				L2 = sunColor * BRDF_D * gi.rgb;
				#ifdef AO_ENABLED
					#ifdef AO_MULTI_BOUNCE
						ao = AOMultiBounce(albedo, saturate(gi.a));
					#else 
						ao = vec3(saturate(gi.a));
					#endif
				#endif
			}
		#endif

		float shadow = 1.0;
		vec3 colorShadow = vec3(0.0);
		if(!outScreen(shadowPos.xy) && cos_theta > 0.001){
			shadow = CT4R.x;
			colorShadow = getColorShadow(shadowPos, shadow);
		}
		float RTShadow = saturate(CT4R.y);
		shadow = min(shadow, RTShadow);

		shadow = saturate(shadow);
		vec3 visibility = vec3(shadow + colorShadow);
		vec3 direct = sunColor * BRDF * visibility * cos_theta;



		vec3 gi_PT = vec3(0.0);
		#if defined PATH_TRACING || defined COLORED_LIGHT
			gi_PT = getGI_PT(depth1, normalW).rgb * BRDF_D * PI;
		#endif

		vec3 artificial = vec3(0.0);

		float heldBlockLight = 0.5 * ARTIFICIAL_COLOR_ALPHA * 
					pow(remapSaturate(worldDis1, 0.0, DYNAMIC_LIGHT_DISTANCE, 1.0, 0.0), ARTIFICIAL_LIGHT_FALLOFF);
		#ifdef HELD_BLOCK_NORMAL_AFFECT
			heldBlockLight *= saturate(dot(normalV, -normalize(vec3(viewPos1.xyz))));
		#endif

		#if defined PATH_TRACING || defined COLORED_LIGHT
			#ifdef COLORED_LIGHT
				artificial = gi_PT;
			#endif

			artificial += (LeftLitDiff + RightLitDiff) * heldBlockLight * BRDF_D;

			artificial += max(lightmap.x, materialParams.emissiveness) * diffuse * 2.0;
		#else
			float heldLightIntensity = max(heldBlockLightValue, heldBlockLightValue2) / 15.0;
			lightmap.x = max(lightmap.x, heldLightIntensity * heldBlockLight);

			artificial = lightmap.x * artificial_color * (1.0 + GLOWING_BRIGHTNESS * glowingB) * BRDF_D;
			artificial += saturate(materialParams.emissiveness - lightmap.x) * diffuse * EMISSIVENESS_BRIGHTNESS;
			
			if (lightningBolt > 0.5) {
				color.rgb = vec3(1.0);
				artificial += 1.0 * lightningBolt;
			}
		#endif





		#ifdef DISABLE_LEAKAGE_REPAIR
			lightMask = 1.0;
		#endif

		#ifdef PATH_TRACING
			color.rgb = albedo * 0.001 
						+ nightVision * diffuse * NIGHT_VISION_BRIGHTNESS 
						+ gi_PT;
		#else
			color.rgb = (albedo * 0.01 
						+ nightVision * diffuse * NIGHT_VISION_BRIGHTNESS 
						+ skyLight * SKY_LIGHT_BRIGHTNESS 
						+ L2 * lightMask * RSM_BRIGHTNESS) * ao;
		#endif

		color.rgb += direct * lightMask * DIRECT_LUMINANCE;

		if (isEyeInWater == 1) {
			color.rgb *= saturate(exp((waterFogColor - 1.0) * (3.75 - 3.0 * lightmap.y)));
		}

		color.rgb += artificial;

		// color.rgb = sunColor * gi.rgb + lightmap.y * mix(sunColor, skyColor, SUN_SKY_BLEND - 0.05 * noRSM * lightmap.y) * mix(1.0, UoN * 0.5 + 0.5, 0.75);
		// color.rgb *= vec3(ao);
		// color.rgb = vec3(shadow);
		// color.rgb = gi_PT;
		// color.rgb = RightLitDiff * 1.0;

	}else{
		float d_p2a = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r + atmosphere_h).y;
		float d_p2e = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r).x;
		float d = d_p2e > 0.0 ? d_p2e : d_p2a;
		float dist1 = skyB > 0.5 ? d : worldDis1;

		float cloudTransmittance = 1.0;
		vec3 cloudScattering = vec3(0.0);
		float cloudHitLength = clamp(intersectHorizontalPlane(camera, worldDir, 650), 0.0, 20000.0);

		#ifdef VOLUMETRIC_CLOUDS
			vec2 cloud_uv = texcoord * 0.5 + vec2(0.5, 0.0);
			if(!outScreen(cloud_uv * 2.0 - vec2(1.0, 0.0) + vec2(-1.0, 1.0) * invViewSize) && camera.y < 5000.0)	{
				vec4 CT1_c = texture(colortex3, cloud_uv);
				if(dot(CT1_c.rgb, CT1_c.rgb) <= 1e-9){
					CT1_c.a = 1.0;
				}
				cloudScattering = CT1_c.rgb;
				cloudTransmittance = CT1_c.a;
			}
		#endif

		vec3 skyBaseColor = texture(colortex1, texcoord * 0.5 + 0.5).rgb * SKY_BASE_COLOR_BRIGHTNESS;
		vec3 celestial = drawCelestial(worldDir, cloudTransmittance, true);

		color.rgb = skyBaseColor;	
		color.rgb += celestial;
		cloudTransmittance = max(cloudTransmittance, 0.0);
		cloudScattering = max(cloudScattering, vec3(0.0));
		color.rgb = color.rgb * cloudTransmittance + cloudScattering;

		float VoL = saturate(dot(worldDir, sunWorldDir));
		float phase = saturate(hgPhase1(VoL, 0.66 - 0.56 * rainStrength));
		float crepuscularLight = 0.0;
		#ifdef CREPUSCULAR_LIGHT
			if(phase > 0.01 && sunRiseSetS + isNoonS > 0.001) crepuscularLight = computeCrepuscularLight(viewPos1) * phase;
		#endif
		if(cloudTransmittance < 1.0){

			color.rgb = 
				mix((skyBaseColor + celestial), color.rgb, 
					saturate(
						// mix(saturate(pow(getLuminance(cloudScattering), 1.0 - 0.45 * phase * sunRiseSetS)), 
						// 	exp(-cloudHitLength / (CLOUD_FADE_DISTANCE * (1.0 + 1.0 * phase * sunRiseSetS))) * 1.0, 
						// 	0.66)
						pow(exp(-cloudHitLength / (CLOUD_FADE_DISTANCE * (1.0 + 1.0 * phase * sunRiseSetS))), 
								remapSaturate(1.0 - saturate(getLuminance(cloudScattering - 0.5) + 0.05), 0.0, 1.0, 1.0, 2.0))
					)
				);
			
		}
		color.rgb += pow(crepuscularLight, 1.0) * sunColor * max3(0.6 * sunRiseSetS, 5.0 * rainStrength, 0.05 * isNoonS) * saturate(1.0 - isNightS)
					* remapSaturate(camera.y, 600.0, 1000.0, 1.0, 0.0);
		// color.rgb = vec3(computeCrepuscularLight(viewPos1));
		// color.rgb = vec3(crepuscularLight);
		// color.rgb = normalize(normalDecode(texelFetch(colortex9, ivec2(gl_FragCoord.xy * 2.0 - viewSize), 0).ba));
	}
	
	color.rgb = max(BLACK, color.rgb);
	// color.rgb = vec3(1.0 - texture(colortex3, texcoord * 0.5).a);
	
	// if(dhTerrain > 0.5) color.rgb = vec3(1.0 - texture(colortex1, texcoord * 0.5).a);
	// color.rgb = texture(colortex11, texcoord * 0.5).rgb;

	// color.rgb = toLinearR(texelFetch(customimg0, ivec3(relWorldToVoxelCoord(worldPos1.xyz - 0.1 * normalW)), 0).rgb);
	
	CT4.rg = pack4x8To2x16(vec4(albedo, ao));

/* DRAWBUFFERS:0249 */
	gl_FragData[0] = color;
	gl_FragData[1] = CT2;
	gl_FragData[2] = CT4;
	gl_FragData[3] = vec4(velocity, 0.0, 1.0);
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

	vec4 LeftLitCol = texelFetch(colortex7, LeftLitPreUV, 0);
	vec4 RightLitCol = texelFetch(colortex7, rightLitPreUV, 0);
	LeftLitDiff = toLinearR(LeftLitCol.rgb * LeftLitCol.a);
	RightLitDiff = toLinearR(RightLitCol.rgb * RightLitCol.a);

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
