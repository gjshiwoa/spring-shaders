vec2 AtlasFromLocal(vec2 local01) {
    return texCoordAM.st + fract(local01) * texCoordAM.pq;
}

int wrapInt(int x, int n) {
    int r = x % n;
    return (r < 0) ? (r + n) : r;
}

float dis = length(viewPos.xyz);

void getTileInfo(out ivec2 tileStartPx, out ivec2 tilePxSize) {
    tileStartPx = ivec2(texCoordAM.st * vec2(atlasSize) + 0.5);
    ivec2 sz = ivec2(texCoordAM.pq * vec2(atlasSize) + 0.5);
    tilePxSize = max(min(max(sz, ivec2(1)), atlasSize - tileStartPx), ivec2(1));
}

float getParallaxHeight(vec2 uv){
    if(dis > PARALLAX_DISTANCE) return 1.0;
    if(any(lessThan(texCoordAM.pq, vec2(1e-8)))) return 1.0;

    vec2 localUV = fract((uv - texCoordAM.st) / texCoordAM.pq);

    ivec2 tileStartPx, tilePxSize;
    getTileInfo(tileStartPx, tilePxSize);

    vec2 texPos = localUV * vec2(tilePxSize) - 0.5;
    vec2 f = fract(texPos);
    ivec2 i0 = ivec2(floor(texPos));

    int ix  = wrapInt(i0.x, tilePxSize.x);
    int iy  = wrapInt(i0.y, tilePxSize.y);
    int ix1 = (ix + 1) % tilePxSize.x;
    int iy1 = (iy + 1) % tilePxSize.y;

    float h00 = texelFetch(normals, tileStartPx + ivec2(ix,  iy),  0).a;
    float h10 = texelFetch(normals, tileStartPx + ivec2(ix1, iy),  0).a;
    float h01 = texelFetch(normals, tileStartPx + ivec2(ix,  iy1), 0).a;
    float h11 = texelFetch(normals, tileStartPx + ivec2(ix1, iy1), 0).a;

    float thresh = 0.5 / 255.0;
    vec4 hh = vec4(h00, h10, h01, h11);
    hh = mix(vec4(1.0), hh, step(vec4(thresh), hh));

    float hx0 = mix(hh.x, hh.y, f.x);
    float hx1 = mix(hh.z, hh.w, f.x);
    float height = mix(hx0, hx1, f.y);

    return mix(height, 1.0,
        remapSaturate(dis, 0.5 * PARALLAX_DISTANCE, PARALLAX_DISTANCE, 0.0, 1.0)
    );
}

vec3 computeNormalFromHeight(vec2 parallaxUV) {
    const float sampleSpanTexels = 1.0;

    ivec2 tileStartPx, tilePxSize;
    getTileInfo(tileStartPx, tilePxSize);

    vec2 localBase = fract((parallaxUV - texCoordAM.st) / texCoordAM.pq);
    vec2 dLocal = vec2(sampleSpanTexels) / vec2(tilePxSize);

    float hl = getParallaxHeight(AtlasFromLocal(localBase + vec2(-dLocal.x, 0.0)));
    float hr = getParallaxHeight(AtlasFromLocal(localBase + vec2( dLocal.x, 0.0)));
    float hd = getParallaxHeight(AtlasFromLocal(localBase + vec2(0.0, -dLocal.y)));
    float hu = getParallaxHeight(AtlasFromLocal(localBase + vec2(0.0,  dLocal.y)));

    float dhdu = (hr - hl) / (2.0 * dLocal.x);
    float dhdv = (hu - hd) / (2.0 * dLocal.y);

    return normalize(vec3(-PARALLAX_HEIGHT * dhdu, -PARALLAX_HEIGHT * dhdv, 1.0));
}

vec2 parallaxMapping(vec3 viewVector, inout vec3 parallaxOffset, inout vec3 normalTS){
    float viewAngleScale = 1.0 / max(abs(viewVector.z), 0.05);
    int slicesNum = int(PARALLAX_SAMPLES * viewAngleScale);
    slicesNum = clamp(slicesNum, int(PARALLAX_SAMPLES), int(PARALLAX_SAMPLES) * 2);
    // int slicesNum = int(PARALLAX_SAMPLES);
    float dHeight = 1.0 / float(slicesNum);
    vec2 dUVLocal = PARALLAX_HEIGHT * (viewVector.xy / viewVector.z) / float(slicesNum);

    vec2 currOffsetLocal = vec2(0.0);
    float rayHeight = 1.0;
    float prevHeight = getParallaxHeight(AtlasFromLocal(texCoordLocal));
    float currHeight = prevHeight;

    if(prevHeight < 254.5 / 255.0){
        rayHeight -= dither * dHeight;
        currOffsetLocal -= dither * dUVLocal;
        currHeight = getParallaxHeight(AtlasFromLocal(texCoordLocal + currOffsetLocal));

        for(int i = 0; i < slicesNum; ++i){
            if(currHeight > rayHeight) break;

            prevHeight = currHeight;
            currOffsetLocal -= dUVLocal;
            rayHeight -= dHeight;

            currHeight = getParallaxHeight(AtlasFromLocal(texCoordLocal + currOffsetLocal));
        }

        vec2 biOffsetPrev = currOffsetLocal + dUVLocal;
        vec2 biOffsetCurr = currOffsetLocal;
        float biRayPrev   = rayHeight + dHeight;
        float biRayCurr   = rayHeight;

        for(int j = 0; j < 4; ++j){
            vec2  midOffset = (biOffsetPrev + biOffsetCurr) * 0.5;
            float midRay    = (biRayPrev + biRayCurr) * 0.5;
            float midHeight = getParallaxHeight(AtlasFromLocal(texCoordLocal + midOffset));

            if(midHeight > midRay){
                biOffsetCurr = midOffset;
                biRayCurr    = midRay;
            } else {
                biOffsetPrev = midOffset;
                biRayPrev    = midRay;
            }
        }

        currOffsetLocal = (biOffsetPrev + biOffsetCurr) * 0.5;
        rayHeight       = (biRayPrev + biRayCurr) * 0.5;
    }

    vec2 parallaxUV = AtlasFromLocal(texCoordLocal + currOffsetLocal);
    parallaxOffset = vec3(currOffsetLocal * texCoordAM.pq, rayHeight);

    if(PARALLAX_NORMAL_MIX_WEIGHT > 0.0001){
        normalTS = computeNormalFromHeight(parallaxUV);
    }

    return parallaxUV;
}

float getVoxelHeightTexel(ivec2 texelIndex, ivec2 tileStartPx, ivec2 tilePxSize){
    if(dis > PARALLAX_DISTANCE) return 1.0;

    ivec2 pixelCoord = tileStartPx + ivec2(wrapInt(texelIndex.x, tilePxSize.x), wrapInt(texelIndex.y, tilePxSize.y));
    float h = texelFetch(normals, pixelCoord, 0).a;

    if (h < 0.5 / 255.0) h = 1.0;

    return mix(h, 1.0,
        remapSaturate(dis, 0.5 * PARALLAX_DISTANCE, PARALLAX_DISTANCE, 0.0, 1.0)
    );
}

