#define BLACK vec3(0.0)
#define GAMMA 2.2   // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
#define _HIGH 1.0   // [0.0 1.0]

#define HALF_PI 1.5707963267948966
#define PI 3.14159265359
#define _2PI 6.28318530718
#define _4PI 12.5663706144

#define GOLDEN_RATIO 0.61803398875
#define GOLDEN_ANGLE 2.39996323

#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float2x2 mat2
#define float3x3 mat3
#define float4x4 mat4
#define frac fract
#define atan2 atan
#define rsqrt inversesqrt

#define NOON_DURATION 40.0          // [5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define NIGHT_DURATION 30.0         // [5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]

#define NOON_DURATION_SLOW 3.0      // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0]
#define NIGHT_DURATION_SLOW 10.0     // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0]

const float wetnessHalflife = 600.0;
const float drynessHalflife = 10.0;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
const int noiseTextureResolution = 64;






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define ID_SCALE        255.0
#define PLANTS_SHORT    1.0
#define PLANTS_TALL_L   2.0
#define PLANTS_TALL_U   3.0
#define LEAVES          4.0
#define PLANTS_OTHER    5.0

#define WATER           11.0
#define ICE             12.0

#define GLOWING_BLOCK   21.0

#define NO_ANISO        31.0

#define ENTITIES        51.0
#define LIGHTNING_BOLT  52.0
#define FIREWORK_ROCKET 53.0
#define BLOCK           61.0
#define HAND            71.0

#define DH_TERRAIN      101.0
#define DH_LEAVES       102.0
#define DH_WOOD         103.0







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define WAVING_PLANTS
#define WAVING_RATE 1.0                 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define PLANTS_SHORT_AMPLITUDE 1.0    // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define PLANTS_TALL_AMPLITUDE 0.4     // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define LEAVES_AMPLITUDE 0.4          // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define WAVING_NOISE_SCALE 1.0       // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 4.5 5.0]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// #define PARALLAX_MAPPING
#define PARALLAX_TYPE 0             // [0 1]
#define PARALLAX_SAMPPLES 30.0      // [15.0 30.0 45.0 60.0 75.0 90.0 120.0 150.0 180.0]
#define PARALLAX_HEIGHT 0.25        // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define PARALLAX_DISTANCE 30.0      // [5.0 10.0 15.0 20.0 25.0 30.0 40.0 50.0 60.0]
#define PARALLAX_SHADOW
#define PARALLAX_SHADOW_SAMPPLES 8.0   // [4.0 8.0 12.0 16.0 20.0 24.0 28.0 32.0]
#define PARALLAX_SHADOW_SOFTENING 1.0   // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 5.0]
#define PARALLAX_NORMAL_MIX_WEIGHT 0.5   // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define PARALLAX_FORCE_NORMAL_VERTICAL

#define PBR_REFLECTIVITY
// #define USE_OLD_PBR
#define SSS_INTENSITY 5.0           // [0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define EMISSIVENESS_BRIGHTNESS 1.0 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define MIRROR_INTENSITY 0.5        // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.25 1.5 1.75 2.0]
#define PBR_REFLECTION_DIR_COUNT 1  // [1 2 3 4 5 6 8 10 12 14 16 18 20]
// #define PBR_REFLECTION_BLUR
#define TRANSLUCENT_ROUGHNESS 0.75  // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95]
#define TRANSLUCENT_F0 0.75         // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95]
// #define TRANSLUCENT_USE_REASOURCESPACK_PBR



#define RAINY_GROUND_WET_ENABLE
#define RAINY_GROUND_WET_NOISE
#define WET_GROUND_SMOOTHNESS 0.95   // [0.5 0.6 0.7 0.8 0.9 0.95 1.0]
#define WET_GROUND_F0 0.02           // [0.01 0.02 0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]

