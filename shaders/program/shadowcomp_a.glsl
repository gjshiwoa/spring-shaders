const ivec3 workGroups = ivec3(128, 256, 1);
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(rgba8, binding = 0) uniform readonly image3D voxel;
layout(r16ui, binding = 1) uniform writeonly uimage3D tmpX;

const int N = 256;
const int INF = 1 << 20;  // 足够大且不会溢出
const uint INF_OUT = 65535u;

shared int sPref[N];  // 存 f[j]-j 的前缀最小
shared int sSuf[N];   // 存 f[j]+j 的“后缀最小”(用反转前缀实现)

void main() {
    int x = int(gl_LocalInvocationID.x);
    int y = int(gl_WorkGroupID.x); // 0..127
    int z = int(gl_WorkGroupID.y); // 0..255
    if (y >= 128 || z >= 256) return;

    float a = imageLoad(voxel, ivec3(x, y, z)).a;
    int f = (a < 0.95) ? 0 : INF;  // 物体=0，空=INF

    int u = f - x;        // f[j]-j
    int v = f + x;        // f[j]+j
    int xr = (N - 1) - x; // 反转索引

    sPref[x] = u;
    sSuf[xr] = v;
    barrier();

    // 并行前缀 min：sPref[x] = min_{j<=x}(f[j]-j)
    for (int off = 1; off < N; off <<= 1) {
        int self  = sPref[x];
        int other = (x >= off) ? sPref[x - off] : INF;
        barrier();               // 确保所有线程都读完
        sPref[x] = min(self, other);
        barrier();               // 确保写完进入下一轮
    }

    // 反转数组前缀 min：sSuf[xr] = min_{j>=x}(f[j]+j)
    for (int off = 1; off < N; off <<= 1) {
        int self  = sSuf[xr];
        int other = (xr >= off) ? sSuf[xr - off] : INF;
        barrier();
        sSuf[xr] = min(self, other);
        barrier();
    }

    int prefMin = sPref[x];
    int sufMin  = sSuf[xr];

    int d = min(x + prefMin, -x + sufMin);
    uint outv = (d >= INF) ? INF_OUT : uint(max(d, 0));
    imageStore(tmpX, ivec3(x, y, z), uvec4(outv, 0, 0, 0));
}