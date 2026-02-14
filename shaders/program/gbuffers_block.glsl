varying vec2 lmcoord;
varying vec2 texcoord;

varying vec4 glcolor;

// varying float blockID;

varying mat3 tbnMatrix, T_tbnMatrix;

varying vec3 N;

varying vec3 mcPos;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"

#ifdef FSH

void main() {
	vec2 parallaxUV = texcoord;

	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);
	vec4 color = texture(tex, texcoord) * glcolor;
	
	float parallaxShadow = 1.0;

	vec3 normalFinal = normalize(tbnMatrix * (textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0));

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
            #else
                wetFactor *= float(biome_precipitation == 1);
            #endif
        }
	#endif

	vec4 specularTex = saturate(textureGrad(specular, parallaxUV, texGradX, texGradY));
	if(isRain && wetFactor > 0.0001){
		normalFinal = mix(normalFinal, N, saturate(wetFactor * float(upFace) * (1.0 - specularTex.g)));
		#ifdef RAINY_GROUND_WET_ENABLE
			specularTex.r = max(specularTex.r, WET_GROUND_SMOOTHNESS * wetFactor);
			specularTex.g = max(specularTex.g, WET_GROUND_F0 * wetFactor);
		#endif
	}
	
	normalFinal = normalize(normalFinal);
	specularTex = saturate(specularTex);

#ifdef PATH_TRACING
#ifdef VOXY
/* RENDERTARGETS: 0,4,5,9,19 */
#else
/* RENDERTARGETS: 0,4,5,9 */
#endif
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(BLOCK / ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalFinal), lmcoord);
	gl_FragData[3] = vec4(0.0, 0.0, normalEncode(N));
#ifdef VOXY
	gl_FragData[4] = vec4(1.0, 0.0, 0.0, 1.0);
#endif
#else
#ifdef VOXY
/* RENDERTARGETS: 0,4,5,19 */
#else
/* RENDERTARGETS: 0,4,5 */
#endif
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(BLOCK / ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalFinal), lmcoord);
#ifdef VOXY
	gl_FragData[3] = vec4(1.0, 0.0, 0.0, 1.0);
#endif
#endif
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
#include "/lib/common/noise.glsl"

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
attribute vec4 at_midBlock;


void main() {
	gl_Position = ftransform();
	vec4 vViewPos = gl_ModelViewMatrix * gl_Vertex;
	vec4 vWorldPos = viewPosToWorldPos(vViewPos);
	mcPos = vWorldPos.xyz + cameraPosition;

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;

	// TBN Mat 参考自 BSL shader
	N = normalize(gl_NormalMatrix * gl_Normal);
	vec3 B = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	vec3 T = normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix = mat3(T, B, N);
	T_tbnMatrix = transpose(tbnMatrix);

	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	#if defined PATH_TRACING || defined COLORED_LIGHT
		lmcoord.x = ((at_midBlock.a - 1.0)) / 15.0;
	#endif
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}

#endif
