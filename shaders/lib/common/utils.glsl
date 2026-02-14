#define max3(x, y, z) max(x, max(y, z))
#define min3(x, y, z) min(x, min(y, z))
#define max4(x, y, z, w) max(x, max3(y, z, w))
#define min4(x, y, z, w) min(x, min3(y, z, w))

vec2 rotate2D(vec2 point, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    mat2 rotationMatrix = mat2(c, -s, s, c);
    return rotationMatrix * point;
}

float fastExp(float x) {
    x = 1.0 + x / 256.0;
    x *= x; x *= x; x *= x; x *= x;
    x *= x; x *= x; x *= x; x *= x;
    return x;
}

vec2 fastExp(vec2 x) {
    return vec2(fastExp(x.x), fastExp(x.y));
}

vec3 fastExp(vec3 x) {
    return vec3(fastExp(x.x), fastExp(x.y), fastExp(x.z));
}

float fastPow(float x, float e) {
    int ipart = int(e);
    float fpart = e - float(ipart);
    float pow_int = 1.0;
    for(int i=0; i<ipart; i++) pow_int *= x;
    float log_x = (x - 1.0) - 0.5*(x - 1.0)*(x - 1.0);
    return pow_int * fastExp(fpart * log_x); 
}

vec2 fastPow(vec2 x, float e) {
    return vec2(fastPow(x.x, e), fastPow(x.y, e));
}

vec3 fastPow(vec3 x, float e) {
    return vec3(fastPow(x.x, e), fastPow(x.y, e), fastPow(x.z, e));
}

vec2 fastPow(vec2 x, vec2 e) {
    return vec2(fastPow(x.x, e.x), fastPow(x.y, e.y));
}

vec3 fastPow(vec3 x, vec3 e) {
    return vec3(fastPow(x.x, e.x), fastPow(x.y, e.y), fastPow(x.z, e.z));
}


float fastPow(float x, int e) {
    float result = 1.0;
    for (int i = 0; i < e; i++) {
        result *= x;
    }
    return result;
}

vec2 fastPow(vec2 x, int e) {
    return vec2(fastPow(x.x, e), fastPow(x.y, e));
}

vec3 fastPow(vec3 x, int e) {
    return vec3(fastPow(x.x, e), fastPow(x.y, e), fastPow(x.z, e));
}

float fastSin(float x) {
    x = mod(x + PI, _2PI) - PI;
    float x2 = x * x;
    return x * (1.0 - x2/6.0 * (1.0 - x2/20.0 * (1.0 - x2/42.0)));
}

vec2 fastSin(vec2 x) {
    return vec2(fastSin(x.x), fastSin(x.y));
}

vec3 fastSin(vec3 x) {
    return vec3(fastSin(x.x), fastSin(x.y), fastSin(x.z));
}

float fastCos(float x) {
    return fastSin(x + HALF_PI);
}

vec2 fastCos(vec2 x) {
    return fastSin(x + HALF_PI);
}

vec3 fastCos(vec3 x) {
    return fastSin(x + HALF_PI);
}

float pack2x8To16(float a, float b) {
    a = clamp(a, 0.0, 1.0);
    b = clamp(b, 0.0, 1.0);
    int ai = int(a * 255.0);
    int bi = int(b * 255.0);
    int Packed = (ai << 8) | bi;
    return float(Packed) / 65535.0;
}

float pack2x8To16(vec2 v) {
    float a = clamp(v.x, 0.0, 1.0);
    float b = clamp(v.y, 0.0, 1.0);
    int ai = int(a * 255.0);
    int bi = int(b * 255.0);
    int Packed = (ai << 8) | bi;
    return float(Packed) / 65535.0;
}

vec2 unpack16To2x8(float Packed) {
    int p = int(Packed * 65535.0);
    int a = (p >> 8) & 255;
    int b = p & 255;
    return vec2(float(a) / 255.0, float(b) / 255.0);
}

