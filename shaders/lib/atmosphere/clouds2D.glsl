float cloud2DWorley(vec2 p) {
	vec2 cell = floor(p);
	vec2 localPos = fract(p);
	float minDist = 1.0;

	for(int y = -1; y <= 1; y++) {
		for(int x = -1; x <= 1; x++) {
			vec2 offset = vec2(x, y);
			vec2 point = rand2_3(cell + offset).xy * 0.5 + 0.5;
			minDist = min(minDist, length(offset + point - localPos));
		}
	}

	return saturate(minDist);
}

float cloud2DPerlin(vec2 p) {
	return simplex2d(p) * 0.5 + 0.5;
}

float sampleCloud2D(vec2 p) {
	float frequency = CLOUDS_2D_SCALE;
	float weight = 1.0;
	float time = CLOUDS_2D_SPEED * frameTimeCounter;

	p -= (1.0 - cloud2DWorley(p * frequency)) * 0.001;

	float noise = 0.0;
	float totalWeight = 0.0;
	for(int i = 0; i < 6; i++) {
		noise += cloud2DPerlin(p * frequency + time) * weight;
		totalWeight += weight;

		frequency *= 2.5;
		weight *= 0.5;
		time *= 1.1;
	}

	return noise / totalWeight;
}

vec3 getCloud2DPhase(vec3 dir) {
	float VoL = dot(dir, sunWorldDir);
	vec3 forwardPhase = phasefunc_KleinNishina(VoL, vec3(0.25));
	vec3 backPhase = vec3(0.0);
	return saturate((forwardPhase + backPhase) * 4.0 * PI);
}

vec4 renderCloud2D(vec3 pos, vec3 dir, float occluderTransmittance) {
	float cloudRadius = earth_r + CLOUDS_2D_HEIGHT;
	vec2 earthHit = RaySphereIntersection(pos, dir, vec3(0.0), earth_r);
	if(pos.y < cloudRadius && earthHit.x > 0.0) return vec4(vec3(0.0), 1.0);

	vec2 cloudHit = RaySphereIntersection(pos, dir, vec3(0.0), cloudRadius);
	float lenToCloud = pos.y < cloudRadius ? cloudHit.y : cloudHit.x;
	if(lenToCloud < 0.0 || (earthHit.x > 0.0 && earthHit.x < lenToCloud)) return vec4(vec3(0.0), 1.0);

	vec3 cloudPos = pos + dir * lenToCloud;
	vec2 samplePos = cloudPos.xz / cloudRadius;
	float cloudNoise = sampleCloud2D(samplePos);
	float cloudShape = remapSaturate(cloudNoise, 1.0 - CLOUDS_2D_COVERAGE, 1.0, 0.0, 1.0);
	cloudShape = smoothstep(0.0, 1.0, cloudShape);
	float cloudDensity = cloudShape * CLOUDS_2D_DENSITY * (1.0 - 0.66 * rainStrength);
	if(cloudDensity < 1e-5) return vec4(vec3(0.0), 1.0);

	float viewFade = exp(-lenToCloud / CLOUDS_2D_FADE_DISTANCE);
	float alpha = saturate(cloudDensity * viewFade * occluderTransmittance);
	vec3 phase = getCloud2DPhase(dir);
	vec3 lighting = mix(sunColor * phase, skyColor, CLOUDS_2D_SKY_MIX);
	vec3 scattering = lighting * alpha * CLOUDS_2D_BRIGHTNESS * (1.0 - 0.5 * isNightS);

	return vec4(scattering, 1.0 - alpha);
}
