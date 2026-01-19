


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/camera/filter.glsl"

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
flat in vec4 texCoordAM;
in vec2 texCoordLocal;

float dither = temporalBayer64(ivec2(gl_FragCoord.xy));
#include "/lib/surface/parallaxMapping.glsl"
#include "/lib/antialiasing/anisotropicFiltering.glsl"
#include "/lib/surface/ripple.glsl"



void main() {
	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);

	vec3 dp1 = dFdx(viewPos.xyz);
	vec3 dp2 = dFdy(viewPos.xyz);

	vec3 normal = normalize(cross(dp1, dp2));
	vec3 dp2perp = cross(dp2, normal);
	vec3 dp1perp = cross(normal, dp1);

	vec3 T = normalize(dp2perp * texGradX.x + dp1perp * texGradY.x);
	vec3 B = normalize(dp2perp * texGradX.y + dp1perp * texGradY.y);
	float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
	mat3 tbn = mat3(T * invmax, B * invmax, normal);
	// tbn = tbnMatrix;

	vec2 parallaxUV = texcoord;
	float parallaxShadow = 1.0;
	vec3 normalFH = vec3(0.0, 0.0, 1.0);
	vec3 parallaxOffset = vec3(0.0, 0.0, 1.0);

	#ifdef PARALLAX_MAPPING
		vec2 pq  = max(texCoordAM.pq, vec2(1e-8));
		float ref = max(pq.x, pq.y);
		vec2 scale = ref / pq;

		vec3 viewDirTS = normalize(viewPos.xyz * tbn);
		viewDirTS.xy *= scale;
		vec3 lightDirTS = normalize(shadowLightPosition * tbn);
		lightDirTS.xy *= scale;

		#if PARALLAX_TYPE == 0
			parallaxUV = parallaxMapping(normalize(viewDirTS), parallaxOffset, normalFH);
			#ifdef PARALLAX_SHADOW
				parallaxShadow = ParallaxShadow(parallaxOffset, normalize(lightDirTS));
			#endif
		#else
			parallaxUV = voxelParallaxMapping(normalize(viewDirTS), parallaxOffset, normalFH);
			#ifdef PARALLAX_SHADOW
				parallaxShadow = voxelParallaxShadow(parallaxOffset, normalize(lightDirTS));
			#endif
		#endif
	#endif

	vec4 texColor;
	if(abs(blockID - NO_ANISO) < 0.5) parallaxUV = texcoord;
	#ifdef ANISOTROPIC_FILTERING
		if(abs(blockID - NO_ANISO) > 0.5){
			#if ANISOTROPIC_FILTERING_MODE == 0
				texColor = textureAniso2(tex, parallaxUV, texcoord);
			#else
				texColor = textureAniso(tex, parallaxUV, texcoord);
			#endif
		} else {
			texColor = texture(tex, parallaxUV);
		}
	#else
		#ifdef PARALLAX_MAPPING
			texColor = textureGrad(tex, parallaxUV, texGradX, texGradY);
		#else
			texColor = texture(tex,parallaxUV);
		#endif
	#endif
	if(texColor.a < 0.05) discard;
	vec4 color = texColor * glcolor;



	


	vec3 normalFinal = normalize(tbn * (textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0));
	vec3 N1 = N;

	float wetFactor = 0.0;
	bool upFace = dot(N, upViewDir) > 0.95;
	bool isRain = rainStrength > 0.001;

	#ifdef RAINY_GROUND_WET_ENABLE
		if(isRain){
            wetFactor = smoothstep(0.88, 0.95, lmcoord.y) * rainStrength;
            #ifdef RAINY_GROUND_WET_NOISE
                float noiseSample = texture(colortex8, mcPos.xz * 0.01).r;
                float smoothedNoise = pow(smoothstep(0.0, 0.75, noiseSample), 0.5);
                float noiseFactor = upFace ? smoothedNoise : 0.95;
                wetFactor *= noiseFactor * float(biome_precipitation == 1);
            #endif
			wetFactor *= float(biome_precipitation == 1);
        }
			
		#ifdef RIPPLE
			float worldDis = length(viewPos);
			if(upFace && worldDis < RIPPLE_DISTANCE && isRain && wetFactor > 0.0001) 
				N1 = normalize(mat3(gbufferModelView) * RippleNormalWS(mcPos.xz, worldDis, wetFactor));
		#endif
	#endif

	#ifdef PARALLAX_MAPPING
		vec3 heightBasedNormal = tbn * normalFH;

		#if PARALLAX_TYPE == 0
			normalFinal = mix(normalFinal, heightBasedNormal, PARALLAX_NORMAL_MIX_WEIGHT);
		#else
			normalFinal = mix(normalFinal, N1, 
						saturate(max(PARALLAX_NORMAL_MIX_WEIGHT, wetFactor * float(upFace))));

			#ifdef PARALLAX_FORCE_NORMAL_VERTICAL
				float verticalness = dot(normalFH, vec3(0.0, 0.0, 1.0));
				normalFinal = verticalness > 0.95 ? normalFinal : (heightBasedNormal);
			#else
				normalFinal = heightBasedNormal;
			#endif
		#endif
	#endif

	vec4 specularTex = saturate(textureGrad(specular, parallaxUV, texGradX, texGradY));
	if(isRain && wetFactor > 0.0001){
		#if !defined(PARALLAX_MAPPING) || PARALLAX_TYPE == 0
			normalFinal = mix(normalFinal, N1, saturate(wetFactor * float(upFace) * (1.0 - specularTex.g)));
		#endif

		#ifdef RAINY_GROUND_WET_ENABLE
			specularTex.r = max(specularTex.r, WET_GROUND_SMOOTHNESS * wetFactor);
			specularTex.g = max(specularTex.g, WET_GROUND_F0 * wetFactor);
		#endif
	}
	normalFinal = normalize(normalFinal);
	specularTex = saturate(specularTex);

	// vec2 noiseCoord = mcPos.xz;
	// noiseCoord = rotate2D(noiseCoord, 0.45);
    // noiseCoord = vec2(noiseCoord.x * 3.0, noiseCoord.y);
	// noiseCoord.x += frameTimeCounter * 32.0;
	// noiseCoord /=64.0 * noiseTextureResolution;
    // color.rgb = vec3(textureBicubic(noisetex, noiseCoord, noiseTextureResolution).g);

