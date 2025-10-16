varying vec2 lmcoord, texcoord;

varying vec3 normalVO, normalWO;

varying vec4 glcolor;

varying float worldDis0;
varying vec4 vViewPos, vWorldPos, vMcPos;
varying float isNoon, isNight, sunRiseSet;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;
varying vec3 zenithColor, horizonColor;

varying mat3 tbnMatrix;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"

// #include "/lib/atmosphere/atmosphericScattering.glsl"
// #include "/lib/atmosphere/celestial.glsl"

// #include "/lib/lighting/lightmap.glsl"
// #include "/lib/lighting/shadowMapping.glsl"

// #include "/lib/water/waterNormal.glsl"
// #include "/lib/water/waterFog.glsl"
// #include "/lib/water/waterReflectionRefraction.glsl"
// #include "/lib/surface/PBR.glsl"

#ifdef FSH
// #include "/lib/water/translucentLighting.glsl"

// const bool colortex5MipmapEnabled = true;

flat in float isWater;

void main() {
	vec4 color = vec4(0.0);

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
// #include "/lib/common/noise.glsl"
flat out float isWater;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
// attribute vec4 at_tangent;

void main() {
	gl_Position = ftransform();
	isWater = dhMaterialId == DH_BLOCK_WATER ? 1.0 : 0.0;

	vViewPos = gl_ModelViewMatrix * gl_Vertex;
	vWorldPos = viewPosToWorldPos(vViewPos);
	worldDis0 = length(vWorldPos.xyz);
	vMcPos = vec4(vWorldPos.xyz + cameraPosition, 1.0);

	// TBN Mat 参考自 BSL shader
	vec4 at_tangent = vec4(normalize(cross(gl_Normal.xyz, vec3(0.333333333))), 1.0);
	vec3 N = normalize(gl_NormalMatrix * gl_Normal);
	vec3 B = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	vec3 T = normalize(gl_NormalMatrix * at_tangent.xyz);
	tbnMatrix = mat3(T, B, N);

	normalVO = N;
	normalWO = viewPosToWorldPos(vec4(N, 0.0)).xyz;

	sunViewDir = normalize(sunPosition);
	moonViewDir = normalize(moonPosition);
	lightViewDir = normalize(shadowLightPosition);

	sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	// sunColor = texelFetch(gaux2, SUN_COLOR_UV, 0).rgb;
	// skyColor = texelFetch(gaux2, SKY_COLOR_UV, 0).rgb;
	// zenithColor = texelFetch(gaux2, ZENITH_COLOR_UV, 0).rgb;
	// horizonColor = texelFetch(gaux2, HORIZON_COLOR_UV, 0).rgb;

	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}

#endif