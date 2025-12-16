


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"

#ifdef FSH
flat in float blockID, isPlants;
flat in int textureResolution;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in mat3 tbnMatrix;
in vec4 viewPos;
in vec3 N;
in vec3 mcPos;

float dither = temporalBayer64(ivec2(gl_FragCoord.xy));
#include "/lib/antialiasing/anisotropicFiltering.glsl"
#include "/lib/surface/parallaxMapping.glsl"
#include "/lib/surface/ripple.glsl"



void main() {
	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);

	vec3 dp1 = dFdx(viewPos.xyz);
	vec3 dp2 = dFdy(viewPos.xyz);

	vec3 N = normalize(cross(dp1, dp2));
	vec3 dp2perp = cross(dp2, N);
	vec3 dp1perp = cross(N, dp1);

	vec3 T = normalize(dp2perp * texGradX.x + dp1perp * texGradY.x);
	vec3 B = normalize(dp2perp * texGradX.y + dp1perp * texGradY.y);
	float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
	mat3 tbn = mat3(T * invmax, B * invmax, N);
	// tbn = tbnMatrix;

	vec2 parallaxUV = texcoord;
	float parallaxShadow = 1.0;
	vec3 normalFH = vec3(0.0, 0.0, 1.0);
	vec3 parallaxOffset = vec3(0.0, 0.0, 1.0);
	#ifdef PARALLAX_MAPPING
		vec3 viewDirTS = normalize(viewPos.xyz * tbn);
		vec3 lightDirTS = normalize(shadowLightPosition * tbn);

		#if PARALLAX_TYPE == 0
			parallaxUV = parallaxMapping(viewDirTS, parallaxOffset, normalFH);
			#ifdef PARALLAX_SHADOW
				parallaxShadow = ParallaxShadow(parallaxOffset, lightDirTS);
			#endif
		#else
			parallaxUV = voxelParallaxMapping(viewDirTS, parallaxOffset, normalFH);
			#ifdef PARALLAX_SHADOW
				parallaxShadow = voxelParallaxShadow(parallaxOffset, lightDirTS);
			#endif
		#endif
	#endif

	vec4 texColor;
	#ifdef ANISOTROPIC_FILTERING
		#if ANISOTROPIC_FILTERING_MODE == 0
			texColor = textureAniso2(tex, parallaxUV, texcoord);
		#else
			texColor = textureAniso(tex, parallaxUV, texcoord);
		#endif
	#else
		#ifdef PARALLAX_MAPPING
			texColor = textureGrad(tex, parallaxUV, texGradX, texGradY);
		#else
			texColor = texture(tex,parallaxUV);
		#endif
	#endif
	

	
	float rainFactor = 0.0;
	bool upFace = dot(N, upViewDir) > 0.95;
	bool isRain = rainStrength > 0.001;
	#ifdef RAINY_GROUND_WET_ENABLE
		rainFactor = smoothstep(0.88, 0.95, lmcoord.y) * rainStrength;
		float noiseSample = texture(colortex8, mcPos.xz * 0.01).r;
		float smoothedNoise = pow(smoothstep(0.0, 0.75, noiseSample), 0.5);
		float noiseFactor = upFace ? smoothedNoise : 0.95;
		rainFactor *= noiseFactor * float(biome_precipitation == 1);
	#endif

	vec4 color = texColor * glcolor;
	vec3 normalTex = N;
	float worldDis = length(viewPos);
	if(upFace && worldDis < 20.0 && isRain && rainFactor > 0.0001) 
		N = mix(N, 
				mat3(gbufferModelView) * RippleNormalWS(mcPos.xz), 
				rainFactor * remapSaturate(worldDis, 10.0, 20.0, 1.0, 0.0));
	vec3 sampledNormal = textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0;
	normalTex = normalize(tbn * sampledNormal);
	#ifdef PARALLAX_MAPPING
		vec3 heightBasedNormal = tbn * normalFH;
		#if PARALLAX_TYPE == 0
			normalTex = mix(normalTex, heightBasedNormal, PARALLAX_NORMAL_MIX_WEIGHT);
		#else
			float verticalness = dot(normalFH, vec3(0.0, 0.0, 1.0));
			const float VERTICAL_THRESHOLD = 0.95;
				normalTex = mix(normalTex, N, 
								saturate(max(PARALLAX_NORMAL_MIX_WEIGHT, rainFactor * float(upFace))));
			#ifdef PARALLAX_FORCE_NORMAL_VERTICAL
				normalTex = verticalness > VERTICAL_THRESHOLD ? normalTex : (heightBasedNormal);
			#else
				normalTex = heightBasedNormal;
			#endif
		#endif
	#endif

	vec4 specularTex = saturate(textureGrad(specular, parallaxUV, texGradX, texGradY));
	if(isRain && rainFactor > 0.0001){
		#if !defined(PARALLAX_MAPPING) || PARALLAX_TYPE == 0
			normalTex = mix(normalTex, N, saturate(rainFactor * float(upFace) * (1.0 - specularTex.g)));
		#endif

		#ifdef RAINY_GROUND_WET_ENABLE
			specularTex.r = max(specularTex.r, 0.95 * rainFactor);
			specularTex.g = max(specularTex.g, 0.02 * rainFactor);
		#endif
	}
	specularTex = saturate(specularTex);


	// vec2 lmCoord = lmcoord;
	// float heldBlockLight = max(heldBlockLightValue, heldBlockLightValue2) / 15.0;
	// heldBlockLight *= remapSaturate(worldDis, 0.0, 20.0, 1.0, 0.0) * pow(saturate(dot(normalTex, -normalize(vec3(viewPos.xy, viewPos.z)))), 0.5) - 0.05;
	// heldBlockLight = pow(saturate(heldBlockLight), 1.0);
	// lmCoord.x = max(lmCoord.x, heldBlockLight);

	// vec2 noiseCoord = mcPos.xz;
	// noiseCoord = rotate2D(noiseCoord, 0.45);
    // noiseCoord = vec2(noiseCoord.x * 3.0, noiseCoord.y);
	// noiseCoord.x += frameTimeCounter * 8.0;
	// noiseCoord /= 8.0 * noiseTextureResolution;
    // vec3 noise = texture(noisetex, noiseCoord).rgb;
	// color.rgb = vec3(noise.r);

