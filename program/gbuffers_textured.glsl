varying vec2 lmcoord;
varying vec2 texcoord;

varying vec4 glcolor;

varying vec3 sunColor, skyColor;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/camera/colorToolkit.glsl"

#include "/lib/lighting/lightmap.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

void main() {
	vec4 color = texture(tex, texcoord) * glcolor;
	if(isEyeInWater == 1) color.rgb = mix(color.rgb, getLuminance(color.rgb) * waterFogColor * 2.0, 0.66);
#if MC_VERSION >= 11500
	vec2 lightmap = AdjustLightmap(lmcoord);
	vec4 texColor = toLinearR(color);
	color.rgb = texColor.rgb * lightmap.x * 0.2;
	color.rgb += texColor.rgb * saturate(lightmap.y + 0.005) * getLuminance(sunColor) * 0.2;
	color.rgb += nightVision * texColor.rgb * NIGHT_VISION_BRIGHTNESS / PI;
	if(isEyeInWater == 1) color.rgb *= 0.5;
#endif

/* DRAWBUFFERS:05 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(normalEncode(normalize(upPosition)), lmcoord);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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

	sunColor = texelFetch(gaux2, SUN_COLOR_UV, 0).rgb;
	skyColor = texelFetch(gaux2, SKY_COLOR_UV, 0).rgb;
}

#endif