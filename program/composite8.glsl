varying vec2 texcoord;
varying float curLum, preLum;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/position.glsl"

#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"
#include "/lib/camera/exposure.glsl"

#ifdef FSH
const bool colortex0MipmapEnabled = true;

#include "/lib/camera/bloom.glsl"
#include "/lib/camera/depthOfField.glsl"


void main() {
	vec3 blur = BLACK;
	vec4 color = texture(colortex0, texcoord);

	#ifdef BLOOM
		#if BLOOM_MODE == 0
			blur += upSampling(2.0) * 1.62;
			blur += upSampling(3.0) * 1.56;
			blur += upSampling(4.0) * 1.49;
			blur += upSampling(5.0) * 1.41;
			blur += upSampling(6.0) * 1.32;
			blur += upSampling(7.0) * 1.18;
			blur += upSampling(8.0) * 1.0;
		#elif BLOOM_MODE == 1
			blur += upSampling(2.0) * 1.0;
			blur += upSampling(3.0) * 1.18;
			blur += upSampling(4.0) * 1.32;
			blur += upSampling(5.0) * 1.41;
			blur += upSampling(6.0) * 1.49;
			blur += upSampling(7.0) * 1.56;
			blur += upSampling(8.0) * 1.62;
		#elif BLOOM_MODE == 2
			blur += upSampling(2.0) * 1.0;
			blur += upSampling(3.0) * 1.0;
			blur += upSampling(4.0) * 1.0;
			blur += upSampling(5.0) * 1.0;
			blur += upSampling(6.0) * 1.0;
			blur += upSampling(7.0) * 1.0;
			blur += upSampling(8.0) * 1.0;
		#endif
	#endif

	#if defined NETHER
		float bloomAmount = BLOOM_AMOUNT;
		bloomAmount += 0.025;
		color.rgb = pow(color.rgb, vec3(1.2)) * 2.0;
	#elif defined END
		float bloomAmount = BLOOM_AMOUNT;
		bloomAmount += 0.0120;
		color.rgb = pow(color.rgb, vec3(1.4)) * 8.0;
	#else
		float bloomAmount = BLOOM_AMOUNT;
		bloomAmount += rainStrength * RAIN_ADDITIONAL_BLOOM;

		if(isEyeInWater == 1){
			bloomAmount += UNDERWATER_ADD_BLOOM;
		}
	#endif

	color.rgb = mix(color.rgb, blur, bloomAmount);

	if(isEyeInWater == 1){
		color.rgb = pow(color.rgb, vec3(UNDERWATER_CANTRAST)) * UNDERWATER_BRI;
	}

	color.rgb = max(color.rgb, BLACK);
	



	vec4 CT2 = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0);
    if(ivec2(gl_FragCoord.xy) == ivec2(0, 0)){
        float AverageLum = mix(preLum, curLum, saturate(frameTime*2.0));
        CT2.a = AverageLum;
    }

	

	vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);
	#ifdef DEPTH_OF_FIELD
		CT1.r = calculateCoC();
	#endif


/* DRAWBUFFERS:012 */
	gl_FragData[0] = color;
	gl_FragData[1] = CT1;
	gl_FragData[2] = CT2;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH
const bool colortex0MipmapEnabled = true;

void main() {
	#if EXPOSURE_MODE == 0
		curLum = calculateAverageLuminance();
	#else
		curLum = calculateAverageLuminance1();
	#endif
	preLum = texelFetch(colortex2, ivec2(0, 0), 0).a;

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif