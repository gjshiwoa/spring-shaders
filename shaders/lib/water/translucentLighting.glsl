float shadowMappingTranslucent(vec4 worldPos, vec3 normalTexW, float radius, float quality) {
    worldPos.xyz += 0.05 * normalTexW;
    vec4 shadowPos = getShadowPos(worldPos);
    shadowPos.z -= 0.00005;
    float shade = PCF(shadowtex0, shadowPos.xyz, radius, quality);

    return shade;
}