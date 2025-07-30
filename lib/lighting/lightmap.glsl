vec2 AdjustLightmap(vec2 mcLightmap){
    mcLightmap = (mcLightmap * 33.05 - 1.05) / 32.0;
    mcLightmap = toLinearR(mcLightmap);
    
    // 人造光
    mcLightmap.x = saturate(pow(mcLightmap.x, ARTIFICIAL_LIGHT_FALLOFF));

    // 环境光
    mcLightmap.y = saturate(pow(mcLightmap.y, SKY_LIGHT_FALLOFF));

    return mcLightmap;
}