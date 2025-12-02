varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;


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
#include "/lib/common/gbufferData.glsl"
// #include "/lib/common/materialIdMapper.glsl"
// #include "/lib/lighting/lightmap.glsl"
// #include "/lib/atmosphere/celestial.glsl"

#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/surface/PBR.glsl"
#include "/lib/common/octahedralMapping.glsl"

void main() {
	vec4 color = texture(colortex0, texcoord);
	float depth1 = texture(depthtex1, texcoord).r;
	vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));

#ifdef PBR_REFLECTIVITY
	if(specularMap.r + rainStrength > 0.5 / 255.0){
		
		vec3 viewDir = normalize(viewPos1.xyz);

		vec3 normalV = normalize(normalDecode(normalEnc));
		vec3 normalW = normalize(viewPosToWorldPos(vec4(normalV, 0.0)).xyz);	

		vec4 CT4RG = vec4(CT4R, CT4G);
		vec3 albedo = CT4RG.rgb;
		float ao = CT4RG.a;

		MaterialParams params = MapMaterialParams(specularMap);

		vec3 N = params.N;
		vec3 K = params.K;

		float NdotV = saturate(dot(normalV, -viewDir));

		vec3 reflectColor = getReflectColor(depth1, normalW);

		vec3 F0 = mix(vec3(0.04), albedo, params.metalness); 
		if(params.metalness > 0.9) F0 += max(vec3(0.0), ComplexFresnel(params.N, params.K));
		vec3 BRDF = EnvDFGLazarov(F0, params.smoothness, NdotV) * pow(params.smoothness, 1.0 / MIRROR_INTENSITY);

		color.rgb += reflectColor * BRDF * ao;

		#ifdef RAINY_GROUND_WET_ENABLE
			color.rgb = mix(color.rgb, reflectColor, F_Schlick(NdotV, vec3(0.02)) * smoothstep(0.90, 0.95, mcLightmap.y) * rainStrength * 0.75);
		#endif
	}
#endif
	

	vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
	// color.rgb = texture(colortex1, texcoord * 0.5).rgb;

	vec4 color1 = vec4(color.rgb / COLOR_UI_SCALE, 1.0);

	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);            
	vec2 uv1 = texcoord * 2.0 - 1.0;
	if(!outScreen(uv1)){
		CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy - 0.5 * viewSize), 0);;
	}

	// vec4 viewPos1R = screenPosToViewPos(vec4(texcoord.st, depth1, 1.0));
	// vec4 worldPos1R = viewPosToWorldPos(viewPos1R);
	// vec2 prePos = getPrePos(worldPos1R).xy;
	// vec2 velocity = texcoord - prePos;

	// vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos1.xyz);
	// color.rgb = texture(colortex7, clamp(0.5 * directionToOctahedral(worldDir), 0.0, 0.5 - 1.0 / 512.0)).rgb;
	// color.rgb = vec3(texture(colortex1, texcoord * 0.5 + vec2(0.5, 0.0)).rgb);
	// color.rgb = texture(colortex3, texcoord).rgb;




/* DRAWBUFFERS:0468 */
	gl_FragData[0] = color;
	gl_FragData[1] = color1;
	gl_FragData[2] = CT6;
	gl_FragData[3] = vec4(texture(colortex2, texcoord).rgb / COLOR_UI_SCALE, 1.0);
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

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif