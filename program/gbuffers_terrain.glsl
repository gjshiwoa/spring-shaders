varying vec2 lmcoord, texcoord;
varying vec4 glcolor;

varying mat3 tbnMatrix;

varying vec4 vViewPos;

varying vec4 vTexCoordAM;
varying vec2 vTexCoord;

varying vec3 N;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/position.glsl"

#ifdef FSH
flat in float blockID;
flat in vec4 v_tcrange;
flat in ivec2 textureResolution;

#include "/lib/antialiasing/anisotropicFiltering.glsl"
#include "/lib/surface/parallaxMapping.glsl"

void main() {
	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);

	vec3 parallaxOffset = vec3(0.0, 0.0, 1.0);

	vec2 parallaxUV = texcoord;
	float parallaxShadow = 1.0;
	#ifdef PARALLAX_MAPPING
		vec3 viewDirTS = normalize(vViewPos.xyz * tbnMatrix);
		parallaxUV = parallaxMapping(viewDirTS, texGradX, texGradY, parallaxOffset);

		#ifdef PARALLAX_SHADOW
			vec3 lightDirTS = normalize(shadowLightPosition * tbnMatrix);
			parallaxOffset -= viewDirTS * 0.005;
			parallaxShadow = ParallaxShadow(parallaxOffset, viewDirTS, lightDirTS, texGradX, texGradY);
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
	#ifdef PARALLAX_LERP
		vec3 normalTex = normalize(tbnMatrix * (textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0));
	#else
		vec3 normalTex = N;
	#endif
	vec4 specularTex = saturate(textureGrad(specular, parallaxUV, texGradX, texGradY));
	specularTex.g = saturate(specularTex.g + 0.5 / 255.0);

/* DRAWBUFFERS:045 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(parallaxShadow, 0.0), pack2x8To16(blockID/ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalTex), lmcoord);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
flat out float blockID, isPlants;
flat out float noAniso;
flat out vec4 v_tcrange;
flat out ivec2 textureResolution;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

#include "/lib/common/materialIdMapper.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/wavingPlants.glsl"

void main() {
	blockID = IDMapping();
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
	noAniso = blockID == NO_ANISO ? 1.0 : 0.0;

	// 来自滑稽君
	textureResolution = ivec2(round(abs(gl_MultiTexCoord0.xy - mc_midTexCoord.xy) * atlasSize * 2.0));
    v_tcrange.zw = textureResolution / vec2(atlasSize);
    v_tcrange.xy = mc_midTexCoord.xy - v_tcrange.zw * 0.5;

	// 来自BSL
	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texcoord - midCoord;
	vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
	vTexCoordAM.st  = min(texcoord, midCoord - texMinMidCoord);
	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;

	N = normalize(gl_NormalMatrix * gl_Normal);
	vec3 B = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	vec3 T = normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix = mat3(T, B, N);

	// 坐标
	vViewPos = gl_ModelViewMatrix * gl_Vertex;
	vec4 vWorldPos = viewPosToWorldPos(vViewPos);
	vec4 vMcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

	isPlants = 0.0;
	if(blockID == PLANTS_SHORT || blockID == LEAVES || blockID == PLANTS_TALL_L || blockID == PLANTS_TALL_U){
		isPlants = 1.0;
	}
	#ifdef WAVING_PLANTS
		const float waving_rate = WAVING_RATE;
		if(blockID == PLANTS_SHORT && gl_MultiTexCoord0.t < mc_midTexCoord.t){
			// pos, normal, A, B, D_amount, y_waving_amount
			vMcPos.xyz = wavingPlants(vMcPos.xyz, PLANTS_SHORT_AMPLITUDE, waving_rate, 0.0, 0.0);
		}
		if(blockID == LEAVES){
			vMcPos.xyz = wavingPlants(vMcPos.xyz, LEAVES_AMPLITUDE, waving_rate, 0.0, 1.0);
		}
		if((blockID == PLANTS_TALL_L && gl_MultiTexCoord0.t < mc_midTexCoord.t) || blockID == PLANTS_TALL_U){
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