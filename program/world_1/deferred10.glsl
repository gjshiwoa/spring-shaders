#define CLOUD3D


varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

// varying vec3 sunColor, skyColor;

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


const vec3 sunColor = vec3(0.0);

#include "/lib/common/gbufferData.glsl"

#include "/lib/common/materialIdMapper.glsl"
#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/shadowMapping.glsl"
#include "/lib/lighting/screenSpaceShadow.glsl"
#include "/lib/lighting/voxelization.glsl"
#include "/lib/lighting/RSM.glsl"
#include "/lib/lighting/SSAO.glsl"
#include "/lib/surface/PBR.glsl"
#include "/lib/water/translucentLighting.glsl"
#include "/lib/atmosphere/endFog.glsl"
#include "/lib/lighting/voxelization.glsl"
#include "/lib/lighting/pathTracing.glsl"

void main() {
	vec4 color = texture(colortex0, texcoord);
	vec3 texColor = color.rgb;
	vec3 albedo = pow(texColor, vec3(2.2));
	vec3 diffuse = albedo / PI;
	
	float depth1 = texture(depthtex1, texcoord).r;
    vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));
	vec3 viewDir = normalize(viewPos1.xyz);
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	vec3 shadowPos = getShadowPos(worldPos1).xyz;
	float worldDis1 = length(worldPos1);

	vec3 normalV = normalize(normalDecode(normalEnc));
	vec3 normalW = normalize(viewPosToWorldPos(vec4(normalV, 0.0)).xyz);

	vec3 L2 = BLACK;
	vec3 ao = vec3(1.0);

	if(skyB < 0.5){	
		vec2 lightmap = AdjustLightmap(mcLightmap);

		MaterialParams materialParams = MapMaterialParams(specularMap);
		#ifdef PBR_REFLECTIVITY
			mat2x3 PBR = CalculatePBR(viewDir, normalV, lightViewDir, albedo, materialParams);
			vec3 BRDF = PBR[0] + PBR[1];
			vec3 BRDF_D = reflectDiffuse(viewDir, normalV, albedo, materialParams);
		#else
			vec3 BRDF = albedo / PI;
			vec3 BRDF_D = BRDF;
		#endif

		float noRSM = hand > 0.5 ? 1.0 : 0.0;
		float UoN = dot(normalW, upWorldDir);
		vec3 skyLight = lightmap.y * 0.25 * endColor * BRDF_D * mix(1.0, UoN * 0.5 + 0.5, 0.5);
		
		vec4 gi = getGI(depth1, normalW);
		if(noRSM < 0.5) {
			#ifdef AO_ENABLED
				#ifdef AO_MULTI_BOUNCE
					ao = AOMultiBounce(albedo, saturate(gi.a));
				#else 
					ao = vec3(saturate(gi.a));
				#endif
			#endif
		}

		float shade = 1.0;
		if(worldDis1 < shadowDistance)
			shade = shadowMappingTranslucent(worldPos1, normalW, 0.5, 5.0);
		vec3 direct = 1.5 * BRDF * endColor * shade * pow(fakeCaustics(worldPos1.xyz + cameraPosition), 1.0)* saturate(dot(lightViewDir, normalV));

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
			artificial = gi_PT;

			artificial += (LeftLitDiff + RightLitDiff) * heldBlockLight * BRDF_D;

			artificial += max(lightmap.x, materialParams.emissiveness) * diffuse * GLOWING_BRIGHTNESS;
		#else
			float heldLightIntensity = max(heldBlockLightValue, heldBlockLightValue2) / 15.0;
			lightmap.x = max(lightmap.x, heldLightIntensity * heldBlockLight);

			artificial = lightmap.x * artificial_color * BRDF_D;
			artificial += lightmap.x * artificial_color * GLOWING_BRIGHTNESS * glowingB * diffuse;
			artificial += saturate(materialParams.emissiveness - lightmap.x) * diffuse * EMISSIVENESS_BRIGHTNESS;
		#endif

		
		
		color.rgb = albedo * 0.05;
		color.rgb += skyLight * SKY_LIGHT_BRIGHTNESS;
		color.rgb *= ao /*+ aoMultiBounce * 0.2*/;
		color.rgb += direct;
		color.rgb += artificial;
	}

	// color.rgb = vec3(texture(colortex1, texcoord * 0.5).rgb);
	color.rgb = max(BLACK, color.rgb);

	CT4.rg = pack4x8To2x16(vec4(texColor, ao));

	vec4 viewPos1R = screenPosToViewPos(vec4(texcoord.st, depth1, 1.0));
	vec4 worldPos1R = viewPosToWorldPos(viewPos1R);
	vec2 prePos = getPrePos(worldPos1R).xy;
	vec2 velocity = texcoord - prePos;

	// color.rgb = texture(colortex1, texcoord).rgb;

/* DRAWBUFFERS:049 */
	gl_FragData[0] = color;
	gl_FragData[1] = CT4;
	gl_FragData[2] = vec4(velocity, 0.0, 0.0);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
    moonWorldDir = sunWorldDir;
    lightWorldDir = sunWorldDir;

	sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
	moonViewDir = sunViewDir;
	lightViewDir = sunViewDir;

	vec4 LeftLitCol = texelFetch(colortex7, LeftLitPreUV, 0);
	vec4 RightLitCol = texelFetch(colortex7, rightLitPreUV, 0);
	LeftLitDiff = toLinearR(LeftLitCol.rgb * LeftLitCol.a);
	RightLitDiff = toLinearR(RightLitCol.rgb * RightLitCol.a);

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif