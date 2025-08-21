vec3 drawSun(vec3 worldDir){
    float wds = dot(worldDir, sunWorldDir);
    float mixAmount = wds > (1.0 - SUN_RADIUS) ? 1.0 : 0.0;
    vec3 color = sunColor * SUN_BRIGHTNESS;
    if(isEyeInWater == 1) color *= (0.001 * eyeBrightnessSmooth.y / 240.0 + 0.01);
    return mix(BLACK, color, mixAmount);
}

// piyushslayer: Happy 2020!
// https://www.shadertoy.com/view/tt3GRN
vec3 drawMoon(vec3 worldDir){
    float moon = smoothstep(.030, .025, length(worldDir - moonWorldDir));
    mat3 offsetMat = rotate3D(vec3(1.0, 0.0, 0.0), _2PI * -0.00150) * rotate3D(vec3(0.0, 0.0, 1.0), _2PI * 0.00) * rotate3D(vec3(0.0, 1.0, 0.0), _2PI * 0.00150);
    moon *= 1.0 - smoothstep(.035, .030, length(offsetMat * worldDir - moonWorldDir));
    vec3 moonColor = IncomingLight_N * moon * MOON_BRIGHTNESS;
    return moonColor;
}


// a_codecat：shader实现星空效果
// https://blog.csdn.net/a_codecat/article/details/127600739
vec3 drawStars(vec3 worldDir){
    vec3 uv = worldDir;
    uv *= STARS_DENSITY;
    vec3 ipos = floor(uv);
    vec3 fpos = fract(uv);
    vec3 targetPoint = rand3_3(ipos + sin(frameTimeCounter * 0.5) * 0.00005);

    float dist = length(fpos - targetPoint);
    float size = STARS_SIZE;
    float isStar = 1.0 - step(size, dist);

    return STARS_BRIGHTNESS * IncomingLight_N * isStar;
}

vec3 drawCelestial(vec3 worldDir, float transmittance, bool stars){
    vec3 celestialColor = BLACK;
    if(getLuminance(sunColor) > 0.0) celestialColor += drawSun(worldDir);
    if(isNight > 0.0) {
        #ifdef STARS
            if(stars) celestialColor += drawStars(worldDir);
        #endif
        celestialColor += drawMoon(worldDir);
    }
    
    float mixAmount = saturate((worldDir.y - 0.02) * 5);   // 遮罩
    mixAmount *= fastPow(transmittance, 10);
    mixAmount *= 1.0 - rainStrength;

    return mix(BLACK, celestialColor, mixAmount);
}