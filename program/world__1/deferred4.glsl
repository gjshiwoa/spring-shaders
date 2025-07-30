varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH
const bool shadowtex1Mipmap = true;
const bool shadowtex1Nearest = false;

const bool shadowcolor0Mipmap = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Mipmap = true;
const bool shadowcolor1Nearest = false;



#include "/lib/common/gbufferData.glsl"

#include "/lib/common/materialIdMapper.glsl"
#include "/lib/lighting/lightmap.glsl"
#include "/lib/lighting/shadowMapping.glsl"
#include "/lib/lighting/screenSpaceShadow.glsl"
#include "/lib/lighting/RSM.glsl"
#include "/lib/lighting/SSAO.glsl"
#include "/lib/surface/PBR.glsl"



void main() {
	vec4 color = texture(colortex0, texcoord);	// albedo
	vec3 texColor = color.rgb;
	vec3 albedo = toLinearR(texColor);
	vec3 diffuse = albedo / PI;
	
	float depth1 = texture(depthtex1, texcoord).r;
    vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));
	vec3 viewDir = normalize(viewPos1.xyz);
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	vec3 shadowPos = getShadowPos(worldPos1).xyz;
	float worldDis1 = length(worldPos1);

	vec3 normalV = normalize(normalDecode(normalEnc));
	vec3 normalW = normalize(viewPosToWorldPos(vec4(normalV, 0.0)).xyz);

	vec3 L2 = BLACK;
	float ao = 1.0;

	if(skyB < 0.5){	
		vec2 lightmap = AdjustLightmap(mcLightmap);

		float noRSM = entities + block + hand > 0.5 ? 1.0 : 0.0;
		vec3 skyLight = 0.0025 * albedo;
		
		vec4 gi = getGI(depth1, normalW);
		if(noRSM < 0.5) {
			ao = gi.a;
		}

		vec3 direct = vec3(0.0);

		MaterialParams materialParams = MapMaterialParams(specularMap);
		diffuse = mix(diffuse, vec3(getLuminance(diffuse)), 0.5);
		vec3 artificial = lightmap.x * netherColor * (1. + GLOWING_BRIGHTNESS * glowingB) * diffuse;
		artificial += saturate(materialParams.emissiveness - lightmap.x) * diffuse * EMISSIVENESS_BRIGHTNESS;

		
		
		color.rgb = albedo * 0.005;
		color.rgb += skyLight * SKY_LIGHT_BRIGHTNESS;
		color.rgb *= ao /*+ aoMultiBounce * 0.2*/;
		color.rgb += direct;
		color.rgb += artificial;
	}

	// color.rgb = vec3(texture(colortex1, texcoord * 0.5).rgb);
	color.rgb = max(BLACK, color.rgb);

	CT4.rg = pack4x8To2x16(vec4(albedo, ao));

/* DRAWBUFFERS:04 */
	gl_FragData[0] = color;
	gl_FragData[1] = CT4;
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

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif