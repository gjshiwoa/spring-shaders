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

#include "/lib/atmosphere/atmosphericScattering.glsl"
#include "/lib/atmosphere/celestial.glsl"

#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/shadowMapping.glsl"

#include "/lib/water/waterNormal.glsl"
#include "/lib/water/waterFog.glsl"
#include "/lib/water/waterReflectionRefraction.glsl"
#include "/lib/surface/PBR.glsl"

#ifdef FSH
#include "/lib/water/translucentLighting.glsl"

const bool colortex5MipmapEnabled = true;

flat in float isWater;

void main() {
	vec2 fragCoord = gl_FragCoord.xy * invViewSize;
	if(length(vViewPos.xyz) < far * 0.9) discard;
	if(texture(depthtex0, fragCoord).r < 1.0) discard;

	bool isUnderwater = (isEyeInWater == 1);
	bool isAbovewater = (isEyeInWater == 0);
	vec4 mcPos = vMcPos;

	
	vec2 lightmap = AdjustLightmap(lmcoord);

	vec4 color = vec4(BLACK, 1.0);
	if(isWater > 0.5){
		vec2 refractCoord = fragCoord;
		float depth1 = texture(dhDepthTex1, refractCoord).r;
		vec4 viewPos1 = screenPosToViewPosDH(vec4(refractCoord, depth1, 1.0));
		vec3 viewDir = normalize(viewPos1.xyz);
		vec4 worldPos1 = viewPosToWorldPos(viewPos1);
		float worldDis1 = length(worldPos1.xyz);
		vec3 worldDir = normalize(worldPos1.xyz);

		vec3 viewDirTS = normalize(viewDir * tbnMatrix);
		vec2 waveParallaxUV = mcPos.xz;
		vec3 waveViewNormal = normalize(tbnMatrix * getWaveNormal(waveParallaxUV * 0.5));
		vec3 waveWorldNormal = normalize(viewPosToWorldPos(vec4(waveViewNormal, 0.0)).xyz);

		float lightmapY = saturate(lightmap.y + NIGHT_VISION_BRIGHTNESS * nightVision);
		float deep = worldDis1 - worldDis0;
		vec3 fogColor = waterFogColor * (sunColor * 0.125 + NIGHT_VISION_BRIGHTNESS * nightVision);

		if (isAbovewater) {
			float depthFactor = saturate(deep / WATER_MIST_VISIBILITY);
			vec3 fogAttenuation = saturate(fastExp(-(vec3(1.0) - fogColor) * deep * WATER_FOG_TRANSMIT));
			color.rgb = texture(gaux1, fragCoord, 1).rgb * 3.5;
			color.rgb *= fogAttenuation;
			color.rgb = mix(color.rgb, fogColor * 0.25 * lightmapY, saturate(depthFactor + 0.5));
		}



		vec3 reflectWorldDir = reflect(worldDir, waveWorldNormal);
		vec3 reflectViewDir = reflect(viewDir, waveViewNormal);
	
		float underwaterFactor = isUnderwater ? 0.0 : 1.0;
		int ssrTargetSampled = 0;
		
		float cosTheta = dot(-worldDir, waveWorldNormal);
		float fresnel = mix(pow(1.0 - saturate(cosTheta), REFLECTION_FRESNAL_POWER), 1.0, WATER_F0);

		#ifdef WATER_REFLECTION
			vec3 reflectColor = reflection(
				gaux1, 
				vViewPos.xyz, 
				reflectWorldDir, 
				reflectViewDir, 
				lightmapY * underwaterFactor, 
				normalVO, 
				COLOR_UI_SCALE, 
				ssrTargetSampled
			);
			
			if (isAbovewater) {
				color.rgb = mix(color.rgb, reflectColor, fresnel);
			}
		#endif

	}else{
		vec2 lightmap = AdjustLightmap(lmcoord);
		vec4 texColor = glcolor;
		color.rgb = texColor.rgb * lightmap.x * 0.2;
		color.rgb += texColor.rgb * saturate(lightmap.y + 0.005) * getLuminance(sunColor) * 0.2;
		color.rgb += nightVision * texColor.rgb * NIGHT_VISION_BRIGHTNESS / PI;
		if(isEyeInWater == 1) color.rgb *= 0.5;
	}

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

	sunColor = texelFetch(gaux2, SUN_COLOR_UV, 0).rgb;
	skyColor = texelFetch(gaux2, SKY_COLOR_UV, 0).rgb;
	zenithColor = texelFetch(gaux2, ZENITH_COLOR_UV, 0).rgb;
	horizonColor = texelFetch(gaux2, HORIZON_COLOR_UV, 0).rgb;

	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
}

#endif