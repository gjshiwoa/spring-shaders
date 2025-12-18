// Zavie: Rainier mood 
// https://www.shadertoy.com/view/ldfyzl

float ripple_profile(float d){
    float band = smoothstep(RIPPLE_RING_INNER, RIPPLE_RING_OUTER, d)
               * smoothstep(0.0, RIPPLE_RING_OUTER, d);
    return sin(RIPPLE_WAVE_FREQ * d) * band;
}

vec2 ripple_gradient_uv(vec2 uv, float time){
    vec2 p0 = floor(uv);
    vec2 grad = vec2(0.0);

    for (int j = -RIPPLE_MAX_RADIUS; j <= RIPPLE_MAX_RADIUS; ++j){
        for (int i = -RIPPLE_MAX_RADIUS; i <= RIPPLE_MAX_RADIUS; ++i){
            vec2 pi = p0 + vec2(float(i), float(j));
            vec2 hsh = pi;

            vec3 rand = rand2_3(hsh);
            vec2 center = pi + rand.xy;

            float t = fract(RIPPLE_TIME_SPEED * time + rand.z);

            vec2 v = center - uv;
            float lenV = length(v);

            vec2 dir = (lenV > 1e-6) ? (v / lenV) : vec2(0.0);

            float travel = (float(RIPPLE_MAX_RADIUS) + 1.0) * t;

            float d = lenV - travel;

            float h  = 0.001;
            float p1 = ripple_profile(d - h);
            float p2 = ripple_profile(d + h);
            float dp_dd = (p2 - p1) / (2.0 * h);

            float fade = (1.0 - t);
            fade *= fade;

            grad += 0.5 * dir * dp_dd * fade;
        }
    }

    float denom = float((RIPPLE_MAX_RADIUS * 2 + 1) * (RIPPLE_MAX_RADIUS * 2 + 1));
    grad /= denom;

    return grad;
}

vec2 RippleSlopeXZ_WS(vec2 posXZ, float dis, float wetFactor){
    vec2 uv = posXZ * RIPPLE_UV_SCALE;

    vec2 g_uv = ripple_gradient_uv(uv, frameTimeCounter);

    float dHdx = g_uv.x * RIPPLE_UV_SCALE * RIPPLE_NORMAL_STRENGTH;
    float dHdz = g_uv.y * RIPPLE_UV_SCALE * RIPPLE_NORMAL_STRENGTH;

    vec2 slope = vec2(dHdx, dHdz) 
                * remapSaturate(dis, RIPPLE_DISTANCE * 0.66, RIPPLE_DISTANCE, 1.0, 0.0)
                * wetFactor;

    return slope;
}

vec3 RippleNormalWS(vec2 posXZ, float dis, float wetFactor){
    vec2 slope = RippleSlopeXZ_WS(posXZ, dis, wetFactor);
    return normalize(vec3(-slope.x, 1.0, -slope.y));
}

vec3 RipplePerturbNormalWS(vec2 posXZ, vec3 baseNWS, float dis, float wetFactor){
    vec3 N = normalize(baseNWS);
    if(dis > RIPPLE_DISTANCE) return N;

    vec2 slope = RippleSlopeXZ_WS(posXZ, dis, wetFactor);

    vec3 worldX = vec3(1.0, 0.0, 0.0);
    vec3 worldZ = vec3(0.0, 0.0, 1.0);

    vec3 Tx = worldX - N * dot(N, worldX);
    float lx = length(Tx);
    if (lx < 1e-4) {
        Tx = worldZ - N * dot(N, worldZ);
        lx = length(Tx);
    }
    Tx = (lx > 1e-6) ? (Tx / lx) : vec3(1.0, 0.0, 0.0);

    vec3 Tz = worldZ - N * dot(N, worldZ);
    Tz = Tz - Tx * dot(Tx, Tz);
    float lz = length(Tz);
    if (lz < 1e-4){
        Tz = normalize(cross(N, Tx));
    }else{
        Tz /= lz;
    }

    vec3 nWS = normalize(N - slope.x * Tx - slope.y * Tz);

    return nWS;
}
