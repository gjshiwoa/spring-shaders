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
    return GetParallaxCoord(parallaxOffset.xy);
}

vec3 computeNormalFromHeight(vec2 parallaxUV, vec2 texGradX, vec2 texGradY) {
    const float sampleSpanTexels = 1.5;
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

float ParallaxShadow(vec3 parallaxOffset, vec3 viewDirTS, vec3 lightDirTS, vec2 texGradX, vec2 texGradY){
    float parallaxHeight = parallaxOffset.z;
    float shadow = 0.0;

    if(parallaxHeight < 0.99){  
        const float shadowSoftening = PARALLAX_SHADOW_SOFTENING;
        float slicesNum = PARALLAX_SHADOW_SAMPPLES;
        
        float dDist = 1.0 / slicesNum;
        float dHeight = (1.0 - parallaxHeight) / slicesNum;
        vec2 dUV = vec2(textureResolution)/vec2(atlasSize) * PARALLAX_HEIGHT * dHeight * lightDirTS.xy / lightDirTS.z;

        float rayHeight = parallaxHeight + dither * dHeight;
        float dist = dDist;

        vec2 currUVOffset = parallaxOffset.st + dither * dUV;
        float currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset));

        for (int i = 1; i < slicesNum && rayHeight < 1.0; i++){
                if (currHeight > rayHeight){
                    shadow = max(shadow, (currHeight - rayHeight) / dist * shadowSoftening);
                    if(1.0 == shadow) break;
                }
                rayHeight += dHeight;
                dist += dDist;
            
            currUVOffset += dUV;
            currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset));
        }

    }

    return saturate(1.0 - shadow);
}


