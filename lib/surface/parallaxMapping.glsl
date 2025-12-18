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

float getParallaxHeight(vec2 uv){
    float dis = length(viewPos.xyz);
    if(dis > PARALLAX_DISTANCE) return 1.0;
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

    float thresh = 0.5 / 255.0;
    vec4 hh = vec4(h00, h10, h01, h11);
    hh = mix(vec4(1.0), hh, step(vec4(thresh), hh));
    h00 = hh.x; h10 = hh.y; h01 = hh.z; h11 = hh.w;

    float hx0 = mix(h00, h10, f.x);
    float hx1 = mix(h01, h11, f.x);
    float height = mix(hx0, hx1, f.y);

    return mix(height, 1.0, remapSaturate(dis, 0.5 * PARALLAX_DISTANCE, PARALLAX_DISTANCE, 0.0, 1.0));
}

vec3 computeNormalFromHeight(vec2 parallaxUV) {
    const float sampleSpanTexels = 1.0;
    vec2 dUV = vec2(sampleSpanTexels) / vec2(atlasSize);

    float hc = getParallaxHeight(parallaxUV);

    vec2 leftUV  = GetParallaxCoord(vec2(-dUV.x,0.0), parallaxUV, textureResolution);
    vec2 rightUV = GetParallaxCoord(vec2(dUV.x, 0.0), parallaxUV, textureResolution);
    vec2 downUV  = GetParallaxCoord(vec2(0.0, -dUV.y), parallaxUV, textureResolution);
    vec2 upUV    = GetParallaxCoord(vec2(0.0,  dUV.y), parallaxUV, textureResolution);

    float hl = getParallaxHeight(leftUV);
    float hr = getParallaxHeight(rightUV);
    float hd = getParallaxHeight(downUV);
    float hu = getParallaxHeight(upUV);

    float spanUV = sampleSpanTexels / float(textureResolution);
    float dhdu = (hr - hl) / (2.0 * spanUV);
    float dhdv = (hu - hd) / (2.0 * spanUV);

    vec3 n = normalize(vec3(-PARALLAX_HEIGHT * dhdu, -PARALLAX_HEIGHT * dhdv, 1.0));

    return n;
}

vec2 parallaxMapping(vec3 viewVector, inout vec3 parallaxOffset, inout vec3 normalTS){
    // const float slicesMin = 60.0;
    // const float slicesMax = 60.0;
    // float slicesNum = ceil(lerp(slicesMax, slicesMin, abs(dot(vec3(0, 0, 1), viewVector))));
    float slicesNum = PARALLAX_SAMPPLES;

    float dHeight = 1.0 / slicesNum;
    vec2 dUV = vec2(textureResolution)/vec2(atlasSize) * PARALLAX_HEIGHT * (viewVector.xy / viewVector.z) / slicesNum;

    vec2 currUVOffset = vec2(0.0);
    float rayHeight = 1.0;
    float weight = 0.0;
    float prevHeight = getParallaxHeight(GetParallaxCoord(vec2(0.0)));
    float currHeight = prevHeight;
    if(prevHeight < 254.5 / 255.0){
        rayHeight = 1.0 - dither * dHeight;
        currUVOffset -= dither * dUV;
        currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset)); 
        for(int i = 0; i < slicesNum; ++i){
            if(currHeight > rayHeight){
                break;
            }
            prevHeight = currHeight;
            currUVOffset -= dUV;
            rayHeight -= dHeight;
            currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset)); 
        }

        float currDeltaHeight = currHeight - rayHeight;
        float prevDeltaHeight = rayHeight + dHeight - prevHeight;
        weight = currDeltaHeight / (currDeltaHeight + prevDeltaHeight);
    }

    vec2 lerpOffset = weight * dUV;

    parallaxOffset = vec3(currUVOffset + lerpOffset, rayHeight);
    vec2 parallaxUV = GetParallaxCoord(parallaxOffset.xy);
    
    if(PARALLAX_NORMAL_MIX_WEIGHT > 0.0001){
        normalTS = computeNormalFromHeight(parallaxUV);
    }

    return parallaxUV;
}



float getVoxelHeightTexel(ivec2 texelIndex, ivec2 tileStartPx){
    float dis = length(viewPos.xyz);
    if(dis > PARALLAX_DISTANCE) return 1.0;

    int res = textureResolution;

    int ix = texelIndex.x % res;
    int iy = texelIndex.y % res;
    if (ix < 0) ix += res;
    if (iy < 0) iy += res;

    ivec2 pixelCoord = tileStartPx + ivec2(ix, iy);

    float h = texelFetch(normals, pixelCoord, 0).a;

    float thresh = 0.5 / 255.0;
    if (h < thresh)
        h = 1.0;

    return mix(h, 1.0, remapSaturate(dis, 0.5 * PARALLAX_DISTANCE, PARALLAX_DISTANCE, 0.0, 1.0));
    return h;
}