vec2 pack4x8To2x16(vec4 abcd) {
    vec4 clamped = clamp(abcd, 0.0, 1.0);
    ivec4 Packed = ivec4(clamped * 255.0);
    int combined1 = (Packed.x << 8) | Packed.y;
    int combined2 = (Packed.z << 8) | Packed.w;
    return vec2(float(combined1) / 65535.0, float(combined2) / 65535.0);
}

vec4 unpack2x16To4x8(vec2 Packed) {
    ivec2 combined = ivec2(Packed * 65535.0);
    ivec4 unpacked;
    unpacked.x = (combined.x >> 8) & 0xFF;
    unpacked.y = combined.x & 0xFF;
    unpacked.z = (combined.y >> 8) & 0xFF;
    unpacked.w = combined.y & 0xFF;
    return vec4(unpacked) / 255.0;
}

vec4 RGBA16ToRGBA16F(vec4 sampledColor) {
    uvec4 encoded = uvec4(
        (sampledColor * 65535.0) + vec4(0.5)) & 0xFFFFu; // 确保 16 位截断
    uint rgPacked = (encoded.r << 16) | encoded.g;
    uint baPacked = (encoded.b << 16) | encoded.a;

    vec2 rg = unpackHalf2x16(rgPacked);
    vec2 ba = unpackHalf2x16(baPacked);
    
    return vec4(rg, ba);
}

float saturate(float color) {
    return clamp(color, 0.0, 1.0);
}

vec2 saturate(vec2 color) {
    return clamp(color, 0.0, 1.0);
}

vec3 saturate(vec3 color) {
    return clamp(color, 0.0, 1.0);
}

vec4 saturate(vec4 color) {
    return clamp(color, 0.0, 1.0);
}




// 来自 滑稽菌 的 Lunar Drips
vec2 offsetCoord(vec2 coord, vec4 v_tcrange) {
    return mod(coord - v_tcrange.xy, v_tcrange.zw) + v_tcrange.xy;
}

// 来自 BSL
vec2 offsetCoord1(vec2 coord, vec4 vTexCoordAM){
    return fract(coord) * vTexCoordAM.pq + vTexCoordAM.st;
}

#ifndef VOXY
    vec2 GetParallaxCoord(vec2 offsetNormalized, vec2 uv, int textureResolution) {
        vec2 tileSizeNormalized = vec2(float(textureResolution)) / vec2(atlasSize);
        vec2 tileStart = floor(uv / tileSizeNormalized) * tileSizeNormalized;

        vec2 targetCoord = uv + offsetNormalized;
        vec2 relativeCoord = targetCoord - tileStart;
        vec2 wrappedRelativeCoord = mod(relativeCoord, tileSizeNormalized);

        return tileStart + wrappedRelativeCoord;
    }
#endif


bool outScreen(vec2 uv){
    if(uv.x <= 0.0
    || uv.x >= 1.0
    || uv.y <= 0.0
    || uv.y >= 1.0){
        return true;
    }else{
        return false;
    }
}

bool outScreen(vec2 uv, vec2 LB, vec2 RT){
    if(uv.x <= LB.x
    || uv.y <= LB.y
    || uv.x >= RT.x
    || uv.y >= RT.y){
        return true;
    }else{
        return false;
    }
}

bool outScreen(vec3 uv){
    if(uv.x <= 0.0
    || uv.x >= 1.0
    || uv.y <= 0.0
    || uv.y >= 1.0
    || uv.z <= 0.0
    || uv.z >= 1.0){
        return true;
    }else{
        return false;
    }
}

bool isOutsideRange(vec2 uv, vec2 minBound, vec2 maxBound) {
    return any(lessThan(uv, minBound)) || any(greaterThan(uv, maxBound));
}

bool isOutsideRange(vec3 uvw, vec3 minBound, vec3 maxBound) {
    return any(lessThan(uvw, minBound)) || any(greaterThan(uvw, maxBound));
}


float checkInRange(float value, float targetValue, float range) {
    if ((value > targetValue - range) && value < (targetValue + range)) {
        return 1.0;
    } else {
        return 0.0;
    }
}



float lerp(float a, float b, float f){
    return a + f * (b - a);
}

vec3 lerp(vec3 a, vec3 b, float f){
    return a + f * (b - a);
}