// 最近像素高度采样：返回 [0,1]，并保留你原来对 0 -> 1 的处理
float getVoxelHeightTexel(ivec2 texelIndex, ivec2 tileStartPx) {
    int res = textureResolution;

    int ix = texelIndex.x % res;
    int iy = texelIndex.y % res;
    if (ix < 0) ix += res;
    if (iy < 0) iy += res;

    ivec2 p = tileStartPx + ivec2(ix, iy);
    float h = texelFetch(normals, p, 0).a;

    float thresh = 0.5 / 255.0;
    if (h < thresh) h = 1.0;

    return h; // [0,1]
}
vec2 voxelParallaxMapping(vec3 viewVector, vec2 texGradX, vec2 texGradY,
                          out vec3 parallaxOffset)
{
    // ---------- 0. 解析当前 tile ----------
    vec2 tileSizeNormalized = vec2(float(textureResolution)) / vec2(atlasSize);
    vec2 tileStart = floor(texcoord / tileSizeNormalized) * tileSizeNormalized;

    // localUV0 ∈ [0,1)
    vec2 localUV0 = (texcoord - tileStart) / tileSizeNormalized;

    float resF = float(textureResolution);

    // 在 texel 网格中的连续坐标
    vec2 gridPos = localUV0 * resF;
    int ix = int(floor(gridPos.x));
    int iy = int(floor(gridPos.y));

    ivec2 atlasPxSize = atlasSize;
    ivec2 tileStartPx = ivec2(tileStart * vec2(atlasPxSize) + 0.5);

    // ---------- 1. 初始高度 ----------
    int res = textureResolution;
    int sx0 = ix % res; if (sx0 < 0) sx0 += res;
    int sy0 = iy % res; if (sy0 < 0) sy0 += res;
    float hCurr = getVoxelHeightTexel(ivec2(sx0, sy0), tileStartPx);

    // 几乎无视差则直接返回
    if (hCurr >= 254.5 / 255.0) {
        parallaxOffset = vec3(0.0, 0.0, 1.0);
        return texcoord;
    }

    // ---------- 2. 构造 (u,v,height) 空间中的射线 ----------
    float vz = max(abs(viewVector.z), 1e-4);
    // height(t) = 1 - t,  t ∈ [0,1]
    vec3 rayDirLocal = vec3(PARALLAX_HEIGHT * viewVector.xy / vz, -1.0);

    // 在 texel 网格坐标中的方向
    vec2 rayDirGrid = rayDirLocal.xy * resF;

    int stepX = (rayDirGrid.x > 0.0) ? 1 : -1;
    int stepY = (rayDirGrid.y > 0.0) ? 1 : -1;

    float invDirX = (rayDirGrid.x != 0.0) ? 1.0 / abs(rayDirGrid.x) : 1e20;
    float invDirY = (rayDirGrid.y != 0.0) ? 1.0 / abs(rayDirGrid.y) : 1e20;

    float tDeltaX = invDirX;
    float tDeltaY = invDirY;

    // 当前格子内的小数部分 [0,1)
    float fracX = gridPos.x - float(ix);
    float fracY = gridPos.y - float(iy);

    float tMaxX, tMaxY;
    if (rayDirGrid.x > 0.0)
        tMaxX = (1.0 - fracX) * invDirX;
    else
        tMaxX = fracX * invDirX;

    if (rayDirGrid.y > 0.0)
        tMaxY = (1.0 - fracY) * invDirY;
    else
        tMaxY = fracY * invDirY;

    float tEnter = 0.0;

    // 命中信息
    bool  hit      = false;
    bool  hitSide  = false;   // 区分顶面/侧面
    float tHit     = 1.0;
    float hitHeight = 1.0;
    vec2  hitLocalUV = localUV0; // 命中处在本 tile 内的 UV（0~1）

    const int VOXEL_MAX_STEPS = 128;

    for (int step = 0; step < VOXEL_MAX_STEPS; ++step) {
        if (tEnter > 1.0)
            break;

        // 当前格子的退出时间（撞到哪条格线）
        float tExit = min(tMaxX, tMaxY);
        float tExitClamped = min(tExit, 1.0);

        // ---------- A. 顶面检测（当前格子内部） ----------
        float tTop = 1.0 - hCurr; // height(t) = 1 - t <= hCurr -> t >= 1 - hCurr

        if (tTop >= tEnter && tTop <= tExitClamped) {
            hit = true;
            hitSide = false;
            tHit = tTop;
            hitHeight = hCurr;
            // 顶面：命中处的 UV 沿射线平移得到
            hitLocalUV = localUV0 + rayDirLocal.xy * tHit;
            break;
        }

        // ---------- B. 准备侧面检测：先确定将要跨哪条边界 ----------
        bool stepXaxis = (tMaxX < tMaxY);
        float tBoundary = tExit; // 此时就是跨格线的时刻

        if (tBoundary > 1.0) {
            break;
        }

        int nx = ix + (stepXaxis ? stepX : 0);
        int ny = iy + (stepXaxis ? 0 : stepY);

        // 邻居格子高度（repeat）
        int sNx = nx % res; if (sNx < 0) sNx += res;
        int sNy = ny % res; if (sNy < 0) sNy += res;
        float hNext = getVoxelHeightTexel(ivec2(sNx, sNy), tileStartPx);

        // ---------- C. 侧面检测 ----------
        float heightB = 1.0 - tBoundary;  // 光线在边界处的高度

        float hMin = min(hCurr, hNext);
        float hMax = max(hCurr, hNext);

        if (heightB >= hMin && heightB <= hMax) {
            // 撞到一堵竖直墙，这堵墙属于高度更高的那一格
            hit = true;
            hitSide = true;
            tHit = tBoundary;
            hitHeight = heightB;

            bool currIsHigh = (hCurr >= hNext);
            int highX = currIsHigh ? ix : nx;
            int highY = currIsHigh ? iy : ny;

            // 用高体素那一格的“texel 中心”作为采样 UV（体素柱整体拉高）
            hitLocalUV = (vec2(highX, highY) + vec2(0.5)) / resF;

            break;
        }

        // ---------- D. 没有命中，推进到下一个格子 ----------
        tEnter = tExit;

        if (stepXaxis) {
            tMaxX += tDeltaX;
            ix = nx;
        } else {
            tMaxY += tDeltaY;
            iy = ny;
        }

        hCurr = hNext;  // 当前高度变为新格子的高度
    }

    // ---------- 3. 结果 UV 偏移 ----------
    vec2 offsetNormalized = vec2(0.0);
    float finalHeight = 1.0;

    if (hit) {
        // 把命中处的 localUV（0~1）换算到全局 UV
        vec2 finalTexcoord = tileStart + hitLocalUV * tileSizeNormalized;
        offsetNormalized = finalTexcoord - texcoord;
        finalHeight = hitHeight;
    } else {
        finalHeight = 0.0;
        offsetNormalized = vec2(0.0);
    }

    parallaxOffset = vec3(offsetNormalized, finalHeight);
    return GetParallaxCoord(offsetNormalized);
}
