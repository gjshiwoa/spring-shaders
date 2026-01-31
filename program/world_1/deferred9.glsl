#define SKY_BOX
#define PROGRAM_VLF

varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"

#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;


#include "/lib/common/gbufferData.glsl"
#include "/lib/common/materialIdMapper.glsl"
#include "/lib/common/octahedralMapping.glsl"
#include "/lib/atmosphere/fog.glsl"
#include "/lib/atmosphere/endFog.glsl"

void main() {
	vec4 CT7 = texelFetch(colortex7, ivec2(gl_FragCoord.xy), 0);

	vec2 uv = texcoord * 2.0;
	if(!outScreen(uv)){

		vec3 worldDir = octahedralToDirection(uv);

		float d_p2a = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r + atmosphere_h).y;
		float d_p2e = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r).x;
		float d = d_p2e > 0.0 ? d_p2e : d_p2a;
		d = max(d, 0.0);

        vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
		vec3 fogColor = mix(endColor * 10.0, endColor, pow(abs(dot(upWorldDir, worldDir)), 0.45)) * 0.004;
        color.rgb = fogColor;

        float cloudTransmittance = 1.0;
        vec3 cloudScattering = vec3(0.0);
        float cloudHitLength = 0.0;
        vec4 intScattTrans = vec4(0.0, 0.0, 0.0, 1.0);
        #ifdef VOLUMETRIC_CLOUDS
            cloudRayMarching(camera, worldDir.xyz * far, intScattTrans, cloudHitLength);
        #endif
        color.rgb = color.rgb * intScattTrans.a + intScattTrans.rgb * 1.;

        color.rgb = underWaterFog(color.rgb, worldDir, far);
		
		CT7.rgb = max(color.rgb, vec3(0.0));

		if(!outScreen(texcoord * 2.0))
			CT7.rgb = mix(texture(colortex7, texcoord).rgb, CT7.rgb, 0.05);
	}

	if(ivec2(gl_FragCoord.xy) == rightLitPreUV){
		vec4 newColor = texelFetch(colortex7, rightLitUV, 0);
		vec4 preColor = texelFetch(colortex7, rightLitPreUV, 0);
		CT7 = mix(preColor, newColor, 0.05);
	}
		
	if(ivec2(gl_FragCoord.xy) == LeftLitPreUV){
		vec4 newColor = texelFetch(colortex7, LeftLitUV, 0);
		vec4 preColor = texelFetch(colortex7, LeftLitPreUV, 0);
		CT7 = mix(preColor, newColor, 0.05);
	}

/* DRAWBUFFERS:7 */
	gl_FragData[0] = CT7;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////ZY/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
    moonWorldDir = sunWorldDir;
    lightWorldDir = sunWorldDir;

	sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
	moonViewDir = sunViewDir;
	lightViewDir = sunViewDir;

	sunColor = endColor * 1.5;
	skyColor = endColor * 0.2 + vec3(0.2);

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif