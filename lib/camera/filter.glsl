#ifndef _FILTER_GLSL_
#define _FILTER_GLSL_

// hornet: Texture Filtering: Catmull-Rom 
// https://www.shadertoy.com/view/MtVGWz
vec4 catmullRom(sampler2D text, vec2 uv){
    vec2 samplePos = uv * viewSize;
    vec2 texPos1 = floor(samplePos - 0.5f) + 0.5f;
    vec2 f = samplePos - texPos1;
    vec2 w0 = f * (-0.5f + f * (1.0f - 0.5f * f));
    vec2 w1 = 1.0f + f * f * (-2.5f + 1.5f * f);
    vec2 w2 = f * (0.5f + f * (2.0f - 1.5f * f));
    vec2 w3 = f * f * (-0.5f + 0.5f * f);
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);
    vec2 texPos0 = texPos1 - 1.0f;
    vec2 texPos3 = texPos1 + 2.0f;
    vec2 texPos12 = texPos1 + offset12;
    texPos0 *= invViewSize;
    texPos3 *= invViewSize;
    texPos12 *= invViewSize;
    vec4 result = vec4(0.0);
    result += texture(text, vec2(texPos0.x, texPos0.y)) * w0.x * w0.y;
    result += texture(text, vec2(texPos12.x, texPos0.y)) * w12.x * w0.y;
    result += texture(text, vec2(texPos3.x, texPos0.y)) * w3.x * w0.y;
    result += texture(text, vec2(texPos0.x, texPos12.y)) * w0.x * w12.y;
    result += texture(text, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += texture(text, vec2(texPos3.x, texPos12.y)) * w3.x * w12.y;
    result += texture(text, vec2(texPos0.x, texPos3.y)) * w0.x * w3.y;
    result += texture(text, vec2(texPos12.x, texPos3.y)) * w12.x * w3.y;
    result += texture(text, vec2(texPos3.x, texPos3.y)) * w3.x * w3.y;
    return max(result, 0.0f);
}

vec4 catmullRom5( sampler2D text, vec2 uv, float sharpenAmount){
    vec2 texsiz = viewSize;
    vec4 rtMetrics = vec4( 1.0 / texsiz.xy, texsiz.xy );
    
    vec2 position = rtMetrics.zw * uv;
    vec2 centerPosition = floor(position - 0.5) + 0.5;
    vec2 f = position - centerPosition;
    vec2 f2 = f * f;
    vec2 f3 = f * f2;

    const float c = sharpenAmount;
    vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
    vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
    vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
    vec2 w3 =         c  * f3 -                c * f2;

    vec2 w12 = w1 + w2;
    vec2 tc12 = rtMetrics.xy * (centerPosition + w2 / w12);
    vec3 centerColor = texture(text, vec2(tc12.x, tc12.y)).rgb;

    vec2 tc0 = rtMetrics.xy * (centerPosition - 1.0);
    vec2 tc3 = rtMetrics.xy * (centerPosition + 2.0);
    vec4 color = vec4(texture(text, vec2(tc12.x, tc0.y )).rgb, 1.0) * (w12.x * w0.y ) +
                 vec4(texture(text, vec2(tc0.x,  tc12.y)).rgb, 1.0) * (w0.x  * w12.y) +
                 vec4(centerColor,                                 1.0) * (w12.x * w12.y) +
                 vec4(texture(text, vec2(tc3.x,  tc12.y)).rgb, 1.0) * (w3.x  * w12.y) +
                 vec4(texture(text, vec2(tc12.x, tc3.y )).rgb, 1.0) * (w12.x * w3.y );
    return vec4( color.rgb / color.a, 1.0 );
}