#define RIPPLE
#define RIPPLE_DISTANCE 20.0        // [10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define RIPPLE_MAX_RADIUS 1         // [1 2 3]
#define RIPPLE_UV_SCALE 3.0         // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define RIPPLE_TIME_SPEED 1.25       // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0]
#define RIPPLE_WAVE_FREQ 25.0
#define RIPPLE_RING_INNER -0.6
#define RIPPLE_RING_OUTER -0.3
#define RIPPLE_NORMAL_STRENGTH 0.05 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.15 0.2]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define TAA_JITTER_AMOUNT 1.0       // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define TAA_VARIANCE_CLIP_GAMMA 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
#define SHARPENING_FACTOR 0.8       // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
// #define TAA_CUSTOM_BLEND_FACTOR
#define TAA_BLEND_FACTOR 0.03       // [0.01 0.015 0.02 0.025 0.03 0.035 0.04 0.045 0.05 0.055 0.06 0.065 0.07 0.075 0.08 0.085 0.09 0.095 0.1]


#define ANISOTROPIC_FILTERING
#define ANISOTROPIC_FILTERING_MODE 0        // [0 1]
#define ANISOTROPIC_FILTERING_QUALITY 1.0   // [1.0 2.0 4.0 8.0 16.0]

#define FSR_RCAS
#define RCAS_LIMIT (0.25 - (1.0 / 16.0))
#define RCAS_ENABLE_NOISE_SUPPRESSION
#define RCAS_SHARPNESS 0.92     // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.92 0.95 1.0]





//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define MIE_G 0.75              // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define MIE_STRENGTHNESS 1.0    // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0 4.25 4.5 4.75 5.0]

const float earth_r = 6371000.0;
const float atmosphere_h = 80000.0;

#define CAMERA_HEIGHT 150.0 // [0.0 150.0 300.0 450.0 600.0 750.0 900.0 1050.0 1200.0 1350.0 1500.0 1650.0 1800.0 1950.0 2100.0 2250.0 2400.0]
vec3 camera = vec3(cameraPosition.x, cameraPosition.y - 64.0 + CAMERA_HEIGHT, cameraPosition.z);
vec3 earthPos = vec3(0.0, earth_r + camera.y, 0.0);

const float ozoneCenter = 25000.0;
const float ozoneWidth = 15000.0;

const vec3 RayleighSigma = vec3(5.802, 13.558, 33.1) * 1e-6;
const vec3 MieSigma = vec3(3.996) * 1e-6;
const vec3 MieAbsorptionSigma = vec3(4.4) * 1e-6;
const vec3 OzoneAbsorptionSigma = vec3(0.650, 1.881, 0.085) * 1e-6;

#define Information CHUN_v2_2025_12_BY_ZY     //     [CHUN_v2_2025_12_BY_ZY]

const float H_R = 8500.0;
const float H_M = 1200.0;

const ivec4 T1_I = ivec4(0, 511 - 64, 127, 511);
const ivec4 T1_O = ivec4(0, 0, 127, 63);
const ivec4 MS_I = ivec4(127 + 10, 511 - 64, 127 + 10 + 64, 511);
const ivec4 MS_O = ivec4(0, 0, 63, 63);

const ivec2 sunColorUV = ivec2(1, 256 + 10);
const ivec2 skyColorUV = ivec2(1 + 10, 256 + 10);
const ivec2 averageLumUV = ivec2(0, 0);


#define ATMOSPHERE_SCATTERING_SAMPLES 16    // [4 8 12 16 20 24 32 48 64 86 128]






#define SKY_BASE_COLOR_BRIGHTNESS 2.5   // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0 4.25 4.5 4.75 5.0]
#define SKY_BASE_COLOR_BRIGHTNESS_N 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0 4.25 4.5 4.75 5.0]

#define INCOMING_LIGHT_RED 1.0      // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define INCOMING_LIGHT_GREEN 1.0    // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define INCOMING_LIGHT_BLUE 1.0     // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define INCOMING_LIGHT_ALPHA 8.0    // [2.0 3.0 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 10.5 11.0 11.5 12.0 13.0 14.0 15.0]
const vec3 IncomingLight = vec3(INCOMING_LIGHT_RED, INCOMING_LIGHT_GREEN, INCOMING_LIGHT_BLUE) * INCOMING_LIGHT_ALPHA;

