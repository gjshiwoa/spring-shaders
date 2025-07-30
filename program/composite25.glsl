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

#include "/lib/camera/postFX.glsl"
#include "/lib/camera/depthOfField.glsl"


void main() {
	vec4 color = max(texture(colortex0, texcoord), 0.0);
	
	#ifdef DEPTH_OF_FIELD
		color.rgb = tentFilter(color.rgb);
	#endif

	#ifdef EXPOSURE
		avgExposure(color.rgb);
	#endif
	
	#ifdef VIGNETTE
		color.rgb = vignette(color.rgb);
	#endif

	color.rgb = simpleFilter(color.rgb, filterSlope, filterOffset, filterPower, FLITER_SATURATE);
	
	// vec3 q_albedo = textureLod(shadowcolor0, texcoord, 0.0).rgb;
    //     toLinear(q_albedo);
	// color.rgb = q_albedo;

	color.rgb = TONE_MAPPING(color.rgb);

	// toGamma(color);

	// color.rgb += vec3(1.0 * temporalWhiteNoise(gl_FragCoord.xy) / 255.0);

	// #ifdef LETTER_BOX
	// 	color.rgb = applyLetterbox(color.rgb, LETTER_BOX_SIZE);
	// #endif

	
	
	// color.rgb = drawTransmittanceLut1();
	// color.rgb = drawMultiScatteringLut();
	// color.rgb = textureORB(depthtex2, texcoord).rgb;
	// color.rgb = getNormal(texcoord);
	// color.rgb = normalize(viewPosToWorldPos(vec4(color.rgb, 0.0)).xyz);
	// color.rgb = texture(colortex7, texcoord).rgb;
	// color.rgb = textureLod(shadowcolor0, texcoord, 0.0).rgb;
	// color.rgb = vec3(textureLod(shadowcolor1, texcoord, 0.0).a);
	// color.rgb = normalize((shadowProjection * vec4(color.rgb, 0.0)).xyz);
	
	// color.rgb = getSpecularTex(texcoord).rgb;
	// color.rgb = vec3(temporalBayer64(gl_FragCoord.xy));
	// color.rgb = vec3(temporalBayer64(gl_FragCoord.xy));
	// color.rgb = vec3(textureLod(shadowtex1, texcoord, 0).r);
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = saturate(color);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif