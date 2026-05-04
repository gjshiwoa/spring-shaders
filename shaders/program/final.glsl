varying vec2 texcoord;



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
#include "/lib/antialiasing/FSR.glsl"

vec3 sRGBEncodeSafe(vec3 c) {
	vec3 s = sign(c);
	c = abs(c);

	bvec3 cutoff = lessThan(c, vec3(0.0031308));
	vec3 higher = vec3(1.055) * pow(c, vec3(1.0 / 2.4)) - vec3(0.055);
	vec3 lower = c * vec3(12.92);
	c = mix(higher, lower, cutoff);

	return c * s;
}


void main() {
	#ifdef FSR_RCAS
		vec4 color = vec4(fsrRCAS(colortex0, ivec2(gl_FragCoord.xy)), 1.0);
	#else
		vec4 color = max(texture(colortex0, texcoord), 0.0);
	#endif

	#if defined(HDR_MOD_INSTALLED) && defined(HDR_ENABLED)
		color.rgb *= HdrGamePaperWhiteBrightness / max(HdrUIBrightness, 1.0);
		color.rgb = sRGBEncodeSafe(color.rgb);
	#else
		toGamma(color);
	#endif

	#ifdef LETTER_BOX
		color.rgb = applyLetterbox(color.rgb, LETTER_BOX_SIZE);
	#endif

	// color.rgb = 10.0 * texelFetch(colortex7, lightColorUV, 0).rgb;

	
	
	// color.rgb = drawTransmittanceLut1();
	// color.rgb = drawMultiScatteringLut();
	// color.rgb = textureORB(depthtex2, texcoord).rgb;
	// color.rgb = getNormal(texcoord);
	// color.rgb = normalize(viewPosToWorldPos(vec4(color.rgb, 0.0)).xyz);
	// color.rgb = texture(colortex6, texcoord).xyzypanda;
	// color.rgb = textureLod(shadowcolor0, texcoord, 0.0).rgb;
	// color.rgb = vec3(textureLod(shadowcolor1, texcoord, 0.0));
	// color.rgb = normalize((shadowProjection * vec4(color.rgb, 0.0)).xyz);
	
	// color.rgb = getSpecularTex(texcoord).rgb;
	// color.rgb = vec3(temporalBayer64(gl_FragCoord.xy));
	// color.rgb = vec3(temporalBayer64(gl_FragCoord.xy));
	// color.rgb = vec3(textureLod(shadowtex1, texcoord, 0).r);
	
/* RENDERTARGETS: 0 */
	#if defined(HDR_MOD_INSTALLED) && defined(HDR_ENABLED)
		gl_FragData[0] = vec4(color.rgb, 1.0);
	#else
		gl_FragData[0] = saturate(vec4(color.rgb, 1.0));
	#endif
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////Z///////////////////////////////////////////////////////////////////////////////////////////////////////////////////Y///////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