vec3 gaussianBlur6x6(sampler2D tex, vec2 uv, float blurScale, float lodLevel) {
    const float kernel[36] = float[](
        0.002969, 0.013306, 0.021938, 0.021938, 0.013306, 0.002969,
        0.013306, 0.059634, 0.098320, 0.098320, 0.059634, 0.013306,
        0.021938, 0.098320, 0.162103, 0.162103, 0.098320, 0.021938,
        0.021938, 0.098320, 0.162103, 0.162103, 0.098320, 0.021938,
        0.013306, 0.059634, 0.098320, 0.098320, 0.059634, 0.013306,
        0.002969, 0.013306, 0.021938, 0.021938, 0.013306, 0.002969
    );
    vec2 scaledTexelSize = invViewSize * blurScale;
    vec2 center = uv - 2.5 * scaledTexelSize;

    vec3 color = BLACK;
    for (int i = 0; i < 6; i++) {
    for (int j = 0; j < 6; j++) {
        vec2 offset = vec2(float(i), float(j)) * scaledTexelSize;
        vec2 sampleCoord = center + offset;
        color += textureLod(tex, sampleCoord, lodLevel).rgb * kernel[i * 6 + j];
    }
    }
    return color;
}

vec4 gaussianBlur5x5(sampler2D tex, vec2 uv, float scale) {
    const float kernel[25] = float[](
        0.00072, 0.00628, 0.01290, 0.00628, 0.00072,
        0.00628, 0.05446, 0.11189, 0.05446, 0.00628,
        0.01290, 0.11189, 0.22986, 0.11189, 0.01290,
        0.00628, 0.05446, 0.11189, 0.05446, 0.00628,
        0.00072, 0.00628, 0.01290, 0.00628, 0.00072
    );
    
    vec2 scaledTexelSize = invViewSize * scale;
    vec4 result = vec4(0.0);
    
    for (int y = 0; y < 5; y++) {
    for (int x = 0; x < 5; x++) {
        vec2 offset = vec2(float(x - 2), float(y - 2)) * scaledTexelSize;
        vec2 currUV = uv + offset;
        result += texture(tex, currUV) * kernel[y * 5 + x];
    }
    }
    
    return result;
}

const float kernel6[6] = float[](0.054488, 0.244201, 0.402620, 0.402620, 0.244201, 0.054488);

vec3 gaussianBlur6x1(sampler2D tex, vec2 uv, float blurScale, float lodLevel) {
    vec2 scaledTexelSize = vec2(invViewSize.x * blurScale, 0.0);
    vec2 center = uv - 2.5 * scaledTexelSize;

    vec3 color = BLACK;
    for (int i = 0; i < 6; i++) {
        vec2 sampleCoord = center + vec2(float(i), 0.0) * scaledTexelSize;
        color += textureLod(tex, sampleCoord, lodLevel).rgb * kernel6[i];
    }
    return color;
}

vec3 gaussianBlur1x6(sampler2D tex, vec2 uv, float blurScale, float lodLevel) {
    vec2 scaledTexelSize = vec2(0.0, invViewSize.y * blurScale);
    vec2 center = uv - 2.5 * scaledTexelSize;

    vec3 color = BLACK;
    for (int i = 0; i < 6; i++) {
        vec2 sampleCoord = center + vec2(0.0, float(i)) * scaledTexelSize;
        color += textureLod(tex, sampleCoord, lodLevel).rgb * kernel6[i];
    }
    return color;
}

vec3 filter5_22(sampler2D tex, vec2 uv, float scale, float lod){
    const vec3 filterOffset[13] = vec3[](
        vec3(0.0, 0.0, 0.5),
        vec3(1.0, 1.0, 0.5),
        vec3(1.0, -1.0, 0.5),
        vec3(-1.0, 1.0, 0.5),
        vec3(-1.0, -1.0, 0.5),
        vec3(2.0, 0.0, 0.25),
        vec3(-2.0, 0.0, 0.25),
        vec3(0.0, 2.0, 0.25),
        vec3(0.0, -2.0, 0.25),
        vec3(2.0, 2.0, 0.125),
        vec3(2.0, -2.0, 0.125),
        vec3(-2.0, 2.0, 0.125),
        vec3(-2.0, -2.0, 0.125)
    );

    vec3 color = BLACK;
    for(int i = 0; i < 13; ++i){
        vec2 offset = (filterOffset[i].xy) * invViewSize * scale;
        vec2 curUV = uv + offset;
        color += textureLod(tex, curUV, lod).rgb * filterOffset[i].z;
    }

    return color;
}

