#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH
in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in mat3 tbnMatrix;
in vec3 N;

void main() {
	vec2 parallaxUV = texcoord;

	vec2 texGradX = dFdx(texcoord);
	vec2 texGradY = dFdy(texcoord);

	vec4 color = texture(tex, texcoord) * glcolor;
	
	float parallaxShadow = 1.0;

	vec3 normalTex = normalize(tbnMatrix * (textureGrad(normals, parallaxUV, texGradX, texGradY).rgb * 2.0 - 1.0));
	vec4 specularTex = texture(specular, texcoord);

	vec2 lmCoord = lmcoord;
	float heldBlockLight = max(heldBlockLightValue, heldBlockLightValue2) / 15.0;
	lmCoord.x = max(heldBlockLight * 0.5, lmCoord.x);

#ifdef PATH_TRACING
/* DRAWBUFFERS:0459 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(HAND / ID_SCALE, 0.0), vec4(0.0));
	gl_FragData[2] = vec4(normalEncode(normalTex), lmCoord);
	gl_FragData[3] = vec4(0.0, 0.0, normalEncode(N));
#else
/* DRAWBUFFERS:045 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(pack2x8To16(1.0, 0.0), pack2x8To16(HAND / ID_SCALE, 0.0), vec4(0.0));
	gl_FragData[2] = vec4(normalEncode(normalTex), lmCoord);
#endif
}


#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZY//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#ifdef GSH

#include "/lib/common/position.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in vec2 v_lmcoord[];
in vec2 v_texcoord[];
in vec4 v_glcolor[];
in mat3 v_tbnMatrix[];
in vec3 v_N[];
in vec2 v_midTexCoord[];
in vec4 v_viewPos[];
in vec4 v_midBlock[];

layout(rgba16f) uniform image2D colorimg7;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out mat3 tbnMatrix;
out vec3 N;

void main() {
	float maxLength = max3(distance(v_viewPos[0].xyz, v_viewPos[1].xyz), 
                            distance(v_viewPos[1].xyz, v_viewPos[2].xyz), 
                            distance(v_viewPos[2].xyz, v_viewPos[0].xyz));

	#if defined PATH_TRACING || defined COLORED_LIGHT
		if(maxLength > 0.5){
			vec4 ndcPos0 = gl_in[0].gl_Position / gl_in[0].gl_Position.w;
			float spe = texture(specular, v_midTexCoord[0]).a;
			vec2 bias = abs(v_texcoord[0] - v_midTexCoord[0]) * 0.5;
			vec2 biasArr[5] = vec2[](
				vec2(0.0, 0.0),
				vec2(bias.x, bias.y),
				vec2(-bias.x, bias.y),
				vec2(-bias.x, -bias.y),
				vec2(bias.x, -bias.y)
			);
			vec3 lightCol = vec3(0.0);
			float weight = 0.0;
			for(int j = 0; j < 5; j++){
				vec4 litTexCol = texture(tex, v_midTexCoord[0] + biasArr[j]);
				lightCol += litTexCol.rgb * litTexCol.a;
				weight += litTexCol.a;
			}
			lightCol /= max(weight, 0.01);
			if(weight < 0.5) lightCol = vec3(0.0);
			vec3 outCol = lightCol * v_glcolor[0].rgb;
			if(ndcPos0.x > 0.0) imageStore(colorimg7, rightLitUV, vec4(outCol, heldBlockLightValue / 15.0));
			if(ndcPos0.x < 0.0) imageStore(colorimg7, LeftLitUV, vec4(outCol, heldBlockLightValue2 / 15.0));
		}
	#endif

	for(int i = 0; i < 3; ++i){
		lmcoord = v_lmcoord[i];
		texcoord = v_texcoord[i];
		glcolor = v_glcolor[i];
		tbnMatrix = v_tbnMatrix[i];
		N = v_N[i];
		
		gl_Position = gl_in[i].gl_Position;
		
		EmitVertex();
	}
	EndPrimitive();
}
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZY//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
#include "/lib/common/noise.glsl"

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
attribute vec4 at_midBlock;

out vec2 v_lmcoord, v_texcoord;
out vec4 v_glcolor;
out mat3 v_tbnMatrix;
out vec3 v_N;
out vec2 v_midTexCoord;
out vec4 v_viewPos;
out vec4 v_midBlock;

void main() {
	gl_Position = ftransform();
	v_viewPos = gl_ModelViewMatrix * gl_Vertex;
	v_lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	#if defined PATH_TRACING || defined COLORED_LIGHT
		v_lmcoord.x = (at_midBlock.a - 1.0) / 15.0;
	#endif
	v_texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	v_glcolor = gl_Color;
	v_midTexCoord = mc_midTexCoord.xy;
	v_midBlock = at_midBlock;

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;

	// TBN Mat 参考自 BSL shader
	v_N = normalize(gl_NormalMatrix * gl_Normal);
	vec3 B = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	vec3 T = normalize(gl_NormalMatrix * at_tangent.xyz);
	v_tbnMatrix = mat3(T, B, v_N);
}

#endif