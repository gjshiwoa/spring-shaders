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

    vec4 v    = imageLoad(voxel, p);
    vec4 sky  = imageLoad(voxelLitSky, p);

    imageStore(voxelPrev, p, v);

    // 只确保R保留，其他为0（可选但推荐）
    imageStore(voxelLitSkyPrev, p, vec4(sky.r, 0.0, 0.0, 0.0));
}
