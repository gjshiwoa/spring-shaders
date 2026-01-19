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
        int metalType = int(round(specularMap.g * 255) + 0.01);
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

    #ifndef USE_OLD_PBR
        if(specularMap.b < 0.251) {
            params.porosity = smoothstep(0.0, 64.0/255.0, specularMap.b);
        } else {
            params.subsurfaceScattering = smoothstep(65.0/255.0, 1.0, specularMap.b);
        }

        params.emissiveness = specularMap.a;
        if(params.emissiveness * 255.0 > 254.1) {
            params.emissiveness = 0.0;
        }
    #endif

    return params;
}

float D_GGX(float NoH, float a){
    float a2 = a * a;
    float f = (NoH * NoH) * (a2 - 1.0) + 1.0;
    return a2 / (PI * f * f + 0.000001);
}

float SchlickGGX_UE4(float NoX, float roughness){
    float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    return NoX / (NoX * (1.0 - k) + k + 0.000001);
}

float SchlickGGX(float NoV, float NoL, float roughness){
    return SchlickGGX_UE4(NoV, roughness) * SchlickGGX_UE4(NoL, roughness);
}

float GGX(float NoV, float k){
    return NoV / (NoV * (1.0 - k) + k + 0.000001);
}

float G_Smith(float NoV, float NoL, float roughness){
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return GGX(NoV, k) * GGX(NoL, k);
}

vec3 F_Schlick(float VoH, vec3 F0){
    float f = pow(1.0 - VoH, 5.0);
    return F0 + (1.0 - F0) * f;
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness){
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 BurleyDiffuse(vec3 kD, vec3 albedo, float roughness, float NoL, float NoV, float VoH){
    float Fd90 = 0.5 + 2.0 * roughness * VoH * VoH;
    float fresnelL = pow(saturate(1.0 - NoL), 5.0);
    float fresnelV = pow(saturate(1.0 - NoV), 5.0);
    float diffuseTerm = (1.0 + (Fd90 - 1.0) * fresnelL) * (1.0 + (Fd90 - 1.0) * fresnelV);
    return kD * albedo * (1.0 / PI) * diffuseTerm;
}

vec3 Diffuse_OrenNayar(vec3 DiffuseColor, float Roughness, float NoV, float NoL, float VoH) {
    float a = Roughness * Roughness;
    float s = a;
    float s2 = s * s;
    float VoL = 2.0 * VoH * VoH - 1.0;
    float Cosri = VoL - NoV * NoL;
    float C1 = 1.0 - 0.5 * s2 / (s2 + 0.33);
    float C2 = 0.45 * s2 / (s2 + 0.09) * Cosri * (Cosri >= 0.0 ? 1.0 / max(NoL, NoV) : 1.0);
    return DiffuseColor / PI * (C1 + C2) * (1.0 + Roughness * 0.5);
}

vec3 ComplexFresnel(vec3 N, vec3 K) {
    vec3 nMinusOneSq = (N - 1.0) * (N - 1.0);
    vec3 nPlusOneSq = (N + 1.0) * (N + 1.0);
    vec3 kSq = K * K;

    vec3 numerator = nMinusOneSq + kSq;
    vec3 denominator = nPlusOneSq + kSq;

    vec3 F0 = numerator / denominator;

    return F0;
}

mat2x3 CalculatePBR(vec3 viewDir, vec3 N, vec3 L, vec3 albedo, MaterialParams params) {
    vec3 V = -viewDir;
    vec3 H = normalize(L + V);
    
    float VoH = saturate(dot(V, H));
    float NoH = saturate(dot(N, H));
    float NoV = max(saturate(dot(N, V)), 1e-2);
    float NoL = saturate(dot(N, L));
    
    vec3 F0 = vec3(params.metalness);
    F0 = mix(vec3(0.04), albedo, params.metalness);

    vec3 F = F_Schlick(VoH, F0);

    float D = D_GGX(NoH, max(0.02, params.roughness));
    float G = SchlickGGX(NoV, NoL, params.roughness);
    
    vec3 specular = vec3(D * F * G) / (4.0 * NoV * NoL + 0.001);
    specular *= 1.0 - 0.9 * rainStrength;
    
    F0 = mix(vec3(0.04), vec3(0.96), params.metalness);
    vec3 kS = fresnelSchlickRoughness(VoH, F0, params.roughness);
    vec3 kD = vec3(1.0) - kS;
    
    // vec3 diffuse = BurleyDiffuse(kD, albedo, params.roughness, NoL, NoV, VoH);
    // vec3 diffuse = Diffuse_OrenNayar(kD * albedo, params.roughness, NoV, NoL, VoH);
    vec3 diffuse = kD * albedo / PI;

    return mat2x3(diffuse, specular); 
}





vec3 reflectDiffuse(vec3 viewDir, vec3 N, vec3 albedo, MaterialParams params){
    vec3 V = -normalize(viewDir);
    
    vec3 F0 = mix(vec3(0.04), vec3(0.96), params.metalness);
    vec3 kS = fresnelSchlickRoughness(saturate(dot(V, N)), F0, params.roughness);
    vec3 kD = vec3(1.0) - kS;
    
    vec3 diffuse = kD * albedo / PI;

    return diffuse;
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
    float G = SchlickGGX(NoV, NoL, params.roughness);
    
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



vec3 getScatteredReflection(vec3 reflectDir, vec3 normal, float roughness, float sampleIndex) {
    if (roughness < 1e-4) {
        return reflectDir;
    }

    vec3 randVec = psuedoB(vec3(gl_FragCoord.xy, float((frameCounter + 1) % 2048)) + sampleIndex * GOLDEN_RATIO).xyz;
    // vec3 randVec = rand2_3(texcoord + sin(frameTimeCounter) + sampleIndex * GOLDEN_RATIO);
    
    vec3 tangent = normalize(cross(
        abs(reflectDir.z) < 0.999 ? vec3(0,0,1) : vec3(1,0,0), 
        reflectDir
    ));
    vec3 bitangent = cross(reflectDir, tangent);
    mat3 tbn = mat3(tangent, bitangent, reflectDir);

    float a = roughness;
    float phi = _2PI * randVec.x;
    
    float cosTheta = sqrt((1.0 - randVec.y) / (1.0 + (a*a - 1.0) * randVec.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    
    vec3 hemisphere = vec3(
        sinTheta * cos(phi),
        sinTheta * sin(phi),
        cosTheta
    );

    vec3 scatteredDir = tbn * hemisphere;

    return dot(scatteredDir, normal) > 0.0 
        ? normalize(scatteredDir)
        : reflect(scatteredDir, normal);
}

mat3 buildTangentBasis(vec3 N) {
    vec3 up = (abs(N.z) < 0.999) ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
    vec3 T = normalize(cross(up, N));
    vec3 B = cross(N, T);
    return mat3(T, B, N);
}

vec3 sampleGGXNormal_Tangent(vec2 u, float alpha) {
    float a2 = alpha * alpha;

    float phi = 2.0 * PI * u.x;

    float cosTheta = sqrt((1.0 - u.y) / (1.0 + (a2 - 1.0) * u.y));
    float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));

    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    float z = cosTheta;

    return vec3(x, y, z);
}

vec3 sampleMicrofacetNormal_GGX(vec3 N, float roughness, vec2 u) {
    float alpha = max(0.001, roughness);
    mat3 TBN = buildTangentBasis(N);

    vec3 H_tangent = sampleGGXNormal_Tangent(u, alpha);
    vec3 H = normalize(TBN * H_tangent);

    if (dot(H, N) < 0.0) H = -H;

    return H;
}

vec3 sampleRoughReflectionDir(vec3 V, vec3 N, float roughness, vec2 u) {
    V = normalize(V);
    N = normalize(N);

    if (roughness < 0.01) {
        return normalize(reflect(-V, N));
    }

    vec3 H = sampleMicrofacetNormal_GGX(N, roughness, u);

    vec3 L = normalize(reflect(-V, H));

    if (dot(L, N) <= 0.0) {
        L = normalize(reflect(-V, N));
    }

    return L;
}



vec3 SampleVNDF_BoundedCorrection(vec2 u, vec3 wi, vec2 alpha, out float out_pdf_ratio)
{
    vec3 wiStd = vec3(wi.xy * alpha, wi.z);
    float t = length(wiStd);
    wiStd /= t;

    float phi = (2.0 * u.x - 1.0) * PI;

    float a = saturate(min(alpha.x, alpha.y));
    float s = 1.0 + length(wi.xy);
    float a2 = a * a;
    float s2 = s * s;
    
    float k = (1.0 - a2) * s2 / (s2 + a2 * wi.z * wi.z); 

    float b = wiStd.z;
    b = wi.z > 0.0 ? k * b : b;

    out_pdf_ratio = (k * wi.z + t) / (wi.z + t);

    float z = (1.0 - u.y) * (1.0 + b) - b;
    float sinTheta = sqrt(clamp(1.0 - z * z, 0.0, 1.0));
    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    vec3 c = vec3(x, y, z);

    vec3 wmStd = c + wiStd;

    vec3 wm = normalize(vec3(wmStd.xy * alpha, wmStd.z));

    return wm;
}

mat3 BuildTBN(vec3 N) {
    vec3 up = abs(N.z) < 0.999 ? vec3(0, 0, 1) : vec3(1, 0, 0);
    vec3 T = normalize(cross(up, N));
    vec3 B = cross(N, T);
    return mat3(T, B, N);
}

vec4 GetSSRDirection(vec3 N_vs, vec3 V_vs, float roughness, vec2 u)
{
    float alpha = roughness;
    alpha = clamp(alpha, 0.001, 1.0); 
    vec2 alpha2 = vec2(alpha, alpha);

    mat3 tbn = BuildTBN(N_vs);

    vec3 V_ts = V_vs * tbn;

    float pdf_ratio;
    vec3 H_ts = SampleVNDF_BoundedCorrection(u, V_ts, alpha2, pdf_ratio);

    vec3 H_vs = tbn * H_ts;

    vec3 L_vs = reflect(-V_vs, H_vs);

    float NdotL = dot(N_vs, L_vs);
    float valid = step(0.0, NdotL);

    return vec4(L_vs, pdf_ratio * valid);
}

#endif