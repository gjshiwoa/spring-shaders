uniform sampler2D tex;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

// 感谢 樱雪 大佬在兼容性方面提供的帮助

#if defined DF4 || defined DF8 || defined DF5
uniform sampler3D depthtex2;
uniform sampler3D colortex2;
#else
uniform sampler2D depthtex2;
uniform sampler2D colortex2;
#endif

uniform sampler2D noisetex;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;

#ifdef SHD
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler3D gaux4;
#elif defined GBF
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

uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

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
uniform vec3 upWorldDir;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

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

#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex0;
    uniform sampler2D dhDepthTex1;

    uniform int dhRenderDistance;
    
    uniform float dhNearPlane;
    uniform float dhFarPlane;

    uniform mat4 dhProjection;
    uniform mat4 dhProjectionInverse;
    uniform mat4 dhPreviousProjection;
#endif

uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform int framemod8;
uniform float rainStrength; 



uniform ivec2 eyeBrightnessSmooth;
uniform float nightVision;
