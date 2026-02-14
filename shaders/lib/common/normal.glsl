#ifndef COMMON_NORMAL_GLSL
#define COMMON_NORMAL_GLSL

//A Survey of Efficient Representations for Independent Unit Vectors
//Journal of Computer Graphics Techniques Vol. 3, No. 2, 2014 
vec2 OctWrap( vec2 v ){
    return ( 1.0 - abs( v.yx ) ) * (step(vec2(0.0), v.xy) * 2.0 - 1.0);
}

vec2 normalEncode(vec3 n){
    n /= ( abs( n.x ) + abs( n.y ) + abs( n.z ) );
    n.xy = n.z >= 0.0 ? n.xy : OctWrap( n.xy );
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}

vec3 normalDecode(vec2 encN) {
    encN = encN * 2.0 - 1.0;
    vec3 n;
    n.z = 1.0 - abs( encN.x ) - abs( encN.y );
    n.xy = n.z >= 0.0 ? encN.xy : OctWrap( encN.xy );
    n = normalize( n );
    return n;
}

float packNormal(vec3 normal){
    ivec3 q = ivec3(round(normal * 500.0));

    q = clamp(q, ivec3(-512), ivec3(511));

    uint xBits = uint(q.x & 0x3FF);
    uint yBits = uint(q.y & 0x3FF);
    uint zBits = uint(q.z & 0x3FF);

    uint packedN = (xBits << 22) | (yBits << 12) | (zBits << 2);

    return uintBitsToFloat(packedN);
}

vec3 unpackNormal(float packedFloat){
    uint packedN = floatBitsToUint(packedFloat);

    int x = int(packedN        ) >> 22;
    int y = int(packedN << 10 ) >> 22;
    int z = int(packedN << 20 ) >> 22;

    vec3 normal;
    normal.x = float(x) * 0.002;
    normal.y = float(y) * 0.002;
    normal.z = float(z) * 0.002;

    return normal;
}

#if defined FSH && !defined GBF && !defined SHD
vec3 getNormal(vec2 uv){
    return normalize(normalDecode(texture(colortex5, uv).rg));
}


vec3 getNormalH(vec2 uv){
    return normalize(normalDecode(texelFetch(colortex5, ivec2(uv * viewSize), 0).rg));
}

vec3 getNH(vec2 uv){
    return normalize(normalDecode(texelFetch(colortex9, ivec2(uv * viewSize), 0).ba));
}
#endif

#endif // COMMON_NORMAL_GLSL