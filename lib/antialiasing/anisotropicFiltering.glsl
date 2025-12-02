// GeForceLegend: Anisotropic filter 
// https://www.shadertoy.com/view/McVXWR
vec2 R = vec2(textureResolution);

vec4 textureAniso(sampler2D T, vec2 p, vec2 oriP) {
    mat2 J = inverse(mat2(dFdx(p),dFdy(p)));       // dFdxy: pixel footprint in texture space
    J = transpose(J)*J;                            // quadratic form
    float d = determinant(J), t = J[0][0]+J[1][1], // find ellipse: eigenvalues, max eigenvector
          D = sqrt(abs(t*t-4.*d)),                 // abs() fix a bug: in weird view angles 0 can be slightly negative
          V = (t-D)/2., v = (t+D)/2.,                     // eigenvalues. ( ATTENTION: not sorted )
          M = 1./sqrt(V), m = 1./sqrt(v), l =log2(m*R.y); // = 1./radii^2
  //if (M/m>16.) l = log2(M/16.*R.y);                     // optional
    vec2 A = M * normalize(vec2( -J[0][1] , J[0][0]-V )); // max eigenvector = main axis

    vec4 sampleA = textureLod(T, p, 0);
    vec4 O = vec4(0);

    float r = ANISOTROPIC_FILTERING_QUALITY / 2.0;
    float c = 0.0;
    for (float i = -r + dither; i < r; i++){                       // sample x16 along main axis at LOD min-radius
        O.rgb += textureLod(T, GetParallaxCoord((i/(r*2.0))*A, p, textureResolution), l).rgb;
        ++c;
    }
    return vec4(O.rgb/c, sampleA.a);
}

vec4 textureAniso2(sampler2D T, vec2 p, vec2 oriP) {
    vec2 pR = oriP * R;
    mat2 J = inverse(mat2(dFdx(pR),dFdy(pR))); // Changed from coord space to texel space
    J = transpose(J)*J;
    float d = determinant(J),
          t = (J[0][0]+J[1][1]) * 0.5,         // No need for 3 extra multiply
          D = sqrt(abs(t * t - d)),
          V = t - D, v = t + D,
          l = log2(inversesqrt(v));            // As switched to texel space, resolution is already multiplied
    vec2 A = vec2(-J[0][1], J[0][0] - V );     // Merged `M` with the inversesqrt() in normalize()
    A *= inversesqrt(V * dot(A, A)) / R;       // Convert back to coord space
    A = clamp(A, -1.0, 1.0);

    vec4 sampleA = textureLod(T, p, 0);
    vec4 O = vec4(0.0);

    float r = ANISOTROPIC_FILTERING_QUALITY / 2.0;
    float c = 0.0;
    for (float i = -r + dither; i < r; i++){
        O.rgb += textureLod(T, GetParallaxCoord((i/(r*2.0))*A, p, textureResolution), l).rgb;
        ++c;
    }
    return vec4(O.rgb/c, sampleA.a);
}