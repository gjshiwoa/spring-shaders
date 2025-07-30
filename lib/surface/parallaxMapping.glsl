// 效果设计-Parallax Mapping视差映射
// https://miusjun13qu.feishu.cn/docx/G17IdiCyhoEd7XxBqJOcb3J1nie

float getParallaxHeight(vec2 uv, vec2 texGradX, vec2 texGradY){
    vec4 normalTex = textureGrad(normals, uv, texGradX, texGradY);
    if(texture(tex, uv).a == 0.0) normalTex.a = 1.0;
    return mix(1.0, normalTex.a, 1.0);
}



vec2 parallaxMapping(vec3 viewVector, vec2 texGradX, vec2 texGradY, out vec3 parallaxOffset){
    // const float slicesMin = 60.0;
    // const float slicesMax = 60.0;
    // float slicesNum = ceil(lerp(slicesMax, slicesMin, abs(dot(vec3(0, 0, 1), viewVector))));
    float slicesNum = PARALLAX_SAMPPLES;

    float dHeight = 1.0 / slicesNum;
    vec2 dUV = PARALLAX_HEIGHT * (viewVector.xy / viewVector.z) / slicesNum;

    vec2 currUVOffset = vec2(0.0);
    float rayHeight = 1.0;
    float weight = 0.0;
    float prevHeight = getParallaxHeight(offsetCoord1(vTexCoord, vTexCoordAM), texGradX, texGradY);
    float currHeight = prevHeight;
    if(prevHeight < 1.0){
        rayHeight = 1.0 - dHeight;
        currUVOffset -= dUV;
        currHeight = getParallaxHeight(offsetCoord1(vTexCoord + currUVOffset, vTexCoordAM), texGradX, texGradY);
        for(int i = 0; i < slicesNum; ++i){
            if(currHeight > rayHeight){
                break;
            }
            prevHeight = currHeight;
            currUVOffset -= dUV;
            rayHeight -= dHeight;
            currHeight = getParallaxHeight(offsetCoord1(vTexCoord + currUVOffset, vTexCoordAM), texGradX, texGradY);
        }

        float currDeltaHeight = currHeight - rayHeight;
        float prevDeltaHeight = rayHeight + dHeight - prevHeight;
        weight = currDeltaHeight / (currDeltaHeight + prevDeltaHeight);
    }

    vec2 lerpOffset = vec2(0.0);
    #ifdef PARALLAX_LERP
        lerpOffset = weight * dUV;
    #endif
    parallaxOffset = vec3(currUVOffset + lerpOffset, rayHeight);
    return offsetCoord1(vTexCoord + currUVOffset + lerpOffset, vTexCoordAM);
}



float ParallaxShadow(vec3 parallaxOffset, vec3 viewDirTS, vec3 lightDirTS, vec2 texGradX, vec2 texGradY){
    float parallaxHeight = parallaxOffset.z;
    float shadow = 0.0;

    if(parallaxHeight < 0.99){  
        const float shadowSoftening = PARALLAX_SHADOW_SOFTENING;
        float slicesNum = PARALLAX_SHADOW_SAMPPLES;
        
        float dDist = 1.0 / slicesNum;
        float dHeight = (1.0 - parallaxHeight) / slicesNum;
        vec2 dUV = PARALLAX_HEIGHT * dHeight * lightDirTS.xy / lightDirTS.z;

        float rayHeight = parallaxHeight + dHeight;
        float dist = dDist;

        float prevHeight = getParallaxHeight(offsetCoord1(vTexCoord + parallaxOffset.st, vTexCoordAM), texGradX, texGradY);
        vec2 currUVOffset = parallaxOffset.st + dUV;
        float currHeight = getParallaxHeight(offsetCoord1(vTexCoord + currUVOffset, vTexCoordAM), texGradX, texGradY);

        for (int i = 1; i < slicesNum && rayHeight < 1.0; i++){
            // #ifdef PARALLAX_LERP
                if (currHeight > rayHeight){
                    shadow = max(shadow, (currHeight - rayHeight) / dist * shadowSoftening);
                    if(1.0 == shadow) break;
                }
                rayHeight += dHeight;
                dist += dDist;
            // #else
            //     if(abs(prevHeight - currHeight) > 0.001 && currHeight > rayHeight){
            //         shadow = 1.0;
            //         break;
            //     }
            // #endif
            
            currUVOffset += dUV;
            prevHeight = currHeight;
            currHeight = getParallaxHeight(offsetCoord1(vTexCoord + currUVOffset, vTexCoordAM), texGradX, texGradY);
        }

        // #ifndef PARALLAX_LERP
        //     if(shadow <= 0.01){
        //         float prevHeight = getParallaxHeight(offsetCoord1(vTexCoord + parallaxOffset.st, vTexCoordAM), texGradX, texGradY);
        //         dUV *= 2.0;
        //         vec2 currUVOffset = parallaxOffset.st - dUV;
        //         float currHeight = getParallaxHeight(offsetCoord1(vTexCoord + currUVOffset, vTexCoordAM), texGradX, texGradY);

        //         for(int i = 0; i < 12; i++){
        //             if(abs(prevHeight - currHeight) > 0.001){
        //                 if(currHeight < prevHeight) shadow = 1.0;
        //                 break;
        //             }
        //             currUVOffset -= dUV;
        //             prevHeight = currHeight;
        //             currHeight = getParallaxHeight(offsetCoord1(vTexCoord + currUVOffset, vTexCoordAM), texGradX, texGradY);
        //         }
        //     }
        // #endif
    }

    return saturate(1.0 - shadow);
}