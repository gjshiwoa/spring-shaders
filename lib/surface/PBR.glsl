vec4 getSpecularTex(vec2 uv){
#ifdef GBF
    vec4 specularMap = unpack2x16To4x8(texture(gaux1, uv).ba);
#else
    vec4 specularMap = unpack2x16To4x8(texture(colortex4, uv).ba);
#endif
    return specularMap;
}

#ifdef FSH
struct MaterialParams {
    float smoothness;
    float roughness;
    float metalness;
    float porosity;
    float subsurfaceScattering;
    float emissiveness;
    vec3 N;
    vec3 K;
};

MaterialParams MapMaterialParams(vec4 specularMap) {
    MaterialParams params;

    params.smoothness = specularMap.r;
    float perceptual_roughness = 1.0 - params.smoothness;
    params.roughness = perceptual_roughness * perceptual_roughness;
    
    params.metalness = specularMap.g;
    if(params.metalness > 0.9){
        int metalType = int(specularMap.g * 255 + 0.1);
        if (metalType == 230) { // Iron
            params.N = vec3(2.9114, 2.9497, 2.5845);
            params.K = vec3(3.0893, 2.9318, 2.7670);
        } else if (metalType == 231) { // Gold
            params.N = vec3(0.18299, 0.42108, 1.3734);
            params.K = vec3(3.4242, 2.3459, 1.7704);
        } else if (metalType == 232) { // Aluminum
            params.N = vec3(1.3456, 0.96521, 0.61722);
            params.K = vec3(7.4746, 6.3995, 5.3031);
        } else if (metalType == 233) { // Chrome
            params.N = vec3(3.1071, 3.1812, 2.3230);
            params.K = vec3(3.3314, 3.3291, 3.1350);
        } else if (metalType == 234) { // Copper
            params.N = vec3(0.27105, 0.67693, 1.3164);
            params.K = vec3(3.6092, 2.6248, 2.2921);
        } else if (metalType == 235) { // Lead
            params.N = vec3(1.9100, 1.8300, 1.4400);
            params.K = vec3(3.5100, 3.4000, 3.1800);
        } else if (metalType == 236) { // Platinum
            params.N = vec3(2.3757, 2.0847, 1.8453);
            params.K = vec3(4.2655, 3.7153, 3.1365);
        } else if (metalType == 237) { // Silver
            params.N = vec3(0.15943, 0.14512, 0.13547);
            params.K = vec3(3.9291, 3.1900, 2.3808);
        } else {
            params.N = vec3(1.0);
            params.K = vec3(0.0);
        }
    }
    
    params.porosity = 0.0;
    params.subsurfaceScattering = 0.0;
    if(specularMap.b < 0.251) {
        params.porosity = smoothstep(0.0, 64.0/255.0, specularMap.b);
    } else {
        params.subsurfaceScattering = smoothstep(65.0/255.0, 1.0, specularMap.b);
    }
    
    params.emissiveness = specularMap.a;
    if(params.emissiveness * 255.0 > 254.3) {
        params.emissiveness = 0.0;
    }
    
    return params;
}

float D_GGX(float NoH, float a){
    float a2 = a * a;
    float f = (NoH * NoH) * (a2 - 1.0) + 1.0;
    return a2 / (PI * f * f + 0.000001);
}

float GGX(float NoV, float k){
    return NoV / (NoV * (1.0 - k) + k + + 0.000001);
}

float G_Smith(float NoV, float NoL, float roughness){
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return GGX(NoV, k) * GGX(NoL, k);
}

vec3 F_Schlick(float VoH, vec3 F0){
    float f = pow(1.0 - VoH, 5.0);
    return F0 + (1.0 - F0) * f;
}

vec3 ComplexFresnel(float cosTheta, vec3 N, vec3 K) {
    vec3 nMinusOneSq = (N - 1.0) * (N - 1.0);
    vec3 kSq = K * K;
    vec3 numerator = nMinusOneSq + kSq;

    vec3 nPlusOneSq = (N + 1.0) * (N + 1.0);
    vec3 denominator = nPlusOneSq + kSq;

    vec3 F0 = numerator / denominator;

    return F0;
}

mat2x3 CalculatePBR(vec3 viewDir, vec3 N, vec3 L, vec3 albedo, MaterialParams params) {
    vec3 V = -viewDir;
    vec3 H = normalize(L + V);
    
    float VoH = saturate(dot(V, H));
    float NoH = saturate(dot(N, H));
    float NoV = saturate(dot(N, V));
    float NoL = saturate(dot(N, L));
    
    vec3 F0 = vec3(params.metalness);
    F0 = mix(vec3(0.04), albedo, params.metalness);

    vec3 F = F_Schlick(VoH, F0);

    float D = D_GGX(NoH, params.roughness);
    float G = G_Smith(NoV, NoL, params.roughness);
    
    vec3 specular = D * F * G / (4.0 * NoV * NoL + 0.001);
    
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - params.metalness;   

    return mat2x3(kD * albedo / PI , specular); 
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness){
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 BRDF_Diffuse(vec3 normalV, vec3 viewDir, vec3 albedo, MaterialParams params){
	vec3 F0 = mix(vec3(0.04), vec3(0.9), params.metalness);
	vec3 kS = fresnelSchlickRoughness(max(dot(normalV, -viewDir), 0.0), F0, params.roughness); 
	vec3 kD = 1.0 - kS;
    // kD *= 1.0 - params.metalness;
    // vec3 kD = vec3(1.0 - params.metalness);
    vec3 BRDF = kD * albedo / PI;
    
	return BRDF;
}

vec3 reflectPBR(vec3 viewDir, vec3 N, vec3 L, MaterialParams params) {
    vec3 V = -viewDir;
    vec3 H = normalize(L + V);
    
    float VoH = saturate(dot(V, H));
    float NoH = saturate(dot(N, H));
    float NoV = saturate(dot(N, V));
    float NoL = saturate(dot(N, L));
    
    vec3 F0 = vec3(params.metalness);
    vec3 F = F_Schlick(VoH, F0);
    float D = D_GGX(NoH, params.roughness);
    float G = G_Smith(NoV, NoL, params.roughness);
    
    vec3 specular = D * F * G / (4.0 * NoV * NoL + 0.001);

    return specular; 
}

vec3 EnvDFGLazarov(vec3 specularColor, float gloss, float ndotv){
    vec4 p0 = vec4( 0.5745, 1.548, -0.02397, 1.301 );
    vec4 p1 = vec4( 0.5753, -0.2511, -0.02066, 0.4755 );
    vec4 t = gloss * p0 + p1;
    float bias = saturate( t.x * min( t.y, exp2( -7.672 * ndotv ) ) + t.z );
    float delta = saturate( t.w );
    float scale = delta - bias;
    bias *= saturate( 50.0 * specularColor.y );
    return specularColor * scale + bias;
}

#endif