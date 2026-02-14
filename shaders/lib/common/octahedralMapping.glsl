#ifndef OCTAHEDRAL_MAPPING_GLSL
#define OCTAHEDRAL_MAPPING_GLSL
vec2 directionToOctahedral(vec3 direction) {
    direction = normalize(direction);
    
    float sum = abs(direction.x) + abs(direction.y) + abs(direction.z);
    vec3 octahedron = direction / sum;
    
    if (octahedron.z < 0.0) {
        vec2 wrapped = (1.0 - abs(octahedron.yx)) * sign(octahedron.xy);
        octahedron.xy = wrapped;
    }
    
    return octahedron.xy * 0.5 + 0.5;
}

vec3 octahedralToDirection(vec2 uv) {
    vec3 position = vec3(2.0 * (uv - 0.5), 0.0);
    
    vec2 absolute = abs(position.xy);
    position.z = 1.0 - absolute.x - absolute.y;
    
    if (position.z < 0.0) {
        position.xy = sign(position.xy) * (1.0 - absolute.yx);
    }
    
    return normalize(position);
}

vec4 sampleOctahedralTexture(sampler2D tex, vec3 direction) {
    vec2 uv = directionToOctahedral(direction);
    
    ivec2 texSize = textureSize(tex, 0);
    vec2 invTexSize = 1.0 / vec2(texSize);
    
    if (any(lessThanEqual(uv, invTexSize)) || any(greaterThanEqual(uv, 1.0 - invTexSize))) {
        uv = uv * vec2(texSize) - 0.5;
        ivec2 baseCoord = ivec2(floor(uv));
        vec2 fractionalPart = uv - vec2(baseCoord);
        
        return texture(tex, directionToOctahedral(direction));
    } else {
        return texture(tex, uv);
    }
}

vec2 cubemapToOctahedral(int face, vec2 faceUV) {
    vec3 direction;
    vec2 coord = faceUV * 2.0 - 1.0;
    
    if (face == 0) {
        direction = vec3(1.0, -coord.y, -coord.x);
    } else if (face == 1) {
        direction = vec3(-1.0, -coord.y, coord.x);
    } else if (face == 2) {
        direction = vec3(coord.x, 1.0, coord.y);
    } else if (face == 3) {
        direction = vec3(coord.x, -1.0, -coord.y);
    } else if (face == 4) {
        direction = vec3(coord.x, -coord.y, 1.0);
    } else {
        direction = vec3(-coord.x, -coord.y, -1.0);
    }
    
    return directionToOctahedral(normalize(direction));
}

#endif