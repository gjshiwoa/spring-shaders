bool voxelInBounds(ivec3 v) {
    return all(greaterThanEqual(v, ivec3(0))) &&
           all(lessThan(v, VOXEL_DIM));
}

ivec3 getCameraFloorInt() {
    ivec3 ti = cameraPositionInt;
    bvec3 needFix = lessThan(cameraPosition, vec3(ti));
    return ti - ivec3(needFix);
}

vec3 getCameraFract01() {
    ivec3 cf = getCameraFloorInt();
    return cameraPosition - vec3(cf);
}

ivec3 relWorldToVoxelCoord(vec3 relPos) {
    ivec3 deltaBlock = ivec3(floor(relPos + getCameraFract01()));
    return deltaBlock + VOXEL_HALF;
}

int voxelCoordToLinearIndex(ivec3 v) {
    return v.x + VOXEL_DIM.x * (v.y + VOXEL_DIM.y * v.z);
}

vec3 voxelUVWToRelWorld(vec3 uvw) {
    vec3 camFract01 = getCameraFract01();
    vec3 s = uvw * vec3(VOXEL_DIM) - vec3(VOXEL_HALF);
    return s - camFract01;
}
