// Morgan McGuire and Michael Mara, Efficient GPU Screen-Space Ray Tracing, Journal of Computer Graphics Techniques (JCGT), vol. 3, no. 4, 73-85, 2014

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
    const float nearPlaneZ = -0.001;
    const float maxSteps = 50.0;
    const float maxRayTraceDistance = 50.0;
    float stride = 3.0 * max(1.0/uWidth, 1.0/uHeight);
    const float jitterFraction = 1.0;
    const float csZThickness = 0.0;

    // Transform into camera space 
    vec3 csOrigin = vec3(vViewMatrix * vec4(ori, 1.0));
    vec3 csDirection = normalize(vec3(vViewMatrix * vec4(dir, 0.0)));

    // Clip ray to a near plane in 3D
    float rayLength = ((csOrigin.z + csDirection.z * maxRayTraceDistance) > nearPlaneZ) ? 
                    (nearPlaneZ - csOrigin.z) / csDirection.z : maxRayTraceDistance;
    vec3 csEndPoint = csOrigin + csDirection * rayLength;

    // Project into screen space
    vec4 H0 = vProjectMatrix * vec4(csOrigin, 1.0);
    vec4 H1 = vProjectMatrix * vec4(csEndPoint, 1.0);
    float k0 = 1.0 / H0.w;
    float k1 = 1.0 / H1.w;

    // Switch the original points to values that interpolate linearly in 2D
    vec3 Q0 = csOrigin * k0; 
    vec3 Q1 = csEndPoint * k1;

    // Screen-space endpoints
    vec2 P0 = vec2(H0.xy * k0) * 0.5 + 0.5;
    vec2 P1 = vec2(H1.xy * k1) * 0.5 + 0.5;

    vec2 hitPixel = vec2(-1.0, -1.0);

    // If the line is degenerate, make it cover at least one pixel
    // to avoid handling zero-pixel extent as a special case later
    P1 += vec2((dot(P0 - P1, P0 - P1) < 0.0001) ? 0.01 : 0.0);

    vec2 delta = P1 - P0;

    // Permute so that the primary iteration is in x to reduce
    // large branches later
    bool permute = false;
	if (abs(delta.x) < abs(delta.y)) 
    {
		// More-vertical line. Create a permutation that swaps x and y in the output
		permute = true;
        // Directly swizzle the inputs
		delta = delta.yx;
		P1 = P1.yx;
		P0 = P0.yx;        
	}

    // From now on, "x" is the primary iteration direction and "y" is the secondary one
    float stepDirection = sign(delta.x);
    float invdx = stepDirection / delta.x;
    vec2 dP = vec2(stepDirection, invdx * delta.y);

    // Track the derivatives of Q and k
    vec3 dQ = (Q1 - Q0) * invdx;
    float dk = (k1 - k0) * invdx;

    // Scale derivatives by the desired pixel stride
	dP *= stride; 
    dQ *= stride; 
    dk *= stride;

    // Offset the starting values by the jitter fraction
	P0 += dP * jitterFraction; 
    Q0 += dQ * jitterFraction; 
    k0 += dk * jitterFraction;

    // Slide P from P0 to P1, (now-homogeneous) Q from Q0 to Q1, and k from k0 to k1
    vec3 Q = Q0;
    float k = k0;

	// We track the ray depth at +/- 1/2 pixel to treat pixels as clip-space solid 
	// voxels. Because the depth at -1/2 for a given pixel will be the same as at 
	// +1/2 for the previous iteration, we actually only have to compute one value 
	// per iteration.
	float prevZMaxEstimate = csOrigin.z;
    float stepCount = 0.0;
    float rayZMax = prevZMaxEstimate, rayZMin = prevZMaxEstimate;
    float sceneZMax = csOrigin.z + 1e4;

    // P1.x is never modified after this point, so pre-scale it by 
    // the step direction for a signed comparison
    float end = P1.x * stepDirection;

    // We only advance the z field of Q in the inner loop, since
    // Q.xy is never used until after the loop terminates.
    vec2 P = P0;
    for(int i = 0;i < int(maxSteps); ++i)
    {
        if(P.x < 0.0 || P.x > 1.0 || P.y < 0.0 || P.y > 1.0)
        {
            break;
        }

        if(!(((P.x * stepDirection) <= end) && 
             ((rayZMax < sceneZMax - csZThickness) ||
              (rayZMin > sceneZMax)) &&
             (sceneZMax != 0.0)))
        {
            break;
        }

        hitPixel = permute ? P.yx : P;
        // The depth range that the ray covers within this loop
        // iteration.  Assume that the ray is moving in increasing z
        // and swap if backwards.  Because one end of the interval is
        // shared between adjacent iterations, we track the previous
        // value and then swap as needed to ensure correct ordering
        rayZMin = prevZMaxEstimate;

        // Compute the value at 1/2 pixel into the future
        rayZMax = (dQ.z * 0.5 + Q.z) / (dk * 0.5 + k);
        prevZMaxEstimate = rayZMax;

        if (rayZMin > rayZMax) 
        { 
            // Swap
            float tmp = rayZMin;
            rayZMin = rayZMax;
            rayZMax = tmp;
        }

        // Camera-space z of the background
        sceneZMax = -texture2D(uGDepth, hitPixel).r;

        P += dP, Q.z += dQ.z, k += dk, stepCount += 1.0;
    }

    Q.xy += dQ.xy * stepCount;
    hitPos = Q * (1.0 / k);

    return (rayZMax >= sceneZMax - csZThickness) && (rayZMin <= sceneZMax);
}