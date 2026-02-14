uniform sampler2D tex;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

// 感谢 樱雪 大佬在兼容性方面提供的帮助

#if defined CLOUD3D || defined SKY_BOX || defined SHD || defined PROGRAM_VLF
uniform sampler3D colortex2;
uniform sampler3D colortex8;
#else
uniform sampler2D colortex2;
uniform sampler2D colortex8;
#endif

uniform sampler2D noisetex;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;

#ifdef GBF
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
#else
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
#endif

uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;

uniform sampler2D colortex16;
uniform sampler2D colortex17;
uniform sampler2D colortex18;
uniform sampler2D colortex19;

uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler3D customimg0;
uniform usampler3D customimg3;
uniform sampler3D customimg4;
uniform sampler3D customimg5;

uniform float alphaTestRef; 



uniform int entityId;
uniform vec4 entityColor;



uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 atlasSize;

uniform vec2 viewSize;
uniform vec2 invViewSize;



uniform float near;
uniform float far;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
vec3 upViewDir = normalize(upPosition);
uniform vec3 upWorldDir;
uniform vec3 cameraPosition;
uniform ivec3 cameraPositionInt;
uniform ivec3 cameraPositionFract;
uniform vec3 previousCameraPosition;
uniform ivec3 previousCameraPositionInt;
uniform vec3 previousCameraPositionFract;

uniform float centerDepthSmooth;

uniform int isEyeInWater;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
mat4 shadowMVP = shadowProjection * shadowModelView;
mat4 shadowMVPInverse = shadowModelViewInverse * shadowProjectionInverse;


uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;

uniform int dhRenderDistance;

uniform float dhNearPlane;
uniform float dhFarPlane;

uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;

uniform int vxRenderDistance;
uniform sampler2D vxDepthTexOpaque;
uniform sampler2D vxDepthTexTrans;
uniform mat4 vxModelView;
uniform mat4 vxProj;
uniform mat4 vxProjInv;
uniform mat4 vxViewProjInv;



uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform int framemod8;

uniform float rainStrength; 
uniform float wetness;

uniform ivec2 eyeBrightnessSmooth;
uniform float nightVision;
#ifdef IS_IRIS
    uniform int biome_precipitation;
#else
    const int biome_precipitation = 1;
#endif


uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

uniform int renderStage;
