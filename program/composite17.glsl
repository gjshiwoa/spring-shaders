varying vec2 texcoord;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/position.glsl"

// #include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"


#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;
#include "/lib/camera/depthOfField.glsl"

void main() {
	vec4 color = texture2D(colortex0, texcoord);
	// color.rgb = color.rgb = textureLod(shadowcolor0, texcoord, 0.0).rgb;
	#ifdef DEPTH_OF_FIELD
		color.rgb = sampleWithKernel();
	#endif

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa/////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif