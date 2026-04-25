varying vec2 lmcoord;
varying vec2 texcoord;

varying vec4 glcolor;

varying vec3 sunColor, skyColor, lightColor, baseLight;
varying vec3 N;



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

	vec3 ambLight = (sunColor + skyColor) * saturate(lightmap.y) + baseLight;
	ambLight *= texColor.rgb;
	color.rgb += ambLight;

	color.rgb += nightVision * texColor.rgb * NIGHT_VISION_BRIGHTNESS / PI;
#endif


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

	N = normalize(gl_NormalMatrix * gl_Normal);

	sunColor = texelFetch(gaux4, sunColorUV, 0).rgb * 0.5;
	skyColor = texelFetch(gaux4, skyColorUV, 0).rgb;

	#ifdef PATH_TRACING
		baseLight = vec3(DEFERRED10_PT_ALBEDO_SCALE);
	#else
		baseLight = vec3(DEFERRED10_ALBEDO_SCALE);
	#endif

	#ifdef CLOUD_SHADOW
		sunColor *= 1.0 - 0.5 * rainStrength;
		skyColor *= 1.0 - 0.5 * rainStrength;
	#endif

	#if defined PATH_TRACING || defined COLORED_LIGHT
		lightColor = normalize(texelFetch(gaux4, lightColorUV, 0).rgb) * 0.66;
		lightColor = max(lightColor, vec3(0.01));
	#else
		lightColor = artificial_color;
	#endif
	#ifdef END
		sunColor = mix(vec3(1.0), endColor, 0.8) * 0.5;
		skyColor = endColor * 0.5;
		lightColor *= 2.5;
		baseLight = vec3(0.125);
	#endif
	#ifdef NETHER
		skyColor = vec3(0.0);
		sunColor = vec3(0.0);
		lightColor = mix(vec3(1.0), netherColor, 0.5) * 0.5;
		baseLight = vec3(0.025);
	#endif
	#ifdef LIGHTNING
		sunColor = vec3(0.0);
		skyColor = vec3(0.0);
		lightColor = vec3(10.0);
	#endif


}

#endif