vec2 voxelParallaxMapping(vec3 viewVector, inout vec3 parallaxOffset, inout vec3 voxelNormalTS){
    if(dis > PARALLAX_DISTANCE){
        parallaxOffset = vec3(0.0, 0.0, 1.0);
        voxelNormalTS  = vec3(0.0, 0.0, 1.0);
        return texcoord;
    }

    ivec2 tileStartPx, tilePxSize;
    getTileInfo(tileStartPx, tilePxSize);

    vec2 localUV0 = clamp(texCoordLocal, vec2(0.0), vec2(1.0 - 1e-6));

    vec2 resF2 = vec2(tilePxSize);
    vec2 gridPos = localUV0 * resF2;

    int ix = int(floor(gridPos.x));
    int iy = int(floor(gridPos.y));

    int sx0 = wrapInt(ix, tilePxSize.x);
    int sy0 = wrapInt(iy, tilePxSize.y);

    float hCurr = getVoxelHeightTexel(ivec2(sx0, sy0), tileStartPx, tilePxSize);

    if (hCurr >= 254.5 / 255.0) {
        parallaxOffset = vec3(0.0, 0.0, 1.0);
        voxelNormalTS  = vec3(0.0, 0.0, 1.0);
        return texcoord;
    }

    const float EPS  = 1e-4;
    const float HUGE = 1e20;

    float vz = max(abs(viewVector.z), EPS);

    vec3 rayDirLocal = vec3(PARALLAX_HEIGHT * viewVector.xy / vz, -1.0);
    vec2 rayDirGrid = rayDirLocal.xy * resF2;

    int stepX = (rayDirGrid.x > 0.0) ? 1 : -1;
    int stepY = (rayDirGrid.y > 0.0) ? 1 : -1;

    float invDirX = (rayDirGrid.x != 0.0) ? (1.0 / abs(rayDirGrid.x)) : HUGE;
    float invDirY = (rayDirGrid.y != 0.0) ? (1.0 / abs(rayDirGrid.y)) : HUGE;
    float tDeltaX = invDirX;
    float tDeltaY = invDirY;

    float fracX = gridPos.x - float(ix);
    float fracY = gridPos.y - float(iy);

    float tMaxX = (rayDirGrid.x > 0.0) ? (1.0 - fracX) * invDirX : fracX * invDirX;
    float tMaxY = (rayDirGrid.y > 0.0) ? (1.0 - fracY) * invDirY : fracY * invDirY;

    float tEnter = 0.0;

    bool  hit       = false;
    float tHit      = 1.0;
    float hitHeight = 1.0;

    vec2 hitLocalUVGeo   = localUV0;
    vec2 hitLocalUVColor = localUV0;
    vec3 hitNormalTS = vec3(0.0, 0.0, 1.0);

    int sxCurr = sx0;
    int syCurr = sy0;

    for (int step = 0; step < 256; ++step) {
        if (tEnter > 1.0) break;

        float tExit = min(tMaxX, tMaxY);
        float tExitClamped = min(tExit, 1.0);

        float tTop = 1.0 - hCurr;

        if (tTop >= tEnter && tTop <= tExitClamped) {
            hit       = true;
            tHit      = tTop;
            hitHeight = hCurr;

            vec2 localHit = localUV0 + rayDirLocal.xy * tHit;
            hitLocalUVGeo   = localHit;
            hitLocalUVColor = localHit;

            hitNormalTS = vec3(0.0, 0.0, 1.0);
            break;
        }

        bool stepXaxis = (tMaxX < tMaxY);
        float tBoundary = tExit;

        if (tBoundary > 1.0) break;

        int nx = ix + (stepXaxis ? stepX : 0);
        int ny = iy + (stepXaxis ? 0    : stepY);

        int sNx = wrapInt(nx, tilePxSize.x);
        int sNy = wrapInt(ny, tilePxSize.y);

        float hNext = getVoxelHeightTexel(ivec2(sNx, sNy), tileStartPx, tilePxSize);

        float heightB = 1.0 - tBoundary;

        float hMin = min(hCurr, hNext);
        float hMax = max(hCurr, hNext);

        if (heightB >= hMin && heightB <= hMax) {
            hit       = true;
            tHit      = tBoundary;
            hitHeight = heightB;

            hitLocalUVGeo = localUV0 + rayDirLocal.xy * tHit;

            bool currIsHigh = (hCurr >= hNext);

            int highSx = currIsHigh ? sxCurr : sNx;
            int highSy = currIsHigh ? syCurr : sNy;
            hitLocalUVColor = (vec2(highSx, highSy) + 0.5) / resF2;

            int highIx = currIsHigh ? ix : nx;
            int highIy = currIsHigh ? iy : ny;
            int lowIx  = currIsHigh ? nx : ix;
            int lowIy  = currIsHigh ? ny : iy;

            int dx = lowIx - highIx;
            int dy = lowIy - highIy;

            vec3 nSide = vec3(float(dx), float(dy), 0.0);
            hitNormalTS = (nSide.x == 0.0 && nSide.y == 0.0) ? vec3(0.0, 0.0, 1.0) : normalize(nSide);
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

    if (hit) {
        parallaxOffset = vec3(AtlasFromLocal(hitLocalUVGeo) - texcoord, hitHeight);
        voxelNormalTS  = hitNormalTS;
        return AtlasFromLocal(hitLocalUVColor);
    }

    parallaxOffset = vec3(0.0, 0.0, 0.0);
    voxelNormalTS  = vec3(0.0, 0.0, 1.0);
    return texcoord;
}

float getVoxelHeight(vec2 uv){
    vec2 localUV = fract((uv - texCoordAM.st) / max(texCoordAM.pq, vec2(1e-8)));

    ivec2 tileStartPx, tilePxSize;
    getTileInfo(tileStartPx, tilePxSize);

    return getVoxelHeightTexel(ivec2(floor(localUV * vec2(tilePxSize))), tileStartPx, tilePxSize);
}

float traceParallaxShadow(vec3 parallaxOffset, vec3 lightDirTS, float shadowSoftening, bool useVoxelHeight){
    float parallaxHeight = parallaxOffset.z;
    if (parallaxHeight >= 254.5 / 255.0) return 1.0;

    const int SAMPLES = int(PARALLAX_SHADOW_SAMPLES);
    float slicesNum = float(SAMPLES);
    float dDist   = 1.0 / slicesNum;
    float dHeight = (1.0 - parallaxHeight) / slicesNum;

    vec2 dLocal = PARALLAX_HEIGHT * lightDirTS.xy / max(abs(lightDirTS.z), 1e-5) * dHeight;

    vec2 localOffset0 = parallaxOffset.xy / max(texCoordAM.pq, vec2(1e-8));

    float rayHeight = parallaxHeight + dither * dHeight;
    float dist      = dDist;

    vec2 currLocal = texCoordLocal + localOffset0 + dither * dLocal;
    float currHeight = useVoxelHeight ? getVoxelHeight(AtlasFromLocal(currLocal)) : getParallaxHeight(AtlasFromLocal(currLocal));

    float shadow = 0.0;
    for (int i = 0; i < SAMPLES && rayHeight < 1.0; ++i) {
        float bias = 12.5 / 255.0 * (1.0 - 0.8 * float(PARALLAX_TYPE));
        if (currHeight > rayHeight + bias){
            float occlusion = (currHeight - rayHeight) / dist * shadowSoftening;
            shadow = max(shadow, occlusion);
            if (shadow >= 0.99) break;
        }
        rayHeight += dHeight;
        dist      += dDist;

        currLocal += dLocal;
        currHeight = useVoxelHeight ? getVoxelHeight(AtlasFromLocal(currLocal)) : getParallaxHeight(AtlasFromLocal(currLocal));
    }

    return pow(saturate(1.0 - shadow), 2.0);
}

float ParallaxShadow(vec3 parallaxOffset, vec3 lightDirTS){
    return traceParallaxShadow(parallaxOffset, lightDirTS, PARALLAX_SHADOW_SOFTENING * 2.5, false);
}

float voxelParallaxShadow(vec3 parallaxOffset, vec3 lightDirTS){
    return traceParallaxShadow(parallaxOffset, lightDirTS, PARALLAX_SHADOW_SOFTENING * 5.0, true);
}
