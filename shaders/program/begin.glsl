const ivec3 workGroups = ivec3(32, 16, 32);
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(rgba8) uniform writeonly image3D voxel;
layout(rgba16f) uniform writeonly image2D colorimg7;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"

void main(){
    ivec3 id = ivec3(gl_GlobalInvocationID.xyz);
    if (id.x >= 256 || id.y >= 128 || id.z >= 256)
        return;

    imageStore(voxel, id, vec4(0.0, 0.0, 0.0, 1.0));

    if(all(equal(id, ivec3(0)))){
        imageStore(colorimg7, rightLitUV, vec4(0.0));
        imageStore(colorimg7, LeftLitUV, vec4(0.0));
    }
}