#define INCOMING_LIGHT_N_RED 0.80   // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define INCOMING_LIGHT_N_GREEN 0.90 // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define INCOMING_LIGHT_N_BLUE 1.0   // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0 1.1 1.2]
#define INCOMING_LIGHT_N_ALPHA 0.125 // [0.0125 0.025 0.0375 0.05 0.0625 0.075 0.0875 0.1 0.2 0.3 0.4 0.5]
const vec3 IncomingLight_N = vec3(INCOMING_LIGHT_N_RED, INCOMING_LIGHT_N_GREEN, INCOMING_LIGHT_N_BLUE) * INCOMING_LIGHT_N_ALPHA;






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define ATMOSPHERIC_SCATTERING_FOG
#define ATMOSPHERIC_SCATTERING_FOG_DENSITY 30.0 // [10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0 150.0 160.0 170.0 180.0 190.0 200.0]
#define VOLUME_LIGHT_SAMPLES 1.0    // [1.0 2.0 3.0 5.0 7.0 9.0 11.0 13.0 15.0]






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define SUN_RADIUS 0.00015      // [0.00005 0.0001 0.00015 0.0002 0.00025 0.0003 0.00035 0.0004 0.00045 0.0005]
#define SUN_BRIGHTNESS 50.0     // [10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0]
#define MOON_BRIGHTNESS 3.5     // [1.5 2.5 3.5 4.5 5.5 6.5 7.5 8.5 9.5 10.5]
#define STARS
#define STARS_DENSITY 30.0      // [10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0]
#define STARS_SIZE 0.05        // [0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2]
#define STARS_BRIGHTNESS 1.0    // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define VOLUMETRIC_CLOUDS
#define CREPUSCULAR_LIGHT

#define VOLUMETRIC_CLOUDS_MIN_HEIGHT 650.0  // [350.0 500.0 650.0 800.0 950.0 1100.0 1250.0 1400.0]
const float cloudHeightMin = VOLUMETRIC_CLOUDS_MIN_HEIGHT + CAMERA_HEIGHT;
#define CLOUD_THICKNESS 800.0               // [50.0 100.0 200.0 300.0 400.0 500.0 600.0 700.0 800.0 900.0 1000.0]
const vec2 cloudHeight = vec2(cloudHeightMin, cloudHeightMin + CLOUD_THICKNESS);

#define VOLUMETRIC_CLOUDS_MAX_SAMPLES 18    // [3 6 9 12 15 18 21 24 27 30]
#define VOLUMETRIC_CLOUDS_MIN_SAMPLES 9     // [1 3 6 9 12 15 18 21 24 27 30]
#define CLOUD_SMALL_STEP 2.0            // [2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]

#define VOLUME_CLOUD_NOISE_SEED 0.6         // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]
#define CLOUD_COVERAGE 0.45      // [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9]
#define CLOUD_RAIN_ADD_COVERAGE 0.3     // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9]

#define CLOUD_SIGMA_S 0.07    // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15]
#define CLOUD_SIGMA_A 0.01    // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
const float cloudSigmaE = CLOUD_SIGMA_S + CLOUD_SIGMA_A;

#define CLOUD_INSCATTER_POWDER 1.25 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0]

#define CLOUD_BRIGHTNESS_DIRECT 1.4     // [0.2 0.4 0.6 0.8 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0]
#define CLOUD_BRIGHTNESS_AMBIENT 0.3    // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

#define CLOUD_FADE_DISTANCE 9000.0  // [3000.0 4500.0 6000.0 7500.0 9000.0 12000.0 15000.0 18000.0]

const float CLOUD_LARGE_STEP = 280.0;  // 大步幅
// const float CLOUD_SMALL_STEP = 70.0;   // 小步幅
const int CLOUD_MAX_STEPS = 80;      // 最大步进次数
const int CLOUD_EMPTY_STEPS = 4;      // 连续空样本阈值
const float CLOUD_MAX_DISTANCE = 40000.0;  // 最大步进距离






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
const float fog_a = 0.12;
const float fog_b = 0.015;

const float fog_startDis = 0.0;
const float fog_startHeight = 0.0;

#define VOLUMETRIC_FOG

#define FOG_NEAR_UNIT 30.0    // [5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define FOG_FAR_UNIT 120.0    // [30.0 60.0 90.0 120.0 150.0 180.0 210.0 240.0]

#define FOG_SIGMA_S 0.03    // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
#define FOG_SIGMA_A 0.01    // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
const float fogSigmaE = FOG_SIGMA_S + FOG_SIGMA_A;