// simesgreen : https://www.shadertoy.com/view/4df3Dn
// 4*4 bicubic filter
float w0(float a){
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}
float w1(float a){
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}
float w2(float a){
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}
float w3(float a){
    return (1.0/6.0)*(a*a*a);
}

// g0 and g1 are the two amplitude functions
float g0(float a){
    return w0(a) + w1(a);
}
float g1(float a){
    return w2(a) + w3(a);
}

// h0 and h1 are the two offset functions
float h0(float a){
    return -1.0 + w1(a) / (w0(a) + w1(a));
}
float h1(float a){
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

vec4 textureBicubic(sampler2D text, vec2 uv){
	uv = uv * viewSize + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * invViewSize;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * invViewSize;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * invViewSize;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * invViewSize;
	
    return g0(fuv.y) * (g0x * texture(text, p0)  +
                        g1x * texture(text, p1)) +
           g1(fuv.y) * (g0x * texture(text, p2)  +
                        g1x * texture(text, p3));
}

vec4 textureBicubic(sampler2D text, vec2 uv, float textureSize){
	uv = uv * textureSize + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) / textureSize;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) / textureSize;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) / textureSize;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) / textureSize;
	
    return g0(fuv.y) * (g0x * texture(text, p0)  +
                        g1x * texture(text, p1)) +
           g1(fuv.y) * (g0x * texture(text, p2)  +
                        g1x * texture(text, p3));
}

vec4 textureNice(sampler2D tex, vec2 uv, float texResolution){
    uv = uv*texResolution + 0.5;
    vec2 iuv = floor( uv );
    vec2 fuv = fract( uv );
    uv = iuv + fuv*fuv*(3.0-2.0*fuv);
    uv = (uv - 0.5)/texResolution;
    return texture( tex, uv );
}

const vec2 offsetUV5[5] = vec2[](
    vec2(0.0, 0.0),
    vec2(1.0, 1.0),
    vec2(1.0, -1.0),
    vec2(-1.0, -1.0),
    vec2(-1.0, 1.0)
);

const vec2 offsetUV9[9] = vec2[](
    vec2(0.0, 0.0),
    vec2(-1.0, 1.0),
    vec2(0.0, 1.0),
    vec2(1.0, 1.0),
    vec2(-1.0, 0.0),
    vec2(1.0, 0.0),
    vec2(-1.0, -1.0),
    vec2(0.0, -1.0),
    vec2(1.0, -1.0)
);

const vec2 offsetUV12[13] = vec2[](
    vec2(0.0, 0.0),
    vec2(-1.0, 1.0),
    vec2(-2.0, 2.0),
    vec2(0.0, 1.0),
    vec2(1.0, 1.0),
    vec2(2.0, 2.0),
    vec2(-1.0, 0.0),
    vec2(1.0, 0.0),
    vec2(-1.0, -1.0),
    vec2(2.0, -2.0),
    vec2(0.0, -1.0),
    vec2(1.0, -1.0),
    vec2(-2.0, -2.0)
);

const vec2 tentOffsetUV[4] = vec2[](
    vec2(-0.5, -0.5),
    vec2(0.5, 0.5),
    vec2(0.5, -0.5),
    vec2(-0.5, 0.5)
);

const vec2 offsetUV16[16] = vec2[](
    vec2(0, 0),
    vec2(0.54545456, 0),
    vec2(0.16855472, 0.5187581),
    vec2(-0.44128203, 0.3206101),
    vec2(-0.44128197, -0.3206102),
    vec2(0.1685548, -0.5187581),
    vec2(1, 0),
    vec2(0.809017, 0.58778524),
    vec2(0.30901697, 0.95105654),
    vec2(-0.30901703, 0.9510565),
    vec2(-0.80901706, 0.5877852),
    vec2(-1, 0),
    vec2(-0.80901694, -0.58778536),
    vec2(-0.30901664, -0.9510566),
    vec2(0.30901712, -0.9510565),
    vec2(0.80901694, -0.5877853)
);
#endif