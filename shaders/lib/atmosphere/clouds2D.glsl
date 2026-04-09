vec2 fbmCloud2D(vec2 uv, int octaves, float lacunarity, float persistence) {
    vec2 value = vec2(0.0);
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;
    
    for (int i = 0; i < octaves; i++) {
        vec4 noise = textureNice(noisetex, uv * frequency, 128);
        value += noise.rg * amplitude;
        maxValue += amplitude;
        
        frequency *= lacunarity;
        amplitude *= persistence;
    }
    
    return value / maxValue;
}

vec4 cloud2D(vec3 worldDir) {
    vec2 uv = 0.1 * worldDir.xz / worldDir.y;
    
    vec2 noise = fbmCloud2D(uv, 4, 2.0, 0.5);
    
    float cloudDensity = remapSaturate(noise.r, 1.0 - noise.g, 1.0, 0.0, 1.0);
 
    vec4 color = vec4(vec3(cloudDensity), 1.0);
    
    return max(color, vec4(0.0));
}