varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

// varying vec3 sunColor, skyColor;


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
#include "/lib/water/translucentLighting.glsl"

float fakeCaustics(vec3 pos){
    float height = 64.0;

    // 点积向上向量和光照方向向量得到cos值   预定高度和实际高度的高度差
    float cosUpSunpos = abs(dot(vec3(0.0,1.0,0.0), lightWorldDir));
    float hDiff = abs(height - pos.y);

    // 高度差 * （1除以cos）得到斜边长度   sqrt（斜边的平方-邻边的平方）得到对边长度
    float hyp = hDiff * (1 / cosUpSunpos + 0.01);
    float dist = sqrt(hyp * hyp - hDiff * hDiff);

    // 单位化光照向量，乘上对边长度得到偏移向量
    vec3 unit = normalize(vec3(lightWorldDir.x, 0.0, lightWorldDir.z));
    vec3 offset = dist * unit;

    vec2 waveUV = vec2(0.0);
    if(pos.y < 64){
        waveUV = pos.xz + offset.xz;
    }else{
        waveUV = pos.xz - offset.xz;
    }

    // worley 伪造焦散，最后用pow值调整曲线
    float caustics  = texture(depthtex2, vec3(waveUV * 0.015, 0.0) + frameTimeCounter * 0.025).g;


    return caustics;
}

void main() {
	vec4 color = texture(colortex0, texcoord);
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

		MaterialParams materialParams = MapMaterialParams(specularMap);
		#ifdef PBR_REFLECTIVITY
			mat2x3 PBR = CalculatePBR(viewDir, normalV, lightViewDir, albedo, materialParams);
			vec3 BRDF = PBR[0] + PBR[1];
			vec3 BRDF_D = BRDF_Diffuse(normalV, viewDir, albedo, materialParams);
		#else
			vec3 BRDF = albedo / PI;
			vec3 BRDF_D = BRDF;
		#endif

		float noRSM = entities + block + hand > 0.5 ? 1.0 : 0.0;
		vec3 skyLight = 0.0025 * endColor * albedo;
		
		vec4 gi = getGI(depth1, normalW);
		if(noRSM < 0.5) {
			ao = gi.a;
		}

		float shade = shadowMappingTranslucent(worldPos1, normalW, 0.5, 5.0);
		vec3 direct = BRDF * endColor * shade * pow(fakeCaustics(worldPos1.xyz + cameraPosition), 1.0) * 0.045 * saturate(dot(lightViewDir, normalV));

		// diffuse = mix(diffuse, vec3(getLuminance(diffuse)), 0.5);
		vec3 artificial = lightmap.x * artificial_color * diffuse;
		artificial += saturate(materialParams.emissiveness - lightmap.x) * diffuse * EMISSIVENESS_BRIGHTNESS;
		artificial *= 0.5;

		
		
		color.rgb = (endColor * 0.333333 + albedo) * 0.005;
		color.rgb += skyLight * SKY_LIGHT_BRIGHTNESS;
		color.rgb *= ao /*+ aoMultiBounce * 0.2*/;
		color.rgb += direct;
		color.rgb += artificial;
	}

	// color.rgb = vec3(texture(colortex1, texcoord * 0.5).rgb);
	color.rgb = max(BLACK, color.rgb);

	CT4.rg = pack4x8To2x16(vec4(texColor, ao));

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
	sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
    moonWorldDir = sunWorldDir;
    lightWorldDir = sunWorldDir;

	sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
	moonViewDir = sunViewDir;
	lightViewDir = sunViewDir;

	// sunColor = getSunColor();
	// skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif