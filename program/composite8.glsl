varying vec2 texcoord;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/noise.glsl"

#include "/lib/camera/colorToolkit.glsl"
#include "/lib/camera/filter.glsl"


#ifdef FSH

const bool shadowtex0Mipmap = false;
const bool shadowtex1Mipmap = false;
const bool shadowcolor0Mipmap = false;
const bool shadowcolor1Mipmap = false;

#include "/lib/camera/motionBlur.glsl"
#include "/lib/camera/depthOfField.glsl"

void main() {
    vec4 color = texture(colortex0, texcoord);
    
/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color.rgb, 1.0);
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