/* DRAWBUFFERS:045 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(parallaxShadow, 0.0), pack2x8To16(blockID/ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalTex), lmcoord);
}
 
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef GSH

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in vec2 v_lmcoord[];
in vec2 v_texcoord[];
in vec4 v_glcolor[];
in mat3 v_tbnMatrix[];
in vec4 v_viewPos[];
in vec3 v_N[];
in vec3 v_mcPos[];
flat in float v_blockID[];

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out mat3 tbnMatrix;
out vec4 viewPos;
out vec3 N;
out vec3 mcPos;
flat out float blockID;
flat out int textureResolution;

void main() {
	// 参考自 ITT
    vec2 coordSize = max3(
		abs(v_texcoord[0] - v_texcoord[1]) / distance(v_viewPos[0], v_viewPos[1]),
		abs(v_texcoord[1] - v_texcoord[2]) / distance(v_viewPos[1], v_viewPos[2]),
        abs(v_texcoord[2] - v_texcoord[0]) / distance(v_viewPos[2], v_viewPos[0])
    );
    float resolution = floor(max(atlasSize.x * coordSize.x, atlasSize.y * coordSize.y) + 0.5);
    textureResolution = int(exp2(round(log2(resolution))) + 0.01);

	for(int i = 0; i < 3; ++i){
		lmcoord = v_lmcoord[i];
		texcoord = v_texcoord[i];
		glcolor = v_glcolor[i];
		tbnMatrix = v_tbnMatrix[i];
		viewPos = v_viewPos[i];
		N = v_N[i];
		mcPos = v_mcPos[i];
		blockID = v_blockID[i];

		gl_Position = gl_in[i].gl_Position;
		EmitVertex();
	}
	EndPrimitive();
}
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
out vec2 v_lmcoord, v_texcoord;
out vec4 v_glcolor;
out mat3 v_tbnMatrix;
out vec4 v_viewPos;
out vec3 v_N;
out vec3 v_mcPos;
flat out float v_blockID;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

#include "/lib/common/materialIdMapper.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/wavingPlants.glsl"

void main() {
	v_blockID = IDMapping();
	v_lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	v_texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	v_glcolor = gl_Color;

	const float inf = uintBitsToFloat(0x7f800000u);
	float handedness = clamp(at_tangent.w * inf, -1.0, 1.0);
	v_N = gl_NormalMatrix * normalize(gl_Normal);
	vec3 T = gl_NormalMatrix * normalize(at_tangent.xyz);
	vec3 B = cross(T, v_N) * handedness;
	v_tbnMatrix = mat3(T, B, v_N);

	// 坐标
	v_viewPos = gl_ModelViewMatrix * gl_Vertex;
	vec4 vWorldPos = viewPosToWorldPos(v_viewPos);
	float worldDis = length(vWorldPos.xyz);
	vec4 mcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

	#ifdef WAVING_PLANTS
		if(worldDis < 60.0){
			const float waving_rate = WAVING_RATE;
			if(v_blockID == PLANTS_SHORT && gl_MultiTexCoord0.t < mc_midTexCoord.t){
				// pos, normal, A, B, D_amount, y_waving_amount
				mcPos.xyz = wavingPlants(mcPos.xyz, 1.0, 1.0, 0.0, 1.0);
			}
			if(v_blockID == LEAVES){
				mcPos.xyz = wavingPlants(mcPos.xyz, 0.45, 1.0, 1.0, 1.0);
			}
			if((v_blockID == PLANTS_TALL_L && gl_MultiTexCoord0.t < mc_midTexCoord.t) || v_blockID == PLANTS_TALL_U){
				mcPos.xyz = wavingPlants(mcPos.xyz, 0.45, 1.0, 0.0, 1.0);
			}
		}
	#endif

	v_mcPos = mcPos.xyz;
	gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(mcPos.xyz - cameraPosition, 1.0);

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;
}
 
#endif