mat3 rotate3D(vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat3(
        oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.x * axis.z + axis.y * s,
        oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
        oc * axis.x * axis.z - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c
    );
}



vec2 RaySphereIntersection(vec3 rayOrigin, vec3 rayDir, vec3 sphereCenter, float sphereRadius) {
    rayOrigin -= sphereCenter;
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayOrigin, rayDir);
    float c = dot(rayOrigin, rayOrigin) - (sphereRadius * sphereRadius);
    float d = b * b - 4.0 * a * c;

    if (d < 0.0) {
        return vec2(-1.0);
    } else {
        d = sqrt(d);
        return vec2(-b - d, -b + d) / (2.0 * a);
    }
}

float intersectHorizontalPlane(vec3 origin, vec3 direction, float planeHeight) {
    return (planeHeight - origin.y) / direction.y;
}

vec2 intersectHorizontalAABB(vec3 origin, vec3 dir, vec2 boxY) {
    boxY = vec2(min(boxY.x, boxY.y), max(boxY.x, boxY.y));
    
    float t1 = (boxY.x - origin.y) / dir.y;
    float t2 = (boxY.y - origin.y) / dir.y;
    
    vec2 t = vec2(min(t1, t2), max(t1, t2));
    
    return t;
}

vec2 calculateStepDistances(float minDist, float maxDist, float distOther) {
    if (maxDist < 0.0 || (distOther < 0.0 && distOther < minDist)) {
        return vec2(0.0);
    }

    float firstStep = max(0.0, min(minDist, distOther));

    float totalStep = min(maxDist, max(distOther, 0.0)) - firstStep;

    return vec2(firstStep, totalStep);
}

vec2 rayBoxDst(vec3 boundsMin, vec3 boundsMax, vec3 rayOrigin, vec3 invRaydir) {
    vec3 t0 = (boundsMin - rayOrigin) * invRaydir;
    vec3 t1 = (boundsMax - rayOrigin) * invRaydir;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);

    float dstA = max(max(tmin.x, tmin.y), tmin.z);
    float dstB = min(min(tmax.x, tmax.y), tmax.z);

    float dstToBox = max(0.0, dstA);
    float dstInsideBox = max(0.0, dstB - dstToBox);

    return vec2(dstToBox, dstInsideBox);
}

float remap(float original_value, float original_min, float original_max, float new_min, float new_max){
    float result = new_min + ((( original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
    return result;
}

float remapSaturate(float original_value, float original_min, float original_max, float new_min, float new_max){
    float result = new_min + ((( original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
    return clamp(result, min(new_min, new_max), max(new_min, new_max));
}

float getHeightFractionForPoint(float height, vec2 minMax){
    float height_fraction = remapSaturate(height, minMax.x, minMax.y, 0.0, 1.0);
    return height_fraction;
}

float smoothRemap(float y, float lowerBound, float upperBound, float transitionRange_L, float transitionRange_U,  float smoothness) {
    // float lower = min(lowerBound, upperBound);
    // float upper = max(lowerBound, upperBound);

    float middleLower = lowerBound + transitionRange_L;
    float middleUpper = upperBound - transitionRange_U;

    float t = 0.0;

    if (y <= middleLower) {
        t = smoothstep(lowerBound, middleLower, y);
    } else if (y >= middleUpper) {
        t = 1.0 - smoothstep(middleUpper, upperBound, y);
    } else {
        t = 1.0;
    }

    return pow(t, smoothness);
}



vec2 floorUV(vec2 uv){
    uv *= viewSize;
    uv = floor(uv) + 0.5;
    uv *= invViewSize;
    return uv;
}



float hgPhase(float cosTheta, float g){
    float numer = 1.0f - g * g;
    float denom = 1.0f + g * g + 2.0f * g * cosTheta;
    return numer / (4.0f * PI * denom * sqrt(denom));
}

float hgPhase1(float cos_angle, float g){
    float g2 = g * g;
    return ((1.0 - g2) / pow((1.0 + g2 - 2.0 * g * cos_angle), 1.5)) / (4.0 * PI);
}

