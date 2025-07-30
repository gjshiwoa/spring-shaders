varying vec2 texcoord;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

// #include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"


#ifdef FSH
#include "/lib/camera/bloom.glsl"

const bool colortex0MipmapEnabled = true;

void main() {
	vec4 CT1 = texelFetch(colortex1, ivec2(gl_FragCoord.xy), 0);

	vec3 blur = BLACK;
	#ifdef BLOOM
		blur += horizontalDownSampling(2.0);
		blur += horizontalDownSampling(3.0);
		blur += horizontalDownSampling(4.0);
		blur += horizontalDownSampling(5.0);
		blur += horizontalDownSampling(6.0);
		blur += horizontalDownSampling(7.0);
		blur += horizontalDownSampling(8.0);
	#endif
	blur = max(blur, BLACK);
	CT1.rgb = blur;

/* DRAWBUFFERS:1 */
	gl_FragData[0] = CT1;
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