#define FOG_DIRECT_INTENSITY 10.0        // [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0]
#define FOG_AMBIENT_INTENSITY 4.0        // [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0]

#define FOG_REF_HEIGHT 64.0     // [-64.0 -32.0 0.0 16.0 32.0 48.0 64.0 80.0 96.0 112.0 128.0 144.0 160.0 176.0 192.0 208.0 224.0 240.0 256.0 272.0 288.0 304.0 320.0]
#define FOG_THICKNESS 200.0     // [0.0 20.0 40.0 60.0 80.0 100.0 120.0 140.0 160.0 180.0 200.0 220.0 240.0 260.0 280.0 300.0 320.0 340.0 360.0 380.0 400.0]
const vec2 fogHeight = vec2(FOG_REF_HEIGHT - FOG_THICKNESS * 0.5, FOG_REF_HEIGHT + FOG_THICKNESS * 0.5) - 64.0 + CAMERA_HEIGHT;

#define FOG_BASE_COVERAGE_RAIN 0.65         // [0.0 0.1 0.2 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define FOG_BASE_COVERAGE_NIGHT 0.65        // [0.0 0.1 0.2 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define FOG_BASE_COVERAGE_SUNRISESET 0.65        // [0.0 0.1 0.2 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define FOG_BASE_COVERAGE_NOON 0.05        // [0.0 0.1 0.2 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

#define FOG_ADD_COVERAGE_RAIN 0.35        // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.7 0.8 0.9 1.0]
#define FOG_ADD_COVERAGE_NIGHT 0.2        // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.7 0.8 0.9 1.0]
#define FOG_ADD_COVERAGE_SUNRISESET 0.2        // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.7 0.8 0.9 1.0]
#define FOG_ADD_COVERAGE_NOON 0.0        // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.7 0.8 0.9 1.0]






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define ARTIFICIAL_LIGHT_FALLOFF 2.0    // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define SKY_LIGHT_FALLOFF 2.0           // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define SUN_SKY_BLEND 0.97          // [0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]

#define HELD_BLOCK_DYNAMIC_LIGHT
#define HELD_BLOCK_NORMAL_AFFECT
#define DYNAMIC_LIGHT_DISTANCE 10.0

#define GLOWING_BRIGHTNESS 2.0      // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define SKY_LIGHT_BRIGHTNESS 4.0    // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0]
#define ARTIFICIAL_COLOR_RED 0.9    // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define ARTIFICIAL_COLOR_GREEN 0.32 // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define ARTIFICIAL_COLOR_BLUE 0.06  // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define ARTIFICIAL_COLOR_ALPHA 1.0  // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
const vec3 artificial_color = vec3(ARTIFICIAL_COLOR_RED, ARTIFICIAL_COLOR_GREEN, ARTIFICIAL_COLOR_BLUE) * ARTIFICIAL_COLOR_ALPHA;

#define NIGHT_VISION_BRIGHTNESS 0.5 // [0.1 0.3 0.5 0.7 0.9 1.1 1.3 1.5 1.7 1.9]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// #define DISABLE_LEAKAGE_REPAIR
// #define SHADOWMAP_EXCLUDE_ENTITIES

const float sunPathRotation = -30.0;    // [-80.0 -70.0 -60.0 -50.0 -40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0]
const bool shadowHardwareFiltering = true;

#define SHADOW_BIAS 0.85    // [0.80 0.85 0.90 0.95 1.00]
const int shadowMapResolution = 2048;   // [1024 2048 3072 4096 5120 6144 7168 8192]
const float shadowDistance = 160.0;    // [40.0 80.0 120.0 160.0 200.0 240.0 280.0 320.0 360.0]
// const float shadowDistanceRenderMul = 1.0;
#define BLOCKER_SEARCH_SAMPLES 3.0 // [3.0 5.0 7.0 9.0 12.0 15.0 18.0 21.0 24.0 27.0 30.0 33.0 36.0]
#define SHADOW_SOFTNESS 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0]
#define SHADOW_SAMPLES 6.0    // [3.0 5.0 6.0 7.0 8.0 9.0 12.0 15.0 18.0 21.0 24.0 27.0 30.0 33.0 36.0]
#define COLOR_SHADOW_SAMPLES 5.0 // [3.0 5.0 7.0 9.0 12.0 15.0 18.0 21.0 24.0 27.0 30.0 33.0 36.0]
#define SCREEN_SPACE_SHADOW_SAMPLES 5.0 // [3.0 5.0 7.0 9.0 12.0 15.0 18.0 21.0 24.0 27.0 30.0 33.0 36.0]
#define SSS_RT_SHADOW_VISIBILITY 0.0    // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

