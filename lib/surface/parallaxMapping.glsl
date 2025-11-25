// 效果设计-Parallax Mapping视差映射
// https://miusjun13qu.feishu.cn/docx/G17IdiCyhoEd7XxBqJOcb3J1nie

vec2 GetParallaxCoord(vec2 offsetNormalized) {
    vec2 tileSizeNormalized = vec2(float(textureResolution)) / vec2(atlasSize);
    vec2 tileStart = floor(texcoord / tileSizeNormalized) * tileSizeNormalized;

    vec2 targetCoord = texcoord + offsetNormalized;
    vec2 relativeCoord = targetCoord - tileStart;
    vec2 wrappedRelativeCoord = mod(relativeCoord, tileSizeNormalized);

    return tileStart + wrappedRelativeCoord;
}

float getParallaxHeight(vec2 uv, vec2 texGradX, vec2 texGradY){
    float baseAlpha = texture(tex, uv).a;
    
    vec2 tileSizeNormalized = vec2(float(textureResolution)) / atlasSize;
    vec2 tileStart = floor(uv / tileSizeNormalized) * tileSizeNormalized;
    
    vec2 localUV = (uv - tileStart) / tileSizeNormalized;

    vec2 texPos = localUV * float(textureResolution);
    vec2 f = fract(texPos);
    ivec2 i0 = ivec2(floor(texPos));

    ivec2 atlasPxSize = atlasSize;

    ivec2 tileStartPx = ivec2(tileStart * vec2(atlasPxSize) + 0.5);

    int res = textureResolution;
    int ix = i0.x % res;
    int iy = i0.y % res;
    if(ix < 0) ix += res;
    if(iy < 0) iy += res;

    int ix1 = (ix + 1) % res;
    int iy1 = (iy + 1) % res;

    ivec2 p00 = tileStartPx + ivec2(ix,  iy);
    ivec2 p10 = tileStartPx + ivec2(ix1, iy);
    ivec2 p01 = tileStartPx + ivec2(ix,  iy1);
    ivec2 p11 = tileStartPx + ivec2(ix1, iy1);

    float h00 = texelFetch(normals, p00, 0).a;
    float h10 = texelFetch(normals, p10, 0).a;
    float h01 = texelFetch(normals, p01, 0).a;
    float h11 = texelFetch(normals, p11, 0).a;

    float thresh = 0.9 / 255.0;
    vec4 hh = vec4(h00, h10, h01, h11);
    hh = mix(vec4(1.0), hh, step(vec4(thresh), hh));
    h00 = hh.x; h10 = hh.y; h01 = hh.z; h11 = hh.w;

    float hx0 = mix(h00, h10, f.x);
    float hx1 = mix(h01, h11, f.x);
    float height = mix(hx0, hx1, f.y);

    return height;
}

vec2 parallaxMapping(vec3 viewVector, vec2 texGradX, vec2 texGradY, out vec3 parallaxOffset){
    // const float slicesMin = 60.0;
    // const float slicesMax = 60.0;
    // float slicesNum = ceil(lerp(slicesMax, slicesMin, abs(dot(vec3(0, 0, 1), viewVector))));
    float slicesNum = PARALLAX_SAMPPLES;

    float dHeight = 1.0 / slicesNum;
    vec2 dUV = vec2(textureResolution)/vec2(atlasSize) * PARALLAX_HEIGHT * (viewVector.xy / viewVector.z) / slicesNum;

    vec2 currUVOffset = vec2(0.0);
    float rayHeight = 1.0;
    float weight = 0.0;
    float prevHeight = getParallaxHeight(GetParallaxCoord(vec2(0.0)), texGradX, texGradY);
    float currHeight = prevHeight;
    if(prevHeight < 1.0){
        rayHeight = 1.0 - dHeight;
        currUVOffset -= dUV;
        currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset), texGradX, texGradY);
        for(int i = 0; i < slicesNum; ++i){
            if(currHeight > rayHeight){
                break;
            }
            prevHeight = currHeight;
            currUVOffset -= dUV;
            rayHeight -= dHeight;
            currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset), texGradX, texGradY);
        }

        float currDeltaHeight = currHeight - rayHeight;
        float prevDeltaHeight = rayHeight + dHeight - prevHeight;
        weight = currDeltaHeight / (currDeltaHeight + prevDeltaHeight);
    }

    vec2 lerpOffset = weight * dUV;
    parallaxOffset = vec3(currUVOffset + lerpOffset, rayHeight);
    return GetParallaxCoord(currUVOffset + lerpOffset);
}

