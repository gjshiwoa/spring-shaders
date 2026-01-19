// 搜狐畅游引擎部: 渲染TA实战：模型草美术效果分享
// https://zhuanlan.zhihu.com/p/609035535

vec3 wavingPlants(vec3 mcPos, float A, float B, float yW, float ns){
    float t = frameTimeCounter;

    vec3 rand0 = texture(noisetex, mcPos.xz / (ns * 4.0 * noiseTextureResolution)).rgb;
    vec3 slow = 0.02 * sin((0.33 * B * t + rand0) * _2PI);
    vec3 wavingPos = slow;

    vec3 rand1 = texture(noisetex, (mcPos.xz + vec2(693.4271)) / (ns * 1.0 * noiseTextureResolution)).rgb;
    vec3 fast = 0.1 * sin((1.0 * B * t + rand1) * _2PI);

    vec2 noiseCoord = mcPos.xz;
	noiseCoord = rotate2D(noiseCoord, 0.45);
    noiseCoord = vec2(noiseCoord.x * 3.0, noiseCoord.y);
	noiseCoord.x += frameTimeCounter * 32.0;
	noiseCoord /= ns * 64.0 * noiseTextureResolution;
    vec3 noise = textureBicubic(noisetex, noiseCoord, noiseTextureResolution).rgb;
    fast *= remapSaturate(noise.g, 0.33 * (1.0 - rainStrength), 1.0, 0.2 * rainStrength, 1.0);
    
    wavingPos += fast;

    wavingPos.y *= yW;
    wavingPos *= A;
    mcPos += wavingPos;

    return mcPos;
}