vec2 voxelParallaxMapping(vec3 viewVector, inout vec3 parallaxOffset, inout vec3 voxelNormalTS){
    vec2 tileSizeNormalized = vec2(float(textureResolution)) / vec2(atlasSize);
    
    vec2 tileStart = floor(texcoord / tileSizeNormalized) * tileSizeNormalized;
    
    vec2 localUV0 = (texcoord - tileStart) / tileSizeNormalized;
    localUV0 = clamp(localUV0, vec2(0.0), vec2(1.0 - 1e-6));

    float resF = float(textureResolution);
    vec2 gridPos = localUV0 * resF;

    int ix = int(floor(gridPos.x));
    int iy = int(floor(gridPos.y));

    ivec2 atlasPxSize = atlasSize;
    ivec2 tileStartPx = ivec2(tileStart * vec2(atlasPxSize) + 0.5);

    int res = textureResolution;

    int sx0 = ix % res; if (sx0 < 0) sx0 += res;
    int sy0 = iy % res; if (sy0 < 0) sy0 += res;
    
    float hCurr = getVoxelHeightTexel(ivec2(sx0, sy0), tileStartPx);

    int sxCurr = sx0;
    int syCurr = sy0;

    voxelNormalTS = vec3(0.0, 0.0, 1.0);
    vec3 hitNormalTS = vec3(0.0, 0.0, 1.0);

    if (hCurr >= 254.5 / 255.0) {
        parallaxOffset = vec3(0.0, 0.0, 1.0);
        voxelNormalTS  = vec3(0.0, 0.0, 1.0);
        return texcoord;
    }

    const float EPS  = 1e-4;
    const float HUGE = 1e20;

    float vz = max(abs(viewVector.z), EPS);
    
    vec3 rayDirLocal = vec3(PARALLAX_HEIGHT * viewVector.xy / vz, -1.0);
    
    vec2 rayDirGrid  = rayDirLocal.xy * resF;

    int   stepX   = (rayDirGrid.x > 0.0) ? 1 : -1;
    int   stepY   = (rayDirGrid.y > 0.0) ? 1 : -1;
    
    float invDirX = (rayDirGrid.x != 0.0) ? 1.0 / abs(rayDirGrid.x) : HUGE;
    float invDirY = (rayDirGrid.y != 0.0) ? 1.0 / abs(rayDirGrid.y) : HUGE;
    float tDeltaX = invDirX;
    float tDeltaY = invDirY;

    float fracX = gridPos.x - float(ix);
    float fracY = gridPos.y - float(iy);

    float tMaxX = (rayDirGrid.x > 0.0) ? (1.0 - fracX) * invDirX : fracX * invDirX;
    float tMaxY = (rayDirGrid.y > 0.0) ? (1.0 - fracY) * invDirY : fracY * invDirY;

    float tEnter = 0.0;

    bool  hit          = false;
    bool  hitSide      = false;
    float tHit         = 1.0;
    float hitHeight    = 1.0;

    vec2  hitLocalUVGeo   = localUV0;
    vec2  hitLocalUVColor = localUV0;

    for (int step = 0; step < 128.0; ++step) {
        if (tEnter > 1.0)
            break;

        float tExit        = min(tMaxX, tMaxY);
        float tExitClamped = min(tExit, 1.0);

        float tTop = 1.0 - hCurr;

        // 顶部碰撞
        if (tTop >= tEnter && tTop <= tExitClamped) {
            hit       = true;
            hitSide   = false;
            tHit      = tTop;
            hitHeight = hCurr;

            vec2 localHit = localUV0 + rayDirLocal.xy * tHit;
            hitLocalUVGeo   = localHit;
            hitLocalUVColor = localHit;

            // 顶部法向量
            hitNormalTS = vec3(0.0, 0.0, 1.0);

            break;
        }

        bool  stepXaxis = (tMaxX < tMaxY);
        
        float tBoundary = tExit;

        if (tBoundary > 1.0) {
            break;
        }

        int nx = ix + (stepXaxis ? stepX : 0);
        int ny = iy + (stepXaxis ? 0    : stepY);

        int sNx = nx % res; if (sNx < 0) sNx += res;
        int sNy = ny % res; if (sNy < 0) sNy += res;
        
        float hNext = getVoxelHeightTexel(ivec2(sNx, sNy), tileStartPx);

        float heightB = 1.0 - tBoundary;
        
        float hMin = min(hCurr, hNext);
        float hMax = max(hCurr, hNext);

        // 侧面碰撞
        if (heightB >= hMin && heightB <= hMax) {
            hit       = true;
            hitSide   = true;
            tHit      = tBoundary;
            hitHeight = heightB;

            vec2 localHitGeo = localUV0 + rayDirLocal.xy * tHit;
            hitLocalUVGeo = localHitGeo;

            bool currIsHigh = (hCurr >= hNext);

            int highSx = currIsHigh ? sxCurr : sNx;
            int highSy = currIsHigh ? syCurr : sNy;

            vec2 highCellUV = (vec2(highSx, highSy) + vec2(0.5)) / resF;
            hitLocalUVColor = highCellUV;

            // 侧面法向量
            int highIx = currIsHigh ? ix : nx;
            int highIy = currIsHigh ? iy : ny;
            int lowIx  = currIsHigh ? nx : ix;
            int lowIy  = currIsHigh ? ny : iy;

            int dx = lowIx - highIx;
            int dy = lowIy - highIy;

            vec3 nSide = vec3(float(dx), float(dy), 0.0);

            if (nSide.x == 0.0 && nSide.y == 0.0) {
                nSide = vec3(0.0, 0.0, 1.0);
            }

            hitNormalTS = normalize(nSide);

            break;
        }

        tEnter = tExit;

        if (stepXaxis) {
            tMaxX += tDeltaX;
            ix     = nx;
        } else {
            tMaxY += tDeltaY;
            iy     = ny;
        }

        hCurr  = hNext;
        sxCurr = sNx;
        syCurr = sNy;
    }

    vec2  offsetShade = vec2(0.0);
    vec2  offsetGeo   = vec2(0.0);
    float finalHeight = 1.0;

    if (hit) {
        vec2 localGeoWrapped = fract(hitLocalUVGeo); 
        vec2 finalTexcoordGeo   = tileStart + localGeoWrapped * tileSizeNormalized;

        vec2 finalTexcoordColor = tileStart + hitLocalUVColor   * tileSizeNormalized;

        offsetGeo   = finalTexcoordGeo   - texcoord;
        offsetShade = finalTexcoordColor - texcoord;
        finalHeight = hitHeight;
    } else {
        offsetGeo   = vec2(0.0);
        offsetShade = vec2(0.0);
        finalHeight = 0.0;

        hitNormalTS = vec3(0.0, 0.0, 1.0);
    }

    parallaxOffset = vec3(offsetGeo, finalHeight);
    voxelNormalTS  = hitNormalTS;

    return GetParallaxCoord(offsetShade);
}




