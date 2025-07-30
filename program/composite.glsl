varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;
varying vec3 horizonColor;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/camera/colorToolkit.glsl"
// #include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/atmosphere/atmosphericScattering.glsl"
#include "/lib/water/waterFog.glsl"

#ifdef FSH

void main() {
	vec4 color = texture(colortex0, texcoord);
	float depth = texture(depthtex0, texcoord).r;
	vec4 viewPos = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth, 1.0));
	vec4 worldPos = viewPosToWorldPos(viewPos);
	float worldDis = length(worldPos);
	vec3 worldDir = normalize(worldPos.xyz);

	#ifdef UNDERWATER_FOG
		if(isEyeInWater == 1){
			color.rgb = underWaterFog(color.rgb, worldDir, worldDis);
		}
	#endif
	// if(texture(depthtex0, texcoord).r < 1.0)
	// 	color.rgb = mix(color.rgb, horizonColor * SKY_BASE_COLOR_BRIGHTNESS, saturate(saturate((60.0 - worldPos.y) / 60.0) * remap(length(worldDis) / far, 0.66, 1.0, 0.0, 1.0)));

	vec4 viewPos1R = screenPosToViewPos(vec4(texcoord.st, depth, 1.0));
	vec4 worldPos1R = viewPosToWorldPos(viewPos1R);
	vec2 prePos = getPrePos(worldPos1R).xy;
	vec2 velocity = texcoord - prePos;

	vec4 CT5 = texture(colortex5, texcoord);
	CT5.ba = velocity;
	
/* DRAWBUFFERS:05 */
	gl_FragData[0] = color;
	gl_FragData[1] = CT5;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunViewDir = normalize(sunPosition);
	moonViewDir = normalize(moonPosition);
	lightViewDir = normalize(shadowLightPosition);

	sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

	sunColor = getSunColor();
	skyColor = getSkyColor();
	horizonColor = texelFetch(colortex1, HORIZON_COLOR_UV, 0).rgb;

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif