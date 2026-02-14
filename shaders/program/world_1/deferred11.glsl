#define CLOUD3D

varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

// varying vec3 sunColor, skyColor;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"

#include "/lib/camera/filter.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

#include "/lib/common/gbufferData.glsl"
// #include "/lib/atmosphere/fog.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/atmosphere/endFog.glsl"


void main() {
	vec4 color = texture(colortex0, texcoord);

	float depth0 = texture(depthtex0, texcoord).r;
	vec4 viewPos0 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth0, 1.0));
	vec4 worldPos0 = viewPosToWorldPos(viewPos0);
	float worldDis0 = length(worldPos0);

	float depth1 = texture(depthtex1, texcoord).r;
    vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	float worldDis1 = length(worldPos1);

	vec3 viewDir = normalize(viewPos1.xyz);
	vec3 worldDir = normalize(worldPos1.xyz);

	vec3 fogColor = mix(endColor * 10.0, endColor, pow(abs(dot(upWorldDir, worldDir)), 0.45)) * 0.004;
	if(skyB > 0.5){
		color.rgb = fogColor;
		color.rgb += 25.0 * drawStars(worldDir);

        float dist1 = min(20000.0, worldDis0);

        float cloudTransmittance = 1.0;
        vec3 cloudScattering = vec3(0.0);
        float cloudHitLength = 0.0;
        vec4 intScattTrans = vec4(0.0, 0.0, 0.0, 1.0);
        #ifdef VOLUMETRIC_CLOUDS
            cloudRayMarching(camera, worldPos0.xyz, intScattTrans, cloudHitLength);
        #endif
        color.rgb = color.rgb * intScattTrans.a + intScattTrans.rgb * 1.;
	}
	
	color.rgb = underWaterFog(color.rgb, worldDir, worldDis0);

	// color.rgb = vec3(texture(colortex1, texcoord).rgb);
	color.rgb = max(color.rgb, BLACK);

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
    moonWorldDir = sunWorldDir;
    lightWorldDir = sunWorldDir;

	sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
	moonViewDir = sunViewDir;
	lightViewDir = sunViewDir;


	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	sunRiseSetS = saturate(1 - isNoon - isNight);

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif