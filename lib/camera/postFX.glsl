vec3 vignette(vec3 color) {
    float dist = distance(texcoord, vec2(0.5));
    dist = max(1e-4, dist * VIGNETTE_SCALE + VIGNETTE_OFFSET);
    dist = pow(dist, VIGNETTE_POWER);
    dist = smoothstep(0.0, 1.0, dist);
    return color.rgb * (1.0 - dist);
}

vec3 applyLetterbox(vec3 color, float letterboxSize) {
    if (texcoord.y < letterboxSize || texcoord.y > 1.0 - letterboxSize) {
        return BLACK;
    }
    return color;
}
