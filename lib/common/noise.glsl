const vec2 Halton_2_3[8] = vec2[](
    vec2(0.0f, -1.0f / 3.0f),
    vec2(-1.0f / 2.0f, 1.0f / 3.0f),
    vec2(1.0f / 2.0f, -7.0f / 9.0f),
    vec2(-3.0f / 4.0f, -1.0f / 9.0f),
    vec2(1.0f / 4.0f, 5.0f / 9.0f),
    vec2(-1.0f / 4.0f, -5.0f / 9.0f),
    vec2(3.0f / 4.0f, 1.0f / 9.0f),
    vec2(-7.0f / 8.0f, 7.0f / 9.0f)
);

vec2 unTAAJitter(vec2 uv){
    vec2 jitter = Halton_2_3[framemod8];	//-1 to 1
	jitter *= invViewSize;
    vec2 newUV = uv - jitter * TAA_JITTER_AMOUNT * 0.5;

    return newUV;
}

// robobo1221: Real time PBR Volumetric Clouds 
// https://www.shadertoy.com/view/MstBWs
float bayer2(vec2 a){
    a = floor(a);
    return fract(dot(a, vec2(.5, a.y * .75)));
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))

float temporalBayer64(vec2 fragCoord){
    float bayer = bayer64(fragCoord);
    return fract(bayer + (frameCounter % 64) * GOLDEN_RATIO);
}

float radicalInverse(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

vec3 optimizedBayer3D(vec2 fragCoord) {
    float bayer = bayer64(fragCoord);
    uint frame = uint(frameCounter % 256);
    
    return vec3(
        fract(bayer + frame * 0.61803398874989484820459),
        radicalInverse(frame),
        fract(radicalInverse(frame) + bayer)
    );
}

vec3 temporalBayer3D(vec2 fragCoord) {
    const float PHI = 1.61803398874989484820459;
    const float PHI2 = PHI * PHI;
    const float PHI3 = PHI2 * PHI;
    
    float bayer = bayer64(fragCoord);

    float x = fract(bayer + (frameCounter % 144) * (1.0/PHI));
    float y = fract(bayer + (frameCounter % 233) * (1.0/PHI2));
    float z = fract(bayer + (frameCounter % 377) * (1.0/PHI3));
    
    return vec3(x, y, z);
}


const float OFFSET_1 = 1.234;
const float OFFSET_2 = 5.678;

vec3 temporalBayer64_3D(vec2 fragCoord){
    float bayer = bayer64(fragCoord);
    float noiseX = fract(bayer + float(frameCounter) * GOLDEN_RATIO);
    float noiseY = fract(bayer + float(frameCounter) * GOLDEN_RATIO + OFFSET_1);
    float noiseZ = fract(bayer + float(frameCounter) * GOLDEN_RATIO + OFFSET_2);

    return vec3(noiseX, noiseY, noiseZ);
}

// #ifndef CLOUD3D
float temporalBlueNoise(vec2 fragCoord) {
    float blueNoise = texelFetch(noisetex, ivec2(fragCoord) % noiseTextureResolution, 0).r;
    return fract(blueNoise + float(frameCounter) * GOLDEN_RATIO);
}
// #endif

float rand2_1(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898,78.233)))*43758.5453123);
}

float temporalWhiteNoise(vec2 uv){
    return rand2_1(uv + sin(frameTimeCounter));
}

vec3 rand2_3(vec2 p) {
    vec3 r;
    r.x = fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
    r.y = fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453123);
    r.z = fract(sin(dot(p, vec2(419.2, 371.9))) * 43758.5453123); 
    return r;
}

