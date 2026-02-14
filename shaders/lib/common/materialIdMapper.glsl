float IDMapping(float id){
    switch(int(round(id + 0.01))){
        case 31:            return PLANTS_SHORT;
        case 10175:         return PLANTS_TALL_L;
        case 11175:         return PLANTS_TALL_U;
        case 18:            return LEAVES;
        case 10176:         return PLANTS_OTHER;
        case 10:            return NO_ANISO;
        case 20:            return NO_VOXEL;
        case 89:            return GLOWING_BLOCK;
        case 61:            return USE_ART_COL;

        default:            return 0.0;
    }
}

#if defined VSH && (defined GBF || defined SHD)

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
    float isSkyHRR(vec2 uv){
        // vec2 uv = texcoord * 2 - 1.0;
        float isSky = 0.0;
        for(int i = 0; i < 9; i++){
            vec2 curUV = uv + offsetUV9[i]*invViewSize;
            float depth = texture(depthtex1, curUV).r;

            #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
                if(depth == 1.0 && texture(dhDepthTex0, curUV).r == 1.0) return 1.0;
            #endif

            if(depth == 1.0) return 1.0;
        }
        return 0.0;
    }

    float depthB0 = texture(depthtex0, texcoord).r;
    float depthB1 = texture(depthtex1, texcoord).r;

    float blockIDRange = 0.3;

    float plantsS   = checkInRange(blockID, PLANTS_SHORT, blockIDRange);
    float plantsTL  = checkInRange(blockID, PLANTS_TALL_L, blockIDRange);
    float plantsTU  = checkInRange(blockID, PLANTS_TALL_U, blockIDRange);
    float plantsT   = plantsTL + plantsTU;
    float leaves   = checkInRange(blockID, LEAVES, blockIDRange);
    float plantsO = checkInRange(blockID, PLANTS_OTHER, blockIDRange);

    float glowingB = checkInRange(blockID, GLOWING_BLOCK, blockIDRange) 
                    + checkInRange(blockID, NO_ANISO, blockIDRange);



    #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
        float dhTerrain = texture(dhDepthTex0, texcoord).r < 1.0 && depthB0 == 1.0 ? 1.0 : 0.0;
        float dhLeaves = checkInRange(blockID, DH_LEAVES, blockIDRange);
        float dhWood = checkInRange(blockID, DH_WOOD, blockIDRange);
    #else
        float dhTerrain = 0.0; float dhLeaves = 0.0; float dhWood = 0.0;
    #endif

    float plants = plantsS + plantsT + leaves + plantsO + dhLeaves + dhWood;
    
    float entities = checkInRange(blockID, ENTITIES, blockIDRange);
    float lightningBolt = checkInRange(blockID, LIGHTNING_BOLT, blockIDRange);

    float block = checkInRange(blockID, BLOCK, blockIDRange);
    float hand = checkInRange(blockID, HAND, blockIDRange);

    float skyA = depthB0 == 1.0 && dhTerrain < 0.5 ? 1.0 : 0.0;
    float skyB = depthB1 == 1.0 && dhTerrain < 0.5 ? 1.0 : 0.0;

    float waterB = depthB0 != depthB1 ? 1.0 : 0.0;
#endif