float shadowMapScale = (120.0 / shadowDistance) * (shadowMapResolution / 2048.0);

#define DIRECT_LUMINANCE 1.75 // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0]




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define RSM_ENABLED
#define RSM_NORMAL_WEIGHT_TYPE 0     // [0 1]
#define RSM_DIST_WEIGHT_TYPE 0  // [0 1]
#define RSM_BRIGHTNESS 1.0      // [0.025 0.05 0.075 0.1 0.125 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0]
#define RSM_SEARCH_RADIUS 240   // [40 80 120 160 200 240 280 320 360]
#define RSM_MAX_SAMPLES 12      // [4 8 12 16 20 24 28 32 36]  
#define RSM_MIN_SAMPLES 4       // [4 8 12 16 20 24 28 32 36]  
#define RSM_LEAK_FIX


#define DENOISER_RADIUS 12.0     // [2.0 4.0 6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0]
#define DENOISER_QUALITY 12.0    // [2.0 4.0 6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0]




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
const float ambientOcclusionLevel = 0.0;  // [0.0 0.05 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define AO_ENABLED

#define AO_TYPE GTAO            // [SSAO GTAO]
#define AO_MULTI_BOUNCE

#define SSAO_SEARCH_RADIUS 3.0  // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define SSAO_MAX_SAMPLES 12   // [4 8 12 16 20 24 28 32 36]
#define SSAO_MIN_SAMPLES 4    // [4 8 12 16 20 24 28 32 36]
#define SSAO_INTENSITY 1.0      // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 5.0]

#define GTAO_SLICE_COUNT 2      // [2 3 4 5 6 7 8 9 10]
#define GTAO_DIRECTION_SAMPLE_COUNT 3 // [1 2 3 4 5 6 7 8 9 10]
#define GTAO_SEARCH_RADIUS 1.5  // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define GTAO_INTENSITY 1.0      // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 5.0]





//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define COLOR_UI_SCALE 4.0

#define WAVE_TYPE 1                    // [0 1]
#define WAVE_SPEED 1.5      // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0]
#define WAVE_FREQUENCY 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0]
#define WAVE_HEIGHT 0.2     // [0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WAVE_PARALLAX
#define WAVE_PARALLAX_HEIGHT 2.0    // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0 4.5 5.0]
#define WAVE_PARALLAX_MIN_SAMPLES 5.0   // [5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define WAVE_PARALLAX_MAX_SAMPLES 15.0  // [5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define WAVE_PARALLAX_ITERATIONS 10     // [0 5 10 15 20 25 30 35 40 45 50]
#define WAVE_NORMAL_ITERATIONS 20       // [0 5 10 15 20 25 30 35 40 45 50]

#define WATER_FOG_COLOR_RED 0.2     // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define WATER_FOG_COLOR_GREEN 0.75   // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define WATER_FOG_COLOR_BLUE 0.9    // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define WATER_FOG_COLOR_ALPHA 1.0   // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
const vec3 waterFogColor = vec3(WATER_FOG_COLOR_RED, WATER_FOG_COLOR_GREEN, WATER_FOG_COLOR_BLUE) * WATER_FOG_COLOR_ALPHA;
#define WATER_MIST_VISIBILITY 12.0  // [2.0 4.0 6.0 8.0 10.0 12.0 16.0 20.0 24.0 28.0 32.0 36.0]
#define WATER_FOG_TRANSMIT 0.5      // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.5 2.0]



#define UNDERWATER_FOG
#define UNDERWATER_FOG_MIST 50.0    // [10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0]

#define UNDERWATER_FOG_SAMPLES 4.0  // [2.0 4.0 6.0 8.0 10.0 12.0 16.0 20.0 24.0 28.0 32.0]
#define UNDERWATER_FOG_DIST 30.0    // [10.0 15.0 20.0 25.0 30.0 35.0 40.0]
#define UNDERWATER_FOG_LIGHT_BRI 0.7   // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#define UNDERWATER_FOG_BRI 0.35     // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]



