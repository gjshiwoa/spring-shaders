const ivec3 workGroups = ivec3(256, 256, 1);

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(r16ui, binding = 1) uniform readonly uimage3D tmpX;
layout(r16ui, binding = 2) uniform writeonly uimage3D tmpY;

const int N = 128;
const int INF = 1 << 20;          // 内部计算用“无穷大”
const uint INF_OUT = 65535u;      // 写出去的“无穷大”标记（r16ui）

shared int sPref[N]; // 前缀 min：min_{j<=i}(f[j]-j)
shared int sSuf[N];  // 反转后前缀 min：min_{j>=i}(f[j]+j)

void main() {
    int y = int(gl_LocalInvocationID.x);  // 0..127
    int x = int(gl_WorkGroupID.x);        // 0..255
    int z = int(gl_WorkGroupID.y);        // 0..255
    if (x >= 256 || z >= 256) return;

    // 读取上一 pass 的距离（已经是 >=0 的整数）
    uint inU = imageLoad(tmpX, ivec3(x, y, z)).r;
    int f = (inU == INF_OUT) ? INF : int(inU);

    int u = f - y;            // f[j] - j
    int v = f + y;            // f[j] + j
    int yr = (N - 1) - y;     // 反转索引

    sPref[y] = u;
    sSuf[yr] = v;
    barrier();

    // inclusive prefix min for sPref
    for (int off = 1; off < N; off <<= 1) {
        int self  = sPref[y];
        int other = (y >= off) ? sPref[y - off] : INF;
        barrier();
        sPref[y] = min(self, other);
        barrier();
    }

    // inclusive prefix min on reversed array => suffix min on original
    for (int off = 1; off < N; off <<= 1) {
        int self  = sSuf[yr];
        int other = (yr >= off) ? sSuf[yr - off] : INF;
        barrier();
        sSuf[yr] = min(self, other);
        barrier();
    }

    int prefMin = sPref[y];    // min_{j<=y}(f[j]-j)
    int sufMin  = sSuf[yr];    // min_{j>=y}(f[j]+j)

    int d = min(y + prefMin, -y + sufMin);
    uint outU = (d >= INF) ? INF_OUT : uint(max(d, 0));
    imageStore(tmpY, ivec3(x, y, z), uvec4(outU, 0, 0, 0));
}