varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying float isNoon, isNight, sunRiseSet;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/position.glsl"

#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/toneMapping.glsl"
#include "/lib/camera/filter.glsl"

#include "/lib/antialiasing/TAA.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

void main() {
	vec3 nowColor = texture(colortex0, texcoord).rgb;
	TAA(nowColor);
	nowColor = max(nowColor, BLACK);

	vec4 CT2 = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0);
	CT2.rgb = nowColor;

	

	#ifdef NETHER
		nowColor = pow(nowColor, vec3(1.0)) * 1.5;
	#elif defined END
		nowColor = pow(nowColor, vec3(1.0)) * 1.0;
	#else
		nowColor = nowColor * (1.0 - 0.15 * isNight);

		if(isEyeInWater == 1){
			nowColor.rgb = pow(nowColor.rgb, vec3(UNDERWATER_CANTRAST)) * UNDERWATER_BRI;
		}

	#endif

/* DRAWBUFFERS:02 */
	gl_FragData[0] = vec4(nowColor, 1.0);
	gl_FragData[1] = CT2;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa gjshiwoa////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunViewDir = normalize(sunPosition);
	moonViewDir = normalize(moonPosition);
	lightViewDir = normalize(shadowLightPosition);

	sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

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

	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif