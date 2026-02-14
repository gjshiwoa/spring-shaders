#ifndef VOXELIZATION_GLSL
#define VOXELIZATION_GLSL

bool voxelInBounds(ivec3 v) {
    return all(greaterThanEqual(v, ivec3(0))) &&
           all(lessThan(v, VOXEL_DIM));
}

ivec3 getCameraFloorInt() {
    ivec3 ti = cameraPositionInt;
    bvec3 needFix = lessThan(cameraPosition, vec3(ti));
    return ti - ivec3(needFix);
}

ivec3 getPrevCameraFloorInt() {
    ivec3 ti = previousCameraPositionInt;
    bvec3 needFix = lessThan(previousCameraPosition, vec3(ti));
    return ti - ivec3(needFix);
}

vec3 getCameraFract01() {
    ivec3 cf = getCameraFloorInt();
    return cameraPosition - vec3(cf);
}

ivec3 reprojectToPrevVoxel(ivec3 curVoxelCoord) {
    ivec3 cfCur  = getCameraFloorInt();
    ivec3 cfPrev = getPrevCameraFloorInt();

    ivec3 worldBlock = cfCur + (curVoxelCoord - VOXEL_HALF);

    ivec3 deltaPrev = worldBlock - cfPrev;

    return deltaPrev + VOXEL_HALF;
}

bool voxelOccupied(vec4 v) {
    bool byA   = (v.a < 0.95);
    bool byRGB = any(greaterThan(v.rgb, vec3(1.0 / 255.0)));
    return byA || byRGB;
}

ivec3 relWorldToVoxelCoord(vec3 relPos) {
    ivec3 deltaBlock = ivec3(floor(relPos + getCameraFract01()));
    return deltaBlock + VOXEL_HALF;
}

vec3 voxelUVWToRelWorld(vec3 uvw) {
    vec3 camFract01 = getCameraFract01();
    vec3 s = uvw * vec3(VOXEL_DIM) - vec3(VOXEL_HALF);
    return s - camFract01;
}

#endif
