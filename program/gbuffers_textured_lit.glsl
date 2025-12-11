varying vec2 lmcoord;
varying vec2 texcoord;

varying vec4 glcolor;

varying vec3 sunColor, skyColor, lightColor;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/camera/colorToolkit.glsl"

#include "/lib/lighting/lightmap.glsl"

#ifdef FSH

void main() {
	vec4 color = texture(tex, texcoord) * glcolor;
#if MC_VERSION >= 11500
	vec4 texColor = toLinearR(color);
	vec2 lightmap = AdjustLightmap(lmcoord);
	color.rgb = texColor.rgb * lightmap.x * 0.4 * lightColor;
	color.rgb += texColor.rgb * saturate(lightmap.y + 0.0005) * (sunColor * saturate(lightmap.y) + skyColor);
	color.rgb += nightVision * texColor.rgb * NIGHT_VISION_BRIGHTNESS / PI;
#endif

/* DRAWBUFFERS:05 */
	gl_FragData[0] = vec4(color.rgb, color.a);
	gl_FragData[1] = vec4(normalEncode(normalize(upPosition)), lmcoord);
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

	sunColor = texelFetch(gaux4, sunColorUV, 0).rgb * 0.4;
	skyColor = texelFetch(gaux4, skyColorUV, 0).rgb;
	lightColor = artificial_color;
	#ifdef END
		sunColor = mix(vec3(1.0), endColor, 0.8) * 2.0;
		skyColor = endColor * 0.0;
		lightColor *= 3.0;
	#endif
	#ifdef NETHER
		sunColor = mix(vec3(1.0), netherColor, 0.3) * 5.0;
		skyColor = netherColor * 0.0;
		lightColor = netherColor * 1.0;
	#endif


}

#endif