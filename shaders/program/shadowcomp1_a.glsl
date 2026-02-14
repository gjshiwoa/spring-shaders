#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/lighting/voxelization.glsl"

const ivec3 workGroups = ivec3(32, 16, 32);
layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(rgba8, binding = 0) uniform image3D voxel;
layout(rgba8, binding = 1) uniform image3D voxelPrev;

layout(rgba8, binding = 2) uniform image3D voxelLitSky;
layout(rgba8, binding = 3) uniform image3D voxelLitSkyPrev;

void main() {
    ivec3 p = ivec3(gl_GlobalInvocationID.xyz);
    if (!voxelInBounds(p)) return;

    vec4 cur    = imageLoad(voxel, p);
    vec4 curSky = imageLoad(voxelLitSky, p);

    bool curOcc = voxelOccupied(cur);

    if (!curOcc) {
        imageStore(voxel, p, cur);
        imageStore(voxelLitSky, p, vec4(0.0));
        return;
    }

    ivec3 pp = reprojectToPrevVoxel(p);
    if (!voxelInBounds(pp)) {
        imageStore(voxel, p, cur);
        imageStore(voxelLitSky, p, vec4(curSky.r, 0.0, 0.0, 0.0));
        return;
    }

    vec4 hist    = imageLoad(voxelPrev, pp);
    vec4 histSky = imageLoad(voxelLitSkyPrev, pp);

    bool histOcc = voxelOccupied(hist);
    if (histOcc != curOcc) {
        imageStore(voxel, p, cur);
        imageStore(voxelLitSky, p, vec4(curSky.r, 0.0, 0.0, 0.0));
        return;
    }

    // float skyDiff = abs(curSky.r - histSky.r);
    // if (skyDiff > 0.25) {
    //     imageStore(voxel, p, cur);
    //     imageStore(voxelLitSky, p, vec4(curSky.r, 0.0, 0.0, 0.0));
    //     return;
    // }

    float historyWeight      = 0.98;
    float historyWeightSky   = 0.98;

    vec4 outv = mix(cur, hist, historyWeight);

    float outSkyR = mix(curSky.r, histSky.r, historyWeightSky);
    vec4  outSky  = vec4(outSkyR, 0.0, 0.0, 0.0);

    imageStore(voxel, p, outv);
    imageStore(voxelLitSky, p, outSky);
}