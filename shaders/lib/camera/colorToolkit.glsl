vec4 toLinearR(vec4 color) {
    return vec4(pow(color.rgb, vec3(GAMMA)), color.a);
}

vec3 toLinearR(vec3 color) {
    return pow(color, vec3(GAMMA));
}

vec2 toLinearR(vec2 color) {
    return pow(color, vec2(GAMMA));
}

float toLinearR(float color) {
    return pow(color, float(GAMMA));
}

void toLinear(inout vec4 color) {
    color.rgb = pow(color.rgb, vec3(GAMMA));
}

void toLinear(inout vec3 color) {
    color = pow(color, vec3(GAMMA));
}

void toLinear(inout vec2 color) {
    color = pow(color, vec2(GAMMA));
}

vec4 toGammaR(vec4 color) {
    return vec4(pow(color.rgb, vec3(1.0 / GAMMA)), color.a);
}

vec3 toGammaR(vec3 color) {
    return pow(color, vec3(1.0 / GAMMA));
}

void toGamma(inout vec4 color) {
    color.rgb = pow(color.rgb, vec3(1.0 / GAMMA));
}

void toGamma(inout vec3 color) {
    color = pow(color, vec3(1.0 / GAMMA));
}

vec4 textureTL(sampler2D tex, vec2 coord){
    return toLinearR(texture(tex, coord));
}

vec4 textureSa(sampler2D tex, vec2 coord){
    return texture(tex, clamp(coord, vec2(0.0), vec2(1.0)));
}

vec4 textureORB(sampler2D tex, vec2 coord){
    if(coord.x < 0.0 || coord.y < 0.0 || coord.x > 1.0 || coord.y > 1.0) return vec4(BLACK, 1.0);
    return texture(tex, clamp(coord, vec2(0.0), vec2(1.0)));
}



float getLuminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float getLuminance(vec4 color) {
	return dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
}

float getLuminance(sampler2D text, vec2 coord) {
	return dot(texture(text, coord).rgb, vec3(0.2126, 0.7152, 0.0722));
}

float getLuminance(sampler2D text, vec2 coord, float lod) {
	return dot(textureLod(text, coord, lod).rgb, vec3(0.2126, 0.7152, 0.0722));
}

float getLuminanceW(vec3 color) {
	return dot(vec3(0.33333333), color);
}

float getLuminanceW(vec4 color) {
	return dot(vec3(0.33333333), color.rgb);
}

float getLuminanceW(sampler2D text, vec2 coord) {
	return dot(vec3(0.33333333), texture(text, coord).rgb);
}



vec3 RGB2YCoCgR(vec3 rgbColor){
    vec3 YCoCgRColor;

    YCoCgRColor.y = rgbColor.r - rgbColor.b;
    float temp = rgbColor.b + YCoCgRColor.y / 2;
    YCoCgRColor.z = rgbColor.g - temp;
    YCoCgRColor.x = temp + YCoCgRColor.z / 2;

    return YCoCgRColor;
}

vec3 YCoCgR2RGB(vec3 YCoCgRColor){
    vec3 rgbColor;

    float temp = YCoCgRColor.x - YCoCgRColor.z / 2;
    rgbColor.g = YCoCgRColor.z + temp;
    rgbColor.b = temp - YCoCgRColor.y / 2;
    rgbColor.r = rgbColor.b + YCoCgRColor.y;

    return rgbColor;
}



const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
    1.6605, -0.1246, -0.0182,
    -0.5876, 1.1329, -0.1006,
    -0.0728, -0.0083, 1.1187
);

const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
    0.6274, 0.0691, 0.0164,
    0.3293, 0.9195, 0.0880,
    0.0433, 0.0113, 0.8956
);