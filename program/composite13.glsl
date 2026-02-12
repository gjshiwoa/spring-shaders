varying vec2 texcoord;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

// #include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"


#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

void main() {
	#define BLOOM_DOWNSAMPLE
    #include "/lib/camera/bloom1.glsl"

/* DRAWBUFFERS:1 */
	gl_FragData[0] = vec4(color.rgb, 1.0);
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////BY ZYPanDa gjshiwoa////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif