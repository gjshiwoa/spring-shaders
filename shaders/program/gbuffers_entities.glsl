varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 N;


varying vec4 glcolor;

varying mat3 tbnMatrix;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH

flat in float entityIdMap;

void main() {
	vec2 parallaxUV = texcoord;

	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);

	vec4 texColor = texture(tex, texcoord);

	vec4 color = texColor * glcolor;
	bool lightning = entityIdMap == LIGHTNING_BOLT || entityIdMap == FIREWORK_ROCKET;
	if(entityIdMap == LIGHTNING_BOLT) {
		color = vec4(vec3(0.0), 1.0);
	}
	
	if (color.a <= 0.0005) discard;
	color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
	
	
	float parallaxShadow = 1.0;

	vec3 normalTex = normalize(tbnMatrix * (textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0));
	vec4 specularTex = texture(specular, texcoord);

	vec2 lightmapCoord = lmcoord;
	if(lightning){
		specularTex = vec4(0.0, 0.0, 0.0, 253.0 / 255.0);
		normalTex = normalize(upPosition);
		lightmapCoord = vec2(0.0, 1.0);
	}

#ifdef PATH_TRACING
#ifdef VOXY
/* RENDERTARGETS: 0,4,5,9,19 */
#else
/* RENDERTARGETS: 0,4,5,9 */
#endif
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(entityIdMap / ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalTex), lightmapCoord);
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
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(entityIdMap / ID_SCALE, 0.0), pack4x8To2x16(specularTex));
	gl_FragData[2] = vec4(normalEncode(normalTex), lightmapCoord);
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
flat out float entityIdMap;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
attribute vec3 at_velocity;
attribute vec4 at_midBlock;

#include "/lib/common/materialIdMapper.glsl"
#include "/lib/common/noise.glsl"

void main() {
	entityIdMap = IDMappingEntity();
	gl_Position = ftransform();

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
	// T_tbnMatrix = transpose(tbnMatrix);

	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	#if defined PATH_TRACING || defined COLORED_LIGHT
		lmcoord.x = ((at_midBlock.a - 1.0)) / 15.0;
	#endif
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}

#endif