#define UNDERWATER_ADD_BLOOM 0.12  // [0.005 0.0075 0.01 0.0125 0.015 0.0175 0.02 0.0225 0.025 0.0275 0.03 0.035 0.04 0.045 0.05 0.055 0.06 0.065 0.07 0.075 0.08]
#define UNDERWATER_CANTRAST 1.5     // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define UNDERWATER_BRI 1.5          // [0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.25 2.5 2.75 3.0 3.25 3.5 3.75 4.0]



#define WATER_REFRACTION
#define WAVE_REFRACTION_INTENSITY 1.0   // [0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0]
#define WATER_REFRAT_IOR 1.2        // [1.0 1.1 1.2 1.3 1.33 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define WATER_REFLECTION
#define UNDERWATER_REFLECTION
#define REFLECTION_STEP_SIZE 0.25   // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 1.0 2.0 3.0]
#define REFLECTION_SAMPLES 20       // [10 15 20 25 30 35 40 45 50]
#define REFLECTION_STEP_GROWTH_BASE 1.4   // [1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 4.0 5.0]
#define REFLECTION_FRESNAL_POWER 5.0    // [0.1 1.0 2.0 3.0 4.0 5.0]
#define WATER_F0 0.02               // [0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define WATER_REFLECT_HIGH_LIGHT
#define WATER_REFLECT_HIGH_LIGHT_INTENSITY 1.0  // [0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 3.5 4.0 5.0]



#define TRANSLUCENT_SHADOW
#define TRANSLUCENT_SHADOW_SOFTNESS 0.5     // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define TRANSLUCENT_SHADOW_QUALITY 5.0      // [2.0 5.0 8.0 12.0 16.0 20.0]
// #define TRANSLUCENT_REFRACTION
#define TRANSLUCENT_REFRACTION_INTENSITY 1.0   // [0.5 0.75 1.0 1.25 1.5 1.75 2.0]






#define CAUSTICS
#define CAUSTICS_FREQ 0.03          // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.09 0.11 0.13 0.15 0.17 0.19]
#define CAUSTICS_SPEED 0.13         // [0.01 0.03 0.05 0.06 0.07 0.09 0.11 0.13 0.15 0.17 0.19]
#define CAUSTICS_POWER 3.0          // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define CAUSTICS_BRI_MIN 1.0        // [0.2 0.4 0.6 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0]
#define CAUSTICS_BRI_MAX 4.0        // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0 4.2 4.4 4.6 4.8 5.0]
#define CAUSTICS_CHROMA_SHIFT 0.05  // [0.0 0.0125 0.025 0.0375 0.05 0.0625 0.075 0.0875 0.1]
#define CAUSTICS_DISPERSION 0.35    // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define BLOOM
#define BLOOM_MODE 0    // [0 1 2]
#define BLOOM_LAYERS 7  // [1 2 3 4 5 6 7]

#define BLOOM_AMOUNT 0.02     // [0.0025 0.005 0.00625 0.0075 0.00875 0.01 0.0125 0.015 0.0175 0.02 0.0225 0.025 0.0275 0.03]
#define RAIN_ADDITIONAL_BLOOM 0.04 // [0.0025 0.005 0.0075 0.01 0.0125 0.015 0.0175 0.02 0.0225 0.025 0.0275 0.03]
#define NIGHT_ADDITIONAL_BLOOM 0.05 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1]
#define NETHER_ADDITIONAL_BLOOM 0.25 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
#define END_ADDITIONAL_BLOOM 0.1 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]










