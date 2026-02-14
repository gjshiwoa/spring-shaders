const ivec3 workGroups = ivec3(256, 128, 1);

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(r16ui, binding = 2) uniform readonly uimage3D tmpY;
layout(r16ui, binding = 3) uniform writeonly uimage3D SDF;

const int N = 256;
const int INF = 1 << 20;
const uint INF_OUT = 65535u;

shared int sPref[N];
shared int sSuf[N];

void main() {
    int z = int(gl_LocalInvocationID.x);  // 0..255
    int x = int(gl_WorkGroupID.x);        // 0..255
    int y = int(gl_WorkGroupID.y);        // 0..127
    if (x >= 256 || y >= 128) return;

    uint inU = imageLoad(tmpY, ivec3(x, y, z)).r;
    int f = (inU == INF_OUT) ? INF : int(inU);

    int u = f - z;
    int v = f + z;
    int zr = (N - 1) - z;

    sPref[z] = u;
    sSuf[zr] = v;
    barrier();

    for (int off = 1; off < N; off <<= 1) {
        int self  = sPref[z];
        int other = (z >= off) ? sPref[z - off] : INF;
        barrier();
        sPref[z] = min(self, other);
        barrier();
    }

    for (int off = 1; off < N; off <<= 1) {
        int self  = sSuf[zr];
        int other = (zr >= off) ? sSuf[zr - off] : INF;
        barrier();
        sSuf[zr] = min(self, other);
        barrier();
    }

    int prefMin = sPref[z];
    int sufMin  = sSuf[zr];

    int d = min(z + prefMin, -z + sufMin);
    uint outU = (d >= INF) ? INF_OUT : uint(max(d, 0));
    imageStore(SDF, ivec3(x, y, z), uvec4(outU, 0, 0, 0));
}