vec4 CT4 = texture(colortex4, texcoord);
vec4 CT5 = texture(colortex5, texcoord);

vec2 mcLightmap = CT5.ba;

vec2 CT4R = unpack16To2x8(CT4.r);
vec2 CT4G = unpack16To2x8(CT4.g);
float blockID = CT4G.x * ID_SCALE;
float gbufferID = CT4G.y * ID_SCALE;
float parallaxShadow = CT4R.x;

vec4 specularMap = unpack2x16To4x8(CT4.ba);

vec2 normalEnc = CT5.rg;