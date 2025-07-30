vec3 wavingPlants(vec3 vMcPos, float A, float B, float Da, float yW){
    float t = frameTimeCounter; // 单位 秒

    // 值控制整齐度，越大越整齐
    vec2 noiseCoord = vMcPos.xz / (4.0 * noiseTextureResolution);
    vec3 noise = texture(noisetex, noiseCoord).rgb;
    // 使用noise，用于使数值随时间无规律地忽高忽低，其中的值为控制变化秒数
    vec2 noiseCoordT = vec2(t / (5.0 * noiseTextureResolution), 0.0);
    float noiseT = texture(noisetex, noiseCoordT).r;

    // 通过sin函数，使数值随时间有规律地忽高忽低，且不同位置初始值不同
    float nt = sin(((1.0 / 16.0) * t + noise.b) * _2PI) * 0.5 + 0.5;
    nt = mix(noiseT, nt, 0.4);
    nt = saturate(max(max(0.1, nt), 0.4 * rainStrength));
    A *= nt * (1.0 + 0.5 * rainStrength);

    B = _2PI / B;
    B *= 1.0 + 0.5 * step(0.01, rainStrength);

    vec3 C = vec3(_2PI) * noise.rgb;

    vec3 D = vec3(0.0);
    
    vMcPos.x +=  A * sin(B * t + C.r) + D.x;
    vMcPos.z +=  A * sin(B * t + C.g) + D.z;
    vMcPos.y += (A * sin(B * t + C.b) + D.y) * yW;

    return vMcPos;
}