void getVoxelTileData(vec2 uv, out vec2 localUV, out ivec2 tileStartPx){
    vec2 tileSizeNormalized = vec2(float(textureResolution)) / vec2(atlasSize);
    vec2 tileStart = floor(uv / tileSizeNormalized) * tileSizeNormalized;
    localUV = fract((uv - tileStart) / tileSizeNormalized);
    ivec2 atlasPxSize = atlasSize;
    tileStartPx = ivec2(tileStart * vec2(atlasPxSize) + 0.5);
}

float getVoxelHeight(vec2 uv){
    vec2 localUV;
    ivec2 tileStartPx;
    getVoxelTileData(uv, localUV, tileStartPx);

    float resF = float(textureResolution);
    ivec2 texelIndex = ivec2(floor(localUV * resF));

    return getVoxelHeightTexel(texelIndex, tileStartPx);
}

float sampleParallaxHeight(bool useVoxelHeight, vec2 coord){
    return useVoxelHeight ? getVoxelHeight(coord) : getParallaxHeight(coord);
}

float traceParallaxShadow(vec3 parallaxOffset, vec3 lightDirTS, float shadowSoftening, bool useVoxelHeight){
    float parallaxHeight = parallaxOffset.z;
    if (parallaxHeight >= 254.5 / 255.0) return 1.0;

    const int SAMPLES = int(PARALLAX_SHADOW_SAMPPLES);
    float slicesNum = float(SAMPLES);

    float dDist = 1.0 / slicesNum;
    float dHeight = (1.0 - parallaxHeight) / slicesNum;

    vec2 uvScale = vec2(float(textureResolution)) / vec2(atlasSize);
    float vz = max(abs(lightDirTS.z), 1e-5);
    vec2 dirXYPerHeight = PARALLAX_HEIGHT * lightDirTS.xy / vz;
    vec2 dUV = uvScale * dirXYPerHeight * dHeight;

    float rayHeight = parallaxHeight + dither * dHeight;
    float dist = dDist;

    vec2 currUVOffset = parallaxOffset.xy + dither * dUV;
    float currHeight = sampleParallaxHeight(useVoxelHeight, GetParallaxCoord(currUVOffset));

    float shadow = 0.0;

    for (int i = 1; i < SAMPLES && rayHeight < 1.0; ++i) {
        float bias = 12.5 / 255.0 * (1.0 - 0.8 * float(PARALLAX_TYPE));
        if (currHeight > rayHeight + bias){
            float occlusion = (currHeight - rayHeight) / dist * shadowSoftening;
            shadow = max(shadow, occlusion);
            if (shadow >= 0.99) break;
        }

        rayHeight += dHeight;
        dist += dDist;
        currUVOffset += dUV;
        currHeight = sampleParallaxHeight(useVoxelHeight, GetParallaxCoord(currUVOffset));
    }

    return saturate(1.0 - shadow);
}


float ParallaxShadow(vec3 parallaxOffset, vec3 lightDirTS){
    return traceParallaxShadow(parallaxOffset, lightDirTS, PARALLAX_SHADOW_SOFTENING * 2.5, false);
}

float voxelParallaxShadow(vec3 parallaxOffset, vec3 lightDirTS){
    return traceParallaxShadow(parallaxOffset, lightDirTS, PARALLAX_SHADOW_SOFTENING * 5.0, true);
}