#ifdef PATH_TRACING
/* DRAWBUFFERS:0459 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(parallaxShadow, 0.0), pack2x8To16(blockID/ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalFinal), lmcoord);
	gl_FragData[3] = vec4(0.0, 0.0, normalEncode(N));
#else
/* DRAWBUFFERS:045 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(parallaxShadow, 0.0), pack2x8To16(blockID/ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalFinal), lmcoord);
#endif
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
flat in vec4 v_texCoordAM[];
in vec2 v_texCoordLocal[];
flat in float v_blockID[];

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out mat3 tbnMatrix;
out vec4 viewPos;
out vec3 N;
out vec3 mcPos;
flat out vec4 texCoordAM;
out vec2 texCoordLocal;
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
		texCoordAM = v_texCoordAM[i];
		texCoordLocal = v_texCoordLocal[i];
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
flat out vec4 v_texCoordAM;
out vec2 v_texCoordLocal;
out vec2 midCoord;
flat out float v_blockID;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
attribute vec4 at_midBlock;

#include "/lib/common/materialIdMapper.glsl"
#include "/lib/wavingPlants.glsl"

void main() {
	v_blockID = IDMapping();
	v_lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	#if defined PATH_TRACING || defined COLORED_LIGHT
		v_lmcoord.x = ((at_midBlock.a - 1.0)) / 15.0;
	#endif
	v_texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	v_glcolor = gl_Color;

	// From BSL
	midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = v_texcoord - midCoord;
	v_texCoordAM.pq  = abs(texMinMidCoord) * 2;
	v_texCoordAM.st  = min(v_texcoord, midCoord - texMinMidCoord);
	v_texCoordLocal.xy    = sign(texMinMidCoord) * 0.5 + 0.5;

	const float inf = uintBitsToFloat(0x7f800000u);
	float handedness = clamp(at_tangent.w * inf, -1.0, 1.0);
	v_N = gl_NormalMatrix * normalize(gl_Normal);
	vec3 T = gl_NormalMatrix * normalize(at_tangent.xyz);
	vec3 B = cross(T, v_N) * handedness;
	v_tbnMatrix = mat3(T, B, v_N);

	v_viewPos = gl_ModelViewMatrix * gl_Vertex;
	vec4 vWorldPos = viewPosToWorldPos(v_viewPos);
	float worldDis = length(vWorldPos.xyz);
	vec4 mcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

	#ifdef WAVING_PLANTS
		if(worldDis < 60.0){
			const float waving_rate = WAVING_RATE;
			if(v_blockID == PLANTS_SHORT && gl_MultiTexCoord0.t < mc_midTexCoord.t){
				mcPos.xyz = wavingPlants(mcPos.xyz, PLANTS_SHORT_AMPLITUDE, waving_rate, 0.0, WAVING_NOISE_SCALE);
			}
			if(v_blockID == LEAVES){
				mcPos.xyz = wavingPlants(mcPos.xyz, LEAVES_AMPLITUDE, waving_rate, 1.0, WAVING_NOISE_SCALE);
			}
			if((v_blockID == PLANTS_TALL_L && gl_MultiTexCoord0.t < mc_midTexCoord.t) || v_blockID == PLANTS_TALL_U){
				mcPos.xyz = wavingPlants(mcPos.xyz, PLANTS_TALL_AMPLITUDE, waving_rate, 0.0, WAVING_NOISE_SCALE);
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