vec3 rand3_3(vec3 p) {
    p = fract(p * vec3(.1031, .1030, .0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

// Zentient: Psuedo Spatiotemporal Blue noise 
// https://www.shadertoy.com/view/wfjcz3
vec4 hash43(vec3 inp){
	uint pg = uint(viewSize.x * viewSize.x * inp.z) % 0xFFFFFFu + uint(viewSize.x * inp.y + inp.x);
	uint state = pg * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	uvec4 RGBA = uvec4(0xFFu) & uvec4(word) >> uvec4(0,8,16,24); 
	return vec4(RGBA) / float(0xFFu);
}

vec4 hash42(vec2 inp){
    uint pg = uint(viewSize.x * inp.y + inp.x);
	uint state = pg * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	uvec4 RGBA = uvec4(0xFFu) & uvec4(word) >> uvec4(0,8,16,24); 
	vec4 b = vec4(RGBA) / float(0xFFu);
    return b;
}

vec4 psuedoB(vec3 xyz){
    vec2 g = vec2(0.75487766624, 0.56984029099); 
    vec4 noise = fract(hash42(xyz.xy) + xyz.z * 0.618033989);
    vec4 bl = vec4(-4.5);
    for(int i; i < 9; i++){   
        vec2 offset = vec2(floor(float(i) / 3.0), i % 3) - 1.0;
        bl += fract(hash42(xyz.xy + offset) + xyz.z * 0.618033989);
    }
    bl = bl / 9.0;
    noise -= bl;
    noise = abs(1.0 - abs(noise));
    return fract(noise);
}


// iq: Texture - Better Filtering  
// https://www.shadertoy.com/view/XsfGDn
vec3 textureN( sampler2D sam, vec2 uv, float resolution ){
    uv = uv*resolution + 0.5;
    vec2 iuv = floor( uv );
    vec2 fuv = fract( uv );
    uv = iuv + fuv*fuv*(3.0-2.0*fuv);
    uv = (uv - 0.5)/resolution;
    return texture( sam, uv ).rgb;
}

vec3 textureN(sampler3D sam, vec3 uv, float resolution) {
    uv = uv * resolution + 0.5;
    vec3 iuv = floor(uv);
    vec3 fuv = fract(uv);
    uv = iuv + fuv * fuv * (3.0 - 2.0 * fuv);
    uv = (uv - 0.5) / resolution;
    return texture(sam, uv).rgb;
}

// From SEUS
float noise3DFrom2D(sampler2D noiseTexture, float repeatScale, vec3 position) {
    vec3 shiftedPos = position + vec3(0.5);
    vec3 voxelIndex = floor(shiftedPos);

    vec3 localFrac = shiftedPos - voxelIndex;
    vec2 uvLower = (voxelIndex.xy + voxelIndex.z * vec2(17.0)) + localFrac.xy;
    vec2 uvUpper = uvLower + vec2(17.0);

    float sampleLower = textureN(noiseTexture, (uvLower + vec2(0.5)) / repeatScale, repeatScale).x;
    float sampleUpper = textureN(noiseTexture, (uvUpper + vec2(0.5)) / repeatScale, repeatScale).x;

    return mix(sampleLower, sampleUpper, localFrac.z);
}


// Loka: 【shader】超级噪声库，附代码（fbm、Perlin、Simplex、Worley、Tiling、Curl等，很全很全）
// https://zhuanlan.zhihu.com/p/560229938
vec2 hash22(vec2 p){
    p = vec2( dot(p,vec2(127.1,311.7)),
              dot(p,vec2(269.5,183.3)));

    return -1.0 + 2.0 * fract(sin(p)*43758.5453123);
}

vec2 hash(vec2 p){
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+19.19);
    return -1. + 2.*fract((p3.xx+p3.yz)*p3.zy);
}

float simplex2d(vec2 p)
{
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;

    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - (i - (i.x + i.y) * K2);
    vec2 o = (a.x < a.y) ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;
    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash22(i)), dot(b, hash22(i + o)), dot(c, hash22(i + 1.0)));
    return dot(vec3(70.0, 70.0, 70.0), n);
}

vec3 random3(vec3 c) {
    float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
    vec3 r;
    r.z = fract(512.0*j);
    j *= .125;
    r.x = fract(512.0*j);
    j *= .125;
    r.y = fract(512.0*j);
    return r-0.5;
}

const float F3 =  0.3333333;
const float G3 =  0.1666667;

float simplex3d(vec3 p) {
    vec3 s = floor(p + dot(p, vec3(F3, F3, F3)));
    vec3 x = p - s + dot(s, vec3(G3, G3, G3));
    
    vec3 e = step(vec3(0,0,0), x - x.yzx);
    vec3 i1 = e*(1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy*(1.0 - e);
    
    vec3 x1 = x - i1 + G3;
    vec3 x2 = x - i2 + 2.0*G3;
    vec3 x3 = x - 1.0 + 3.0*G3;
    
    vec4 w, d;
    
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);
    
    w = max(0.6 - w, 0.0);
    
    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);
    
    w *= w;
    w *= w;
    d *= w;
    
    return dot(d, vec4(52.0, 52.0, 52.0, 52.0));
}



const float rotationArray[32] = float[32](
    0.0,
    3.883222,
    7.766444,
    11.649666,
    15.532888,
    19.41611,
    23.299332,
    27.182554,
    31.065776,
    34.948998,
    38.83222,
    42.715442,
    46.598664,
    50.481886,
    54.365108,
    58.24833,
    62.131552,
    66.014774,
    69.897996,
    73.781218,
    77.66444,
    81.547662,
    85.430884,
    89.314106,
    93.197328,
    97.08055,
    100.963772,
    104.846994,
    108.730216,
    112.613438,
    116.49666,
    120.379882
);

const float goldenRotationArray[32] = float[32](
    0.0,
    2.39996323,
    4.79992646,
    7.19988969,
    9.59985292,
    11.99981615,
    14.39977938,
    16.79974261,
    19.19970584,
    21.59966907,
    23.9996323,
    26.39959553,
    28.79955876,
    31.19952199,
    33.59948522,
    35.99944845,
    38.39941168,
    40.79937491,
    43.19933814,
    45.59930137,
    47.9992646,
    50.39922783,
    52.79919106,
    55.19915429,
    57.59911752,
    59.99908075,
    62.39904398,
    64.79900721,
    67.19897044,
    69.59893367,
    71.9988969,
    74.39886013
);
