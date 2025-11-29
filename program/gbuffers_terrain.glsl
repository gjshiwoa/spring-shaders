


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"

#ifdef FSH
flat in float blockID, isPlants;
flat in int textureResolution;
in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in mat3 tbnMatrix;
in vec4 viewPos;
in vec3 N;

#include "/lib/common/noise.glsl"
float dither = temporalBayer64(ivec2(gl_FragCoord.xy));
#include "/lib/antialiasing/anisotropicFiltering.glsl"
#include "/lib/surface/parallaxMapping.glsl"



void main() {
	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);

	vec3 parallaxOffset = vec3(0.0, 0.0, 1.0);

	vec2 parallaxUV = texcoord;
	float parallaxShadow = 1.0;
	vec3 normalFH = vec3(0.0, 0.0, 1.0);
	#ifdef PARALLAX_MAPPING
		vec3 viewDirTS = normalize(viewPos.xyz * tbnMatrix);
		parallaxUV = voxelParallaxMapping(viewDirTS, parallaxOffset, normalFH);

		#ifdef PARALLAX_SHADOW
			vec3 lightDirTS = normalize(shadowLightPosition * tbnMatrix);
			// parallaxOffset += vec3(0.15 * normalFH.xy / vec2(atlasSize), saturate(12.0 * normalFH.z / 255.0));
			parallaxShadow = voxelParallaxShadow(parallaxOffset, viewDirTS, lightDirTS);
		#endif
	#endif

	vec4 texColor;
	if(blockID == NO_ANISO){
		texColor = texture(tex, texcoord);
	}else{
		#ifdef PARALLAX_MAPPING
			texColor = textureGrad(tex, parallaxUV, texGradX, texGradY);
		#else
			#ifdef ANISOTROPIC_FILTERING
				#if ANISOTROPIC_FILTERING_MODE == 0
					texColor = textureAniso2(tex, parallaxUV, texcoord);
				#else
					texColor = textureAniso(tex, parallaxUV, texcoord);
				#endif
			#else
				texColor = texture(tex, texcoord);
			#endif
		#endif
	}

	
	
	vec4 color = texColor * glcolor;
	vec3 normalTex = N;
	#ifdef PARALLAX_MAPPING
		normalTex = normalize(tbnMatrix * (textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0));
		normalTex = mix(normalTex, tbnMatrix * normalFH, 1.0);
	#endif
	vec4 specularTex = saturate(textureGrad(specular, parallaxUV, texGradX, texGradY));
	specularTex.g = saturate(specularTex.g);

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
flat in float v_blockID[];
flat in float v_isPlants[];

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out mat3 tbnMatrix;
out vec4 viewPos;
out vec3 N;
flat out float blockID;
flat out float isPlants;
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
		blockID = v_blockID[i];
		isPlants = v_isPlants[i];

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
flat out float v_blockID, v_isPlants;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

#include "/lib/common/materialIdMapper.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/wavingPlants.glsl"

void main() {
	v_blockID = IDMapping();
	v_lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	v_texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	v_glcolor = gl_Color;
	// noAniso = v_blockID == NO_ANISO ? 1.0 : 0.0;

	// 来自滑稽君
	// textureResolution = ivec2(round(abs(gl_MultiTexCoord0.xy - mc_midTexCoord.xy) * atlasSize * 2.0));
    // v_tcrange.zw = textureResolution / vec2(atlasSize);
    // v_tcrange.xy = mc_midTexCoord.xy - v_tcrange.zw * 0.5;

	// 来自BSL
	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = v_texcoord - midCoord;
	// vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
	// vTexCoordAM.st  = min(v_texcoord, midCoord - texMinMidCoord);
	// vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;

	v_N = gl_NormalMatrix * normalize(gl_Normal);
	vec3 T = gl_NormalMatrix * normalize(at_tangent.xyz);
	const float inf = uintBitsToFloat(0x7f800000u);
	float handedness = clamp(at_tangent.w * inf, -1.0, 1.0);
	vec3 B = cross(T, v_N) * handedness;
	v_tbnMatrix = mat3(T, B, v_N);

	// 坐标
	v_viewPos = gl_ModelViewMatrix * gl_Vertex;
	vec4 vWorldPos = viewPosToWorldPos(v_viewPos);
	vec4 vMcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

	v_isPlants = 0.0;
	if(v_blockID == PLANTS_SHORT || v_blockID == LEAVES || v_blockID == PLANTS_TALL_L || v_blockID == PLANTS_TALL_U){
		v_isPlants = 1.0;
	}
	#ifdef WAVING_PLANTS
		const float waving_rate = WAVING_RATE;
		if(v_blockID == PLANTS_SHORT && gl_MultiTexCoord0.t < mc_midTexCoord.t){
			// pos, normal, A, B, D_amount, y_waving_amount
			vMcPos.xyz = wavingPlants(vMcPos.xyz, PLANTS_SHORT_AMPLITUDE, waving_rate, 0.0, 0.0);
		}
		if(v_blockID == LEAVES){
			vMcPos.xyz = wavingPlants(vMcPos.xyz, LEAVES_AMPLITUDE, waving_rate, 0.0, 1.0);
		}
		if((v_blockID == PLANTS_TALL_L && gl_MultiTexCoord0.t < mc_midTexCoord.t) || v_blockID == PLANTS_TALL_U){
			vMcPos.xyz = wavingPlants(vMcPos.xyz, PLANTS_TALL_AMPLITUDE, waving_rate, 0.0, 0.0);
		}
	#endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(vMcPos.xyz - cameraPosition, 1.0);

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;
}
 
#endif

