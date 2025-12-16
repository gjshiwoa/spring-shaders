vec3 wavingPlants(vec3 mcPos, float A, float B, float yW, float ns){
    float t = frameTimeCounter;

    vec2 noiseCoord = mcPos.xz;
	noiseCoord = rotate2D(noiseCoord, 0.45);
    noiseCoord = vec2(noiseCoord.x * 3.0, noiseCoord.y);
	noiseCoord.x += frameTimeCounter * 4.0;
	noiseCoord /= ns * 16.0 * noiseTextureResolution;
    vec3 noise = textureBicubic(noisetex, noiseCoord, noiseTextureResolution).rgb;

    vec3 rand0 = texture(noisetex, mcPos.xz / (ns * 4.0 * noiseTextureResolution)).rgb;
    vec3 slow = 0.02 * sin((0.33 * B * t + rand0) * _2PI);
    vec3 wavingPos = slow;

    vec3 rand1 = texture(noisetex, (mcPos.xz + vec2(693.4271)) / (ns * 1.0 * noiseTextureResolution)).rgb;
    vec3 fast = 0.1 * sin((1.0 * B * t + rand1) * _2PI);
    fast *= remapSaturate(noise.g, 0.33 * (1.0 - rainStrength), 1.0, 0.2 * rainStrength, 1.0);
    
    wavingPos += fast;

    wavingPos.y *= yW;
    wavingPos *= A;
    mcPos += wavingPos;

    return mcPos;
}


// SimpleGrassWind 的 GLSL 实现
// 参数说明：
// additionalWPO - 额外的世界位置偏移（Vector3），通常是当前的 world position / WPO 输入
// worldVertPos  - 顶点的世界空间位置（Vector3）
// windIntensity - 风力强度（标量），控制位移幅度
// windSpeed     - 风速（标量），控制动画速度
// time          - 当前时间（秒），代替 Unity 中的 _Time.y
vec3 SimpleGrassWind(vec3 worldPos, float windIntensity, float windSpeed)
{
    // 1) 时间/速度相关
    // 与原代码等价：speed = _Time.y * 0.1 * windSpeed * -0.5
    float speed = frameTimeCounter * 0.1 * windSpeed * -0.5;

    // 2) X 方向的周期性场（大尺度）
    // 把 worldPos / 1024 用作稀疏空间周期，再加上 time 相位
    vec3 speedX = vec3(1.0, 0.0, 0.0) * speed;       // 时间相位仅在 X 分量上
    speedX = (worldPos / 1024.0) + speedX;

    // 将数值映射成 对称三角波 -> 绝对值 -> 平滑曲线
    // fract, abs 都支持 vec3 重载
    speedX = abs(fract(speedX + vec3(0.5)) * 2.0 - vec3(1.0));
    // 平滑函数 (3 - 2x) * x^2，使波形缓入缓出
    speedX = (3.0 - (2.0 * speedX)) * speedX * speedX;

    // d 取 X 分量（等价于 dot(vec3(1,0,0), speedX)）
    float d = speedX.x;

    // 3) Y/Z 混合的较细尺度场（不同频率）
    vec3 speedY = (worldPos / 200.0) + vec3(speed); // 把 speed 广播到 vec3
    speedY = abs(fract(speedY + vec3(0.5)) * 2.0 - vec3(1.0));
    speedY = (3.0 - (2.0 * speedY)) * speedY * speedY;

    // 使用向量长度把三分量合并成一个标量量度
    float distanceY = length(speedY);

    // 角度由 d + distanceY 决定，会随位置/时间变化
    float angle = d + distanceY;

    // 4) 以一个在 worldPos 下方的点为旋转中心做旋转（原代码 point0 = addWPO + (0,-10,0)）
    // 这里我们以 worldPos 为基础构造旋转中心（下方 10 单位）
    vec3 point0 = worldPos + vec3(0.0, -10.0, 0.0);

    // 从旋转中心到当前点的向量
    vec3 rel = worldPos - point0;

    // 绕 Z 轴旋转（在 X-Y 平面旋转）
    float c = cos(angle);
    float s = sin(angle);
    vec2 rotXY = vec2(
        c * rel.x - s * rel.y,
        s * rel.x + c * rel.y
    );
    // 保持 Z 分量不变
    vec3 rotatedRel = vec3(rotXY, rel.z);

    // 旋转后转换回世界坐标
    vec3 rotatedWorldPos = rotatedRel + point0;

    // 计算位移增量（旋转导致的位置变化）
    vec3 delta = rotatedWorldPos - worldPos;

    // 缩放位移并加回原世界坐标，得到最终绝对世界坐标
    float scale = windIntensity * 0.01; // 保持与原代码相同的缩放因子
    vec3 finalWorldPos = worldPos + delta * scale;

    return finalWorldPos;
}


vec3 ApplyPlantSwayWS(vec3 worldPos, float amplitude, float speed, bool swayY)
{
    // 对应 Unity: _Time.x = t/20
    const float timeScale  = 0.05;
    // 对应 Unity: worldPos.xz / _WaveControl.w（此处固定，需匹配时请外部缩放 worldPos.xz）
    const float noiseScale = 1.0;

    vec2 samplePos = worldPos.xz / noiseScale;

    // 对应 Unity: samplePos += _Time.x * -_WaveControl.xz;
    // 你要求去掉 xyz 分量后，这里用单一 speed 同时驱动采样滚动
    samplePos += (frameTimeCounter * timeScale) * vec2(-speed);

    // 对应 Unity: tex2Dlod(_Noise, float4(samplePos,0,0)).r;
    float waveSample = textureLod(depthtex2, samplePos, 0.0).r;

    // 对应 Unity: sin(waveSample * _WindControl.x/z) * (...) * _WindControl.w * v.uv.y
    // 你要求不再采用 xyz，这里用同一个 speed 驱动相位；amplitude 作为最终幅度（建议外部把“顶端权重”乘进去）
    float offset = sin(waveSample * speed) * amplitude;

    worldPos.x += offset;
    worldPos.z += offset;

    if (swayY)
        worldPos.y += offset;

    return worldPos;
}