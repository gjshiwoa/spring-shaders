// GeForceLegend: Anisotropic filter 
// https://www.shadertoy.com/view/McVXWR
vec2 R = vec2(textureResolution);

vec2 WrapInFaceAtlas(vec2 uv){
    vec2 pq = max(texCoordAM.pq, vec2(1e-8));
    return texCoordAM.st + fract((uv - texCoordAM.st) / pq) * pq;
}

vec4 textureAniso(sampler2D T, vec2 p, vec2 oriP) {
    mat2 J = inverse(mat2(dFdx(p), dFdy(p)));
    J = transpose(J) * J;

    float d = determinant(J), t = J[0][0] + J[1][1],
          D = sqrt(abs(t*t - 4.0*d)),
          V = (t - D) / 2.0, v = (t + D) / 2.0,
          M = 1.0 / sqrt(V), m = 1.0 / sqrt(v),
          l = log2(m * R.y);

    vec2 A = M * normalize(vec2(-J[0][1], J[0][0] - V));

    vec4 sampleA = textureLod(T, oriP, 0);
    vec4 O = vec4(0.0);

    float r = ANISOTROPIC_FILTERING_QUALITY / 2.0;
    float c = 0.0;

    for (float i = -r + dither; i < r; i++){
        vec2 uvS = WrapInFaceAtlas(p + (i / (r * 2.0)) * A);
        O.rgb += textureLod(T, uvS, l).rgb;
        ++c;
    }
    return vec4(O.rgb / c, sampleA.a);
}

vec4 textureAniso2(sampler2D T, vec2 p, vec2 oriP) {
    vec2 pR = oriP * R;
    mat2 J = inverse(mat2(dFdx(pR), dFdy(pR)));
    J = transpose(J) * J;

    float d = determinant(J),
          t = (J[0][0] + J[1][1]) * 0.5,
          D = sqrt(abs(t * t - d)),
          V = t - D, v = t + D,
          l = log2(inversesqrt(v));

    vec2 A = vec2(-J[0][1], J[0][0] - V);
    A *= inversesqrt(V * dot(A, A)) / R;
    A = clamp(A, -1.0, 1.0);

    vec4 sampleA = textureLod(T, oriP, 0);
    vec4 O = vec4(0.0);

    float r = ANISOTROPIC_FILTERING_QUALITY / 2.0;
    float c = 0.0;

    for (float i = -r + dither; i < r; i++){
        vec2 uvS = WrapInFaceAtlas(p + (i / (r * 2.0)) * A);
        O.rgb += textureLod(T, uvS, l).rgb;
        ++c;
    }
    return vec4(O.rgb / c, sampleA.a);
}