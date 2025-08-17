#if defined VSH && (defined GBF || defined SHD)

float IDMapping(){
    switch(int(mc_Entity.x)){
        case 31:            return PLANTS_SHORT;
        case 10175:         return PLANTS_TALL_L;
        case 11175:         return PLANTS_TALL_U;
        case 18:            return LEAVES;
        case 10176:         return PLANTS_OTHER;
        case 10:            return NO_ANISO;
        case 89:            return GLOWING_BLOCK;

        default:            return 0.0;
    }
}

float IDMappingEntity(){
    switch(entityId){
        case 2:             return LIGHTNING_BOLT;
        case 3:             return FIREWORK_ROCKET;

        default:            return ENTITIES;
    }
}

// translucency
float IDMappingT(){
    switch(int(mc_Entity.x)){
        case 8:             return WATER;
        
        default:            return 0.0;
    }
}

#endif

#ifdef FSH 
    float isSkyHRR(){
        vec2 uv = texcoord * 2 - 1.0;
        float isSky = 0.0;
        for(int i = 0; i < 9; i++){
            vec2 curUV = uv + offsetUV9[i]*invViewSize;
            float depth = texture(depthtex1, curUV).r;
            if(depth == 1.0) return 1.0;
        }
        return 0.0;
    }

    float isSkyHRR1(){
        vec2 uv = texcoord * 2 - vec2(1.0, 0.0);
        float isSky = 0.0;
        for(int i = 0; i < 9; i++){
            vec2 curUV = uv + offsetUV9[i]*invViewSize;
            float depth = texture(depthtex1, curUV).r;
            if(depth == 1.0) return 1.0;
        }
        return 0.0;
    }

    float blockIDRange = 0.3;

    float plantsS   = checkInRange(blockID, PLANTS_SHORT, blockIDRange);
    float plantsTL  = checkInRange(blockID, PLANTS_TALL_L, blockIDRange);
    float plantsTU  = checkInRange(blockID, PLANTS_TALL_U, blockIDRange);
    float plantsT   = plantsTL + plantsTU;
    float leaves   = checkInRange(blockID, LEAVES, blockIDRange);
    float plantsO = checkInRange(blockID, PLANTS_OTHER, blockIDRange);
    float plants   = plantsS + plantsT + leaves + plantsO;

    float glowingB = checkInRange(blockID, GLOWING_BLOCK, blockIDRange) 
                    + checkInRange(blockID, NO_ANISO, blockIDRange);
    
    
    float entities = checkInRange(blockID, ENTITIES, blockIDRange);
    float lightningBolt = checkInRange(blockID, LIGHTNING_BOLT, blockIDRange);

    float block = checkInRange(blockID, BLOCK, blockIDRange);
    float hand = checkInRange(blockID, HAND, blockIDRange);

    float depthB0 = texture(depthtex0, texcoord).r;
    float depthB1 = texture(depthtex1, texcoord).r;
    float skyA = depthB0 == 1.0 ? 1.0 : 0.0;
    float skyB = depthB1 == 1.0 ? 1.0 : 0.0;

    #ifdef DISTANT_HORIZONS
        float dhTerrain = skyB > 0.5 ? checkInRange(gbufferID, DH_TERRAIN, blockIDRange) : 0.0;
    #endif

    float waterB = depthB0 != depthB1 ? 1.0 : 0.0;

#endif