varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/toneMapping.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/noise.glsl"

#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/camera/exposure.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

#include "/lib/camera/postFX.glsl"
#include "/lib/camera/depthOfField.glsl"


void main() {
	vec4 color = max(texture(colortex0, texcoord), 0.0);
	
	#ifdef DEPTH_OF_FIELD
		color.rgb = tentFilter(color.rgb);
	#endif

	#ifdef EXPOSURE
		avgExposure(color.rgb);
		#if !defined END && !defined NETHER
			color.rgb *= 1.0 + 1.0 * isNight * saturate(isEyeInWater);
		#endif

	#endif
	
	#ifdef VIGNETTE
		color.rgb = vignette(color.rgb);
	#endif

	color.rgb = simpleFilter(color.rgb, filterSlope, filterOffset, filterPower, FLITER_SATURATE);
	
	// vec3 q_albedo = textureLod(shadowcolor0, texcoord, 0.0).rgb;
    //     toLinear(q_albedo);
	// color.rgb = q_albedo;
	
	color.rgb = TONE_MAPPING(color.rgb);
	color.rgb += rand2_3(texcoord + sin(frameTimeCounter)) / 255.0;

	// toGamma(color);

	// color.rgb += vec3(1.0 * temporalWhiteNoise(gl_FragCoord.xy) / 255.0);

	// #ifdef LETTER_BOX
	// 	color.rgb = applyLetterbox(color.rgb, LETTER_BOX_SIZE);
	// #endif

	
	
	// color.rgb = drawTransmittanceLut1();
	// color.rgb = drawMultiScatteringLut();
	// color.rgb = textureORB(depthtex2, texcoord).rgb;
	// color.rgb = getNormal(texcoord);
	// color.rgb = normalize(viewPosToWorldPos(vec4(color.rgb, 0.0)).xyz);
	// color.rgb = texture(colortex1, texcoord).rgb;
	// color.rgb = textureLod(shadowcolor0, texcoord, 0.0).rgb;
	// color.rgb = vec3(textureLod(shadowcolor1, texcoord, 0.0).a);
	// color.rgb = normalize((shadowProjection * vec4(color.rgb, 0.0)).xyz);
	// color.rgb = vec3(texture(dhDepthTex0, texcoord).rgb);
	// color.rgb = getSpecularTex(texcoord).rgb;
	// color.rgb = vec3(temporalBayer64(gl_FragCoord.xy));
	// color.rgb = vec3(temporalBayer64(gl_FragCoord.xy));
	// color.rgb = vec3(textureLod(shadowtex1, texcoord, 0).r);

	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
	vec2 uv1 = texcoord * 2.0 - vec2(1.0, 0.0);
	if(!outScreen(uv1)){
		CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy + vec2(-0.5, 0.5) * viewSize), 0);
	}
	// color = CT6;
/* DRAWBUFFERS:06 */
	gl_FragData[0] = saturate(color);
	gl_FragData[1] = CT6;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa gjshiwoa////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	#ifdef END
		sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
		moonWorldDir = sunWorldDir;
		lightWorldDir = sunWorldDir;

		sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
		moonViewDir = sunViewDir;
		lightViewDir = sunViewDir;
	#elif defined NETHER
		sunWorldDir = normalize(vec3(0.0, 1.0, 0.0));
		moonWorldDir = sunWorldDir;
		lightWorldDir = sunWorldDir;

		sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
		moonViewDir = sunViewDir;
		lightViewDir = sunViewDir;
	#endif

	isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	sunRiseSetS = saturate(1 - isNoonS - isNightS);
}

#endif