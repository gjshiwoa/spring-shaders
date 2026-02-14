varying vec2 lmcoord;
varying vec2 texcoord;

varying vec4 glcolor;

varying vec3 sunColor, skyColor;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"

#include "/lib/lighting/lightmap.glsl"

#ifdef FSH

void main() {
	vec4 color = texture(tex, texcoord) * glcolor;

	vec2 lightmap = AdjustLightmap(lmcoord);
	toLinear(color);
	color.rgb *= (lightmap.y + 0.005) * sunColor * 0.2;
	color.rgb *= 1.0 + lightmap.x;
	if(isEyeInWater == 1) color.rgb *= 0.5;

/* RENDERTARGETS: 0 */
	gl_FragData[0] = vec4(color.rgb, color.a);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
#include "/lib/common/noise.glsl"

void main() {
	gl_Position = ftransform();

	vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
	gl_Position.xyz /= gl_Position.w;
    gl_Position.xy += jitter * TAA_JITTER_AMOUNT;
    gl_Position.xyz *= gl_Position.w;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;

	sunColor = texelFetch(gaux4, sunColorUV, 0).rgb;
	skyColor = texelFetch(gaux4, skyColorUV, 0).rgb;
}

#endif