vec3 computeNormalFromHeight(vec2 parallaxUV, vec2 texGradX, vec2 texGradY) {
    ivec2 atlasPxSizeI = textureSize(normals, 0);
    vec2 atlasPxSize = vec2(atlasPxSizeI);
    vec2 oneTexelUV = 0.02 * (vec2(textureResolution) / vec2(atlasPxSize));

    float parallaxHeight = PARALLAX_HEIGHT * 0.025;
    float hc = mix(1.0, getParallaxHeight(parallaxUV, texGradX, texGradY), parallaxHeight);

    vec2 offX = vec2(oneTexelUV.x, 0.0);
    vec2 offY = vec2(0.0, oneTexelUV.y);

    vec2 leftUV  = GetParallaxCoord(-offX, parallaxUV, textureResolution);
    vec2 rightUV = GetParallaxCoord( offX, parallaxUV, textureResolution);
    vec2 downUV  = GetParallaxCoord( vec2(0.0, -oneTexelUV.y), parallaxUV, textureResolution);
    vec2 upUV    = GetParallaxCoord( vec2(0.0,  oneTexelUV.y), parallaxUV, textureResolution);

    float hl = mix(1.0, getParallaxHeight(leftUV, texGradX, texGradY), parallaxHeight);
    float hr = mix(1.0, getParallaxHeight(rightUV, texGradX, texGradY), parallaxHeight);
    float hd = mix(1.0, getParallaxHeight(downUV, texGradX, texGradY), parallaxHeight);
    float hu = mix(1.0, getParallaxHeight(upUV, texGradX, texGradY), parallaxHeight);

    float dhdu = (hr - hl) / (2.0 * oneTexelUV.x);
    float dhdv = (hu - hd) / (2.0 * oneTexelUV.y);

    vec3 n = normalize(vec3(-PARALLAX_HEIGHT * dhdu, -PARALLAX_HEIGHT * dhdv, 1.0));

    return n;
}

float ParallaxShadow(vec3 parallaxOffset, vec3 viewDirTS, vec3 lightDirTS, vec2 texGradX, vec2 texGradY){
    float parallaxHeight = parallaxOffset.z;
    float shadow = 0.0;

    if(parallaxHeight < 0.99){  
        const float shadowSoftening = PARALLAX_SHADOW_SOFTENING;
        float slicesNum = PARALLAX_SHADOW_SAMPPLES;
        
        float dDist = 1.0 / slicesNum;
        float dHeight = (1.0 - parallaxHeight) / slicesNum;
        vec2 dUV = vec2(textureResolution)/vec2(atlasSize) * PARALLAX_HEIGHT * dHeight * lightDirTS.xy / lightDirTS.z;

        float rayHeight = parallaxHeight + dHeight;
        float dist = dDist;

        vec2 currUVOffset = parallaxOffset.st + dUV;
        float currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset), texGradX, texGradY);

        for (int i = 1; i < slicesNum && rayHeight < 1.0; i++){
                if (currHeight > rayHeight){
                    shadow = max(shadow, (currHeight - rayHeight) / dist * shadowSoftening);
                    if(1.0 == shadow) break;
                }
                rayHeight += dHeight;
                dist += dDist;
            
            currUVOffset += dUV;
            currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset), texGradX, texGradY);
        }

    }

    return saturate(1.0 - shadow);
}