//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define EXPOSURE
#define EXPOSURE_MODE 1             // [0 1]
#define TARGET_BRIGHTNESS 0.11      // [0.06 0.07 0.08 0.09 0.1 0.11 0.012 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2]
#define LIGHT_SENSITIVITY 1.5       // [0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0]
#define EXPOSURE_DELTA 0.55         // [0.1 0.2 0.3 0.4 0.5 0.55 0.6 0.7 0.8 0.9 1.0]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define FILTER_SLOPE_RED 1.0    // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define FILTER_SLOPE_GREEN 1.0  // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define FILTER_SLOPE_BLUE 1.0   // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define FILTER_SLOPE_ALPHA 1.0  // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0]
const vec3 filterSlope = vec3(FILTER_SLOPE_RED, FILTER_SLOPE_GREEN, FILTER_SLOPE_BLUE) * FILTER_SLOPE_ALPHA;
#define FILTER_WHITE 0.0        // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
const vec3 filterOffset = vec3(1.0, 1.0, 1.0) * FILTER_WHITE;
#define FILTER_CONTRAST 1.0     // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0]
const vec3 filterPower = vec3(1.0, 1.0, 1.0) * FILTER_CONTRAST;
#define FLITER_SATURATE 1.0     // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define TONE_MAPPING ACESFull        // [ACESFull ACES AgX Hejl Lottes Hable Neutral Uchimura]

#define ACES_FULL_ADDITIVE 1.5
#define ACES_ADDITIVE 0.75
#define AGX_ADDITIVE 2.25
#define HEJL_ADDITIVE 0.75
#define LOTTES_ADDITIVE 0.75
#define HABLE_ADDITIVE 1.8
#define NEUTRAL_ADDITIVE 1.0
#define UCHIMURA_ADDITIVE 0.85

#define AGX_EV 12.0     // [10.0 10.25 10.5 10.75 11.0 11.25 11.5 11.75 12.0 12.25 12.5 12.75 13.0 13.25 13.5 13.75 14.0 14.25 14.5 14.75 15.0]

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// #define LETTER_BOX
#define LETTER_BOX_SIZE 0.1 // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45]

#define VIGNETTE
#define VIGNETTE_SCALE 1.7      // [0.9 1.1 1.3 1.5 1.7 1.9 2.1 2.3 2.5 2.7 2.9]
#define VIGNETTE_OFFSET -0.65   // [-0.9 -0.8 -0.7 -0.65 -0.6 -0.5 -0.4 -0.3 -0.2 -0.1]
#define VIGNETTE_POWER 1.5      // [0.5 0.7 0.9 1.1 1.3 1.5 1.7 1.9 2.1 2.3 2.5]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// #define MOTION_BLUR

#define MOTIONBLUR_THRESHOLD 0.005
#define MOTIONBLUR_MAX 1.0         // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define MOTIONBLUR_STRENGTH 0.9     // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define MOTIONBLUR_SAMPLE 5         // [1 2 3 4 5 6 7 8 9 10]







//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// #define DEPTH_OF_FIELD

const float centerDepthHalflife = 0.5; // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

#define DOF_BOKEH_RADIUS 8.0    // [2.0 4.0 6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0]
#define DOF_BLUR_WEIGHT_MODE 0  // [0 1]
#define DOF_FOCUSRANGE_DIST_FAC 11.4514 // [0.0 2.0 4.0 6.0 8.0 10.0 12.0 14.0 16.0 18.0 20.0]
#define DOF_FOCUSRANGE_BASE_DIST 1.14514 // [0.1 1.0 2.0 4.0 8.0 16.0 32.0 64.0 128.0 256.0]






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define END_COLOR_RED 0.25    // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define END_COLOR_GREEN 0.1   // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define END_COLOR_BLUE 0.9    // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define END_COLOR_INTENSITY 1.0  // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
const vec3 endColor = vec3(END_COLOR_RED, END_COLOR_GREEN, END_COLOR_BLUE) * END_COLOR_INTENSITY;

#define NETHER_COLOR_RED 0.9     // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define NETHER_COLOR_GREEN 0.25  // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define NETHER_COLOR_BLUE 0.06   // [0.0 0.025 0.05 0.075 0.1 0.125 0.15 0.175 0.2 0.225 0.25 0.275 0.3 0.325 0.35 0.375 0.4 0.425 0.45 0.475 0.5 0.525 0.55 0.575 0.6 0.625 0.65 0.675 0.7 0.725 0.75 0.775 0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#define NETHER_COLOR_INTENSITY 1.0  // [0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]
const vec3 netherColor = vec3(NETHER_COLOR_RED, NETHER_COLOR_GREEN, NETHER_COLOR_BLUE) * NETHER_COLOR_INTENSITY;
