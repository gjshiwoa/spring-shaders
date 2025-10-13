varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH

#include "/lib/common/gbufferData.glsl"

#include "/lib/surface/PBR.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/shadowMapping.glsl"
#include "/lib/lighting/screenSpaceShadow.glsl"



void main() {
	bool isTerrain = skyB < 0.5;
	float depth1 = texture(depthtex1, texcoord).r;
	vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));

	vec3 viewDir = normalize(viewPos1.xyz);
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	vec3 worldDir = normalize(worldPos1.xyz);
	vec3 shadowPos = getShadowPos(worldPos1).xyz;
	float worldDis1 = length(worldPos1);

	if(isTerrain){	
		MaterialParams materialParams = MapMaterialParams(specularMap);

		vec3 normalV = normalize(normalDecode(normalEnc));
		vec3 normalW = normalize(viewPosToWorldPos(vec4(normalV, 0.0)).xyz);
		float cos_theta_O = dot(normalV, lightViewDir);
		float cos_theta = max(cos_theta_O, 0.0);

		// bzyzhang: 练习项目(十一)：次表面散射的近似实现
		// https://zhuanlan.zhihu.com/p/348106844
		float sssWrap = SSS_INTENSITY * materialParams.subsurfaceScattering;
		if(plants > 0.5) sssWrap = 20.0;
		cos_theta = saturate((cos_theta_O + sssWrap) / (1 + sssWrap));

		float shadow = 1.0;
		float RTShadow = 1.0;
		if(!outScreen(shadowPos.xy) && cos_theta > 0.001){
			shadow = min(parallaxShadow, shadowMapping(worldPos1, normalW, sssWrap));
			shadow = max(shadow, 0.0);
			
		}
		if(worldDis1 > shadowDistance * 0.75){
			RTShadow = screenSpaceShadow(viewPos1.xyz, normalW, shadow);
		}
		CT4.r = pack2x8To16(shadow, RTShadow);
	}


/* DRAWBUFFERS:4 */
	gl_FragData[0] = CT4;
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

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif