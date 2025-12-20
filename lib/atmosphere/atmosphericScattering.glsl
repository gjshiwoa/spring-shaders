// AKG4e3: 实时大气散射渲染实战
// https://zhuanlan.zhihu.com/p/595576594

// 张亚坤: 体渲染探秘（三）天空大气渲染
// https://zhuanlan.zhihu.com/p/419165090

// 未名客: 【实战】从零实现一套完整单次大气散射
// https://zhuanlan.zhihu.com/p/237502022

// 感谢 Coldnight冷夜 大佬在实现过程中提供的帮助

float getHeigth(vec3 p){
    return length(p) - earth_r;
}

float getRho(float h, float H){
    return min(exp(-(h / H)), 1.0);
}

vec3 RayleighCoefficient(float h){
    return RayleighSigma * getRho(h, H_R);
}

vec3 MieCoefficient(float h){
    return MieSigma * getRho(h, H_M);
}

vec3 MieAbsorption(float h){
    return MieAbsorptionSigma * getRho(h, H_M);
}

vec3 OzoneAbsorption(float h){
    float rho = max(0, 1.0 - abs(h - ozoneCenter) / ozoneWidth);
    return OzoneAbsorptionSigma * rho;
}

float RayleiPhase(float cos_theta){
    return (3.0 / (16.0 * PI)) * (1.0 + cos_theta * cos_theta);
}

float MiePhase(float cos_theta){
    float g = MIE_G;
    float g2 = g * g;

    // float a = 3.0 / (8.0 * PI);
    // float b = (1.0 - g2) / (2.0 + g2);
    // float c = 1.0 + cos_theta*cos_theta;
    // float d = pow(1.0 + g2 - 2*g*cos_theta, 1.5);
    // return a * b * (c / d);

    return (1 - g2) / (4.0 * PI * pow((1 + g2 - 2 * g * cos_theta), 1.5));
}

vec3 Scattering(float h, vec3 lightDir, vec3 worldDir){
    float cos_theta = dot(lightDir, worldDir);

    vec3 rayleigh = RayleighCoefficient(h) * RayleiPhase(cos_theta);
    vec3 mie = MieCoefficient(h) * MiePhase(cos_theta);

    return rayleigh + mie;
}

vec3 Transmittance(vec3 p1, vec3 p2, int N_SAMPLE){
    vec3 dir = normalize(p2 - p1);
    float distance = length(p2 - p1);
    float ds = distance / float(N_SAMPLE);
    vec3 sum = vec3(0.0);
    vec3 p = p1 + (dir * ds) * 0.5;

    for(int i=0; i<N_SAMPLE; i++){
        float h = getHeigth(p);

        vec3 scattering = RayleighCoefficient(h) + MieCoefficient(h);
        vec3 absorption = OzoneAbsorption(h) + MieAbsorption(h);
        vec3 extinction = scattering + absorption;

        sum += extinction * ds;
        p += dir * ds;
    }

    return exp(-sum);
}

void UvToTransmittanceLutParams(float bottomRadius, float topRadius, vec2 uv, out float mu, out float r){
    float x_mu = uv.x;
    float x_r = uv.y;

    float H = sqrt(max(0.0f, topRadius * topRadius - bottomRadius * bottomRadius));
    float rho = H * x_r;
    r = sqrt(max(0.0f, rho * rho + bottomRadius * bottomRadius));

    float d_min = topRadius - r;
    float d_max = rho + H;
    float d = d_min + x_mu * (d_max - d_min);
    mu = d == 0.0f ? 1.0f : (H * H - rho * rho - d * d) / (2.0f * r * d);

    mu = clamp(mu, -1.0f, 1.0f);
}

#define T1_T 0.0
vec3 DrawTransmittanceLut(){
    float bottomRadius = earth_r - T1_T;
    float topRadius = earth_r + atmosphere_h;

    float cos_theta = 0.0;
    float r = 0.0;
    UvToTransmittanceLutParams(bottomRadius, topRadius, texcoord, cos_theta, r);

    float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
    vec3 worldDir = vec3(sin_theta, cos_theta, 0);
    vec3 eyePos = vec3(0, r, 0);

    float dis = RaySphereIntersection(eyePos, worldDir, vec3(0.0), topRadius).y;
    vec3 hitPoint = eyePos + worldDir * dis;

    return Transmittance(eyePos, hitPoint, 100);
}

vec2 GetTransmittanceLutUv(float bottomRadius, float topRadius, float mu, float r){
    float H = sqrt(max(0.0f, topRadius * topRadius - bottomRadius * bottomRadius));
    float rho = sqrt(max(0.0f, r * r - bottomRadius * bottomRadius));

    float discriminant = r * r * (mu * mu - 1.0f) + topRadius * topRadius;
	float d = max(0.0f, (-r * mu + sqrt(discriminant)));

    float d_min = topRadius - r;
    float d_max = rho + H;

    if(d > d_max) return vec2(-1.0, -1.0);

    float x_mu = (d - d_min) / (d_max - d_min);
    float x_r = rho / H;

    return vec2(x_mu, x_r);
}

vec3 TransmittanceToAtmosphere(vec3 p, vec3 dir){
    float bottomRadius = earth_r - T1_T;
    float topRadius = earth_r + atmosphere_h;

    vec3 upVector = normalize(p);
    float cos_theta = dot(upVector, dir);
    float r = length(p);

    vec2 uv = GetTransmittanceLutUv(bottomRadius, topRadius, cos_theta, r);
    if(outScreen(uv)) return BLACK;

    uv = vec2(remap(uv.x, 0.0, 1.0, T1_I.x - 1, T1_I.z + 1),
              remap(uv.y, 0.0, 1.0, T1_I.y - 1, T1_I.w + 1));
    uv /= 512.0;

    return textureLod(colortex7, uv, 0.0).rgb;
}

vec3 IntegralMultiScattering(vec3 samplePoint, vec3 lightDir){
    vec3 RandomSphereSamples[64] = {
        vec3(0.99358869, 0.11260822, 0.00000000),
        vec3(0.91169626, 0.09264531, -0.40001094),
        vec3(0.67365669, 0.07622308, -0.73516846),
        vec3(0.32027131, 0.05980085, -0.94550312),
        vec3(-0.08461305, 0.04337863, -0.99548599),
        vec3(-0.47211121, 0.02695640, -0.88121127),
        vec3(-0.77287477, 0.01053417, -0.63441844),
        vec3(-0.93893703, -0.00588805, -0.34400967),
        vec3(0.95121443, 0.30510069, 0.04737789),
        vec3(0.87262333, 0.28513778, -0.39735537),
        vec3(0.64508557, 0.26517487, -0.71696598),
        vec3(0.30667517, 0.24521196, -0.91965048),
        vec3(-0.08097941, 0.22524904, -0.97095348),
        vec3(-0.45195152, 0.20528613, -0.86835698),
        vec3(-0.73988292, 0.18532322, -0.64610069),
        vec3(-0.89850573, 0.16536031, -0.40661972),
        vec3(0.81491274, 0.48256240, 0.32112631),
        vec3(0.74692797, 0.46259949, -0.47737804),
        vec3(0.55268120, 0.44263658, -0.70779533),
        vec3(0.26300195, 0.42267367, -0.86739253),
        vec3(-0.06941613, 0.40271076, -0.91272002),
        vec3(-0.38734470, 0.38274785, -0.83677632),
        vec3(-0.63384295, 0.36278493, -0.68292368),
        vec3(-0.77011555, 0.34282202, -0.53851903),
        vec3(0.64279879, 0.64279879, 0.41727299),
        vec3(0.58964950, 0.62283588, -0.51502062),
        vec3(0.43651702, 0.60287297, -0.66832678),
        vec3(0.20790049, 0.58291006, -0.78604042),
        vec3(-0.05489454, 0.56294714, -0.82452911),
        vec3(-0.30611887, 0.54298423, -0.78172057),
        vec3(-0.50124353, 0.52302132, -0.68862370),
        vec3(-0.60813201, 0.50305841, -0.61378117),
        vec3(0.48256240, 0.81491274, 0.32112631),
        vec3(0.44263658, 0.79494983, -0.41521868),
        vec3(0.32760242, 0.77498692, -0.54062333),
        vec3(0.15604192, 0.75502401, -0.63679218),
        vec3(-0.04121196, 0.73506110, -0.67671007),
        vec3(-0.22978144, 0.71509818, -0.65979621),
        vec3(-0.37596411, 0.69513527, -0.61310626),
        vec3(-0.45634954, 0.67517236, -0.57935863),
        vec3(0.30510069, 0.95121443, 0.04737789),
        vec3(0.28513778, 0.93125152, -0.22846527),
        vec3(0.21090146, 0.91128861, -0.35043767),
        vec3(0.10042936, 0.89132570, -0.44192607),
        vec3(-0.02645784, 0.87136279, -0.49013114),
        vec3(-0.14758408, 0.85139987, -0.50327897),
        vec3(-0.24189736, 0.83143696, -0.49920425),
        vec3(-0.29394532, 0.81147405, -0.50381371),
        vec3(0.11260822, 0.99358869, 0.00000000),
        vec3(0.09264531, 0.91169626, -0.40001094),
        vec3(0.07622308, 0.67365669, -0.73516846),
        vec3(0.05980085, 0.32027131, -0.94550312),
        vec3(0.04337863, -0.08461305, -0.99548599),
        vec3(0.02695640, -0.47211121, -0.88121127),
        vec3(0.01053417, -0.77287477, -0.63441844),
        vec3(-0.00588805, -0.93893703, -0.34400967),
        vec3(-0.11260822, 0.99358869, 0.00000000),
        vec3(-0.09264531, 0.91169626, -0.40001094),
        vec3(-0.07622308, 0.67365669, -0.73516846),
        vec3(-0.05980085, 0.32027131, -0.94550312),
        vec3(-0.04337863, -0.08461305, -0.99548599),
        vec3(-0.02695640, -0.47211121, -0.88121127),
        vec3(-0.01053417, -0.77287477, -0.63441844),
        vec3(0.00588805, -0.93893703, -0.34400967)
    };
    const int N_DIRECTION = 64;
    const int N_SAMPLE = 32;
    const float uniform_phase = 1.0 / (4.0 * PI);
    const float sphereSolidAngle = 4.0 * PI / float(N_DIRECTION);
    
    vec3 G_2 = vec3(0, 0, 0);
    vec3 f_ms = vec3(0, 0, 0);

    for(int i=0; i<N_DIRECTION; i++){
        vec3 worldDir = RandomSphereSamples[i];
        float dis = RaySphereIntersection(samplePoint, worldDir, vec3(0.0), earth_r + atmosphere_h).y;
        float d = RaySphereIntersection(samplePoint, worldDir, vec3(0.0), earth_r).x;
        if(d > 0) dis = min(dis, d);
        float ds = dis / float(N_SAMPLE);

        vec3 p = samplePoint + (worldDir * ds) * 0.5;
        vec3 opticalDepth = vec3(0, 0, 0);

        for(int j=0; j<N_SAMPLE; j++)
        {
            float h = getHeigth(p);
            vec3 sigma_s = RayleighCoefficient(h) + MieCoefficient(h);
            vec3 sigma_a = OzoneAbsorption(h) + MieAbsorption(h);
            vec3 sigma_t = sigma_s + sigma_a;
            opticalDepth += sigma_t * ds;

            vec3 t1 = TransmittanceToAtmosphere(p, lightDir);
            vec3 s  = Scattering(h, lightDir, worldDir);
            vec3 t2 = exp(-opticalDepth);
            
            G_2  += t1 * s * t2 * uniform_phase * ds * 1.0;  
            f_ms += t2 * sigma_s * uniform_phase * ds;

            p += worldDir * ds;
        }
    }

    G_2 *= sphereSolidAngle;
    f_ms *= sphereSolidAngle;
    return 50.0 * G_2 * (1.0 / (1.0 - f_ms));
}

vec3 DrawMultiScatteringLut(){
    float mu_s = texcoord.x * 2.0 - 1.0;
    float r = texcoord.y * atmosphere_h + earth_r;

    float cos_theta = mu_s;
    float sin_theta = sqrt(1.0 - cos_theta * cos_theta);
    vec3 lightDir = vec3(sin_theta, cos_theta, 0);
    vec3 p = vec3(0, r, 0);

    return IntegralMultiScattering(p, lightDir);
}

vec3 GetMultiScattering(float h, vec3 p, vec3 lightDir){
    float cosSunZenithAngle = dot(normalize(p), lightDir);
    vec2 uv = vec2(cosSunZenithAngle * 0.5 + 0.5, mix(1.0, h / atmosphere_h, 1.0));
    if(outScreen(uv)) return vec3(0.0);

    uv = vec2(remap(uv.x, 0.0, 1.0, MS_I.x - 1, MS_I.z + 1),
              remap(uv.y, 0.0, 1.0, MS_I.y - 1, MS_I.w + 1));
    uv /= 512.0;

    return textureLod(colortex7, uv, 0.0).rgb * 0.02;
}

void getDensity(float h, out float dRayleigh_c, out float dMie_c){
    dRayleigh_c = getRho(h, H_R);
    dMie_c = getRho(h, H_M);
}

vec3 ExtinctionT2(float h, float dRayleigh_c, float dMie_c,
                inout float dRayleigh, inout float dMie, inout float dOzone){
    dRayleigh += dRayleigh_c;
    dMie += dMie_c;
    dOzone += max(0, 1.0 - (abs(h - ozoneCenter) / ozoneWidth));
    return dRayleigh * RayleighSigma
        + dMie * (MieSigma + MieAbsorptionSigma)
        + dOzone * OzoneAbsorptionSigma;
}

mat2x3 AtmosphericScattering(vec3 worldPos, vec3 worldDirO, vec3 lightDir, vec3 I, float mieAmount, const int N_SAMPLES){
    float dis = length(worldPos);
    vec3 worldDir = normalize(worldPos);
    float ds = dis / float(N_SAMPLES);

    float dRayleigh = 0.0;
    float dMie = 0.0;
    float dRayleigh_c = 0.0;
    float dMie_c = 0.0;
    float dOzone = 0.0;

    vec3 p = earthPos;
    float h = getHeigth(p);

    vec3 t1 = TransmittanceToAtmosphere(p, lightDir);
    vec3 G_ALL = GetMultiScattering(h, p, lightDir);

    getDensity(h, dRayleigh_c, dMie_c);
    vec3 f_in_R_prev    = t1 * dRayleigh_c;
    vec3 f_in_M_prev    = t1 * dMie_c;
    vec3 f_multi_R_prev = G_ALL * dRayleigh_c;
    vec3 f_multi_M_prev = G_ALL * dMie_c;

    vec3 inScatteringR = vec3(0.0);
    vec3 inScatteringM = vec3(0.0);
    vec3 multiScatteringR = vec3(0.0);
    vec3 multiScatteringM = vec3(0.0);

    for (int i = 0; i < N_SAMPLES; i++) {
        p += worldDir * ds;
        h = getHeigth(p);

        t1 = TransmittanceToAtmosphere(p, lightDir);
        G_ALL = GetMultiScattering(h, p, lightDir);

        getDensity(h, dRayleigh_c, dMie_c);
        vec3 opticalDepthT2 = ExtinctionT2(h, dRayleigh_c, dMie_c, dRayleigh, dMie, dOzone) * ds;
        vec3 t2 = exp(-opticalDepthT2);

        vec3 f_in_R_new    = (t1 * t2) * dRayleigh_c;
        vec3 f_in_M_new    = (t1 * t2) * dMie_c;
        vec3 f_multi_R_new = (G_ALL * t2) * dRayleigh_c;
        vec3 f_multi_M_new = (G_ALL * t2) * dMie_c;

        inScatteringR    += 0.5 * (f_in_R_prev    + f_in_R_new);
        inScatteringM    += 0.5 * (f_in_M_prev    + f_in_M_new);
        multiScatteringR += 0.5 * (f_multi_R_prev + f_multi_R_new);
        multiScatteringM += 0.5 * (f_multi_M_prev + f_multi_M_new);

        f_in_R_prev    = f_in_R_new;
        f_in_M_prev    = f_in_M_new;
        f_multi_R_prev = f_multi_R_new;
        f_multi_M_prev = f_multi_M_new;
    }

    float cos_theta = dot(worldDirO, lightDir);
    vec3 inScattering    = inScatteringR * RayleighSigma * RayleiPhase(cos_theta)
                        + inScatteringM * MieSigma      * MiePhase(cos_theta);
                        // inScattering *= vec3(0.9,0.7,0.75);
    vec3 multiScattering = multiScatteringR * RayleighSigma
                        + multiScatteringM * MieSigma * mieAmount * MIE_STRENGTHNESS;

    inScattering = mix(inScattering, vec3(getLuminance(inScattering)), rainStrength * 0.33);

    return mat2x3(inScattering * ds * I, multiScattering * ds * I);
}



void Extinction(float h,
                inout float dRayleigh, inout float dMie, inout float dOzone){
    dRayleigh += getRho(h, H_R);
    dMie += getRho(h, H_M);
    dOzone += max(0, 1.0 - abs(h - ozoneCenter) / ozoneWidth);
}

vec3 Transmittance1(vec3 startPos, vec3 endPos, float stepCount){
    vec3 direction = normalize(endPos - startPos);
    float dist = length(endPos - startPos);
    float stepSize = dist / stepCount;
    vec3 stepVec = direction * stepSize;

    vec3 p = startPos + 0.5 * stepVec;

    float dRayleigh = 0.0;
    float dMie = 0.0;
    float dOzone = 0.0;

    for(int i = 0; i < stepCount; i++){
        float h = getHeigth(p);
        Extinction(h, dRayleigh, dMie, dOzone);
        p += stepVec;
    }
    vec3 opticalDepth = dRayleigh * RayleighSigma
                + dMie * (MieSigma + MieAbsorptionSigma)
                + dOzone * OzoneAbsorptionSigma;
    vec3 t = exp(-opticalDepth * stepSize);

    return t;
}

vec3 getSunColor(){
    vec3 sunColor = texelFetch(colortex7, sunColorUV, 0).rgb;
    return sunColor;
}

vec3 getSkyColor(){
    vec3 skyColor = texelFetch(colortex7, skyColorUV, 0).rgb;
    return skyColor;
}

/*
vec3 AtmosphericScattering(vec3 worldDir, vec3 lightDir){
    const int N_SAMPLE = 64;

    float d_p2a = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r + atmosphere_h).y;
    // float d_p2e = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r).x;
    float dis = d_p2a;
    // if(d_p2a < 0.0) return BLACK; 
    // if(d_p2e > 0.0) dis = min(dis, d_p2e);

    float ds = dis / float(N_SAMPLE);
    vec3 p = earthPos + worldDir * ds * 0.0;

    vec3 color = BLACK;
    vec3 opticalDepth = BLACK;

    for(int i = 0; i < N_SAMPLE; i++){
        float h = getHeigth(p);

        vec3 t1 = TransmittanceToAtmosphere(p, lightDir);
        
        vec3 s = Scattering(h, worldDir, lightDir);
        
        vec3 extinction = RayleighCoefficient(h) + MieCoefficient(h) +
                        OzoneAbsorption(h) + MieAbsorption(h);
        opticalDepth += extinction * ds;
        vec3 t2 = exp(-opticalDepth);

        vec3 inScattering = t1 * s * t2 * ds;
        color += inScattering;

        vec3 multiScattering = GetMultiScattering(h, p, lightDir) 
                                * (RayleighCoefficient(h) + MieCoefficient(h));
        color += multiScattering * t2 * ds;

        p += worldDir * ds;
    }

	return color * vec3(1.0) * 8.0;
}
*/


// 定义常量 (代替 uniform)
// --- 物理和几何参数 (相对值，需要调整以匹配场景尺度和所需外观) ---
const vec3 UP_DIRECTION = vec3(0.0, 1.0, 0.0); // 定义世界的“上”方向
const float PLANET_RADIUS = 6371.0;       // 地球半径 (单位: km, 相对)
const float ATMOSPHERE_HEIGHT = 80.0;       // 大气层有效高度 (单位: km, 相对)
const float SUN_INTENSITY = 22.0;         // 太阳光强度因子

// --- 散射系数 (核心参数，决定颜色和强度) ---
// 瑞利散射系数 (波长依赖性: 蓝 > 绿 > 红) - 这些值需要大量调整!
const vec3 BETA_RAYLEIGH = vec3(5.8e-3, 13.5e-3, 33.1e-3); // (单位: 1/km, 相对)
// 米氏散射系数 (相对波长不敏感) - 控制雾霾/浑浊度
const float BETA_MIE = 4.0e-3;            // (单位: 1/km, 相对)
// 米氏散射方向性 (g) - 控制光晕大小 ([-1, 1], 典型值 0.7 ~ 0.9)
// const float MIE_G = 0.80;

// --- 外观调整参数 ---
const float SUN_DISK_SIZE = 0.999;       // 控制太阳光晕的锐利度 (dot product 阈值)
const float SUN_DISK_INTENSITY = 5.0;    // 太阳光晕的额外强度
const float EXPOSURE1 = 1.5;             // 最终颜色的曝光/亮度调整
const float SUNSET_FACTOR = 2.5;        // 增强日落/日出时瑞利散射导致的红光效果
const float HORIZON_EDGE_FACTOR = 0.1;  // 地平线附近亮度衰减/增亮的调整因子

// 辅助函数：计算 Henyey-Greenstein 米氏散射相位函数
// cosTheta: 视角方向与光照方向夹角的余弦值
// g:        米氏散射方向性参数
float miePhaseFunction(float cosTheta, float g) {
    float g2 = g * g;
    float numerator = (1.0 - g2);
    float denominator = 1.0 + g2 - 2.0 * g * cosTheta;
    // 添加 epsilon 防止分母为零或过小导致数值问题
    denominator = max(denominator, 1e-4); // 防止除以零或负数开根号
    denominator = pow(denominator, 1.5);
    return (1.0 / (4.0 * 3.14159265)) * (numerator / denominator);
}

// 辅助函数：计算瑞利散射相位函数
// cosTheta: 视角方向与光照方向夹角的余弦值
float rayleighPhaseFunction(float cosTheta) {
    float factor = (3.0 / (16.0 * 3.14159265));
    return factor * (1.0 + cosTheta * cosTheta);
}

// 辅助函数：计算光线穿过球壳大气的近似光学深度
// worldPos: 观察点位置 (这里简化为地表附近，高度为0)
// worldDir: 光线方向 (观察方向或太阳光方向)
// radius:   行星半径
// atmHeight: 大气层高度
// scaleHeight: 密度随高度衰减的标高 (这里用 atmHeight 近似)
float getOpticalDepth(vec3 worldPos, vec3 worldDir, float radius, float atmHeight, float scaleHeight) {
    // 简化：假设观察者在地表附近 (高度 h = 0)
    float h = 0.0; // max(0.0, length(worldPos) - radius);
    float cosTheta = dot(worldDir, normalize(worldPos)); // worldPos 在这里近似为 UP_DIRECTION

    // 使用一个简化的几何近似来计算路径长度
    // 避免在地平线附近出现无穷大或负值
    float zenithAngle = acos(max(0.001, dot(worldDir, UP_DIRECTION))); // 与天顶的夹角
    // 简单的近似：路径长度与天顶角的 secant 相关，并考虑大气密度随高度指数衰减
    // 这是一个非常粗略的近似，避免积分
    return scaleHeight * exp(-(h / scaleHeight)) * (1.0 / max(0.001, cos(zenithAngle)));
    // 更简单的近似：直接用角度的函数
    // return scaleHeight / max(0.001, dot(worldDir, UP_DIRECTION));
}
vec3 getASkyColor(in vec3 worldDir, in vec3 sunDir) {
    // 常量定义（不使用uniform）
    const float rayleighScatterCoeff = 0.0025;       // 瑞利散射系数
    const float mieScatterCoeff = 0.0010;            // 米氏散射系数
    const float sunIntensity = 20.0;                 // 太阳强度
    const vec3 rayleighColor = vec3(0.18867780436772762, 0.4978442963618773, 1.0); // RGB: 蓝色为主的瑞利散射
    const vec3 mieColor = vec3(1.0);                 // 米氏散射颜色（白色）
    const float rayleighHeight = 8000.0;             // 瑞利散射高度
    const float mieHeight = 1200.0;                  // 米氏散射高度
    const float mieG = 0.8;                          // 米氏相位函数的 g 参数，控制向前散射的程度
    const float earthRadius = 6371000.0;             // 地球半径（米）
    const float atmosphereHeight = 100000.0;         // 大气层高度（米）
    
    // 通过点积获得太阳角度（阳光和视线方向的夹角）
    float sunCosTheta = dot(worldDir, sunDir);
    
    // 计算视线与天顶方向的夹角
    float zenithCosTheta = worldDir.y; // 假设 Y 轴是天顶方向
    float zenithAngle = acos(zenithCosTheta);
    
    // 估算光学深度（optical depth）- 视线穿过大气层的路径长度
    float rayleighOpticalDepth = rayleighScatterCoeff * exp(-zenithAngle / rayleighHeight);
    float mieOpticalDepth = mieScatterCoeff * exp(-zenithAngle / mieHeight);
    
    // 计算太阳高度对散射的影响
    float sunHeight = sunDir.y; // 太阳高度（-1 到 1 范围）
    
    // 日出/日落效果
    // 当太阳低于地平线或接近地平线时，调整颜色
    vec3 sunsetColor = vec3(1.0, 0.3, 0.1); // 日落的红橙色
    float sunsetFactor = 1.0 - smoothstep(-0.15, 0.15, sunHeight);
    
    // 米氏相位函数 - 控制散射方向性
    float g2 = mieG * mieG;
    float miePhase = 1.5 * (1.0 - g2) / (2.0 + g2) * 
                    (1.0 + sunCosTheta * sunCosTheta) / 
                    pow(1.0 + g2 - 2.0 * mieG * sunCosTheta, 1.5);
    
    // 瑞利相位函数 - 更简单，对前后散射几乎相同
    float rayleighPhase = 0.75 * (1.0 + sunCosTheta * sunCosTheta);
    
    // 计算散射贡献
    vec3 rayleighScatter = rayleighColor * rayleighPhase * rayleighOpticalDepth;
    vec3 mieScatter = mieColor * miePhase * mieOpticalDepth;
    
    // 计算太阳直射光
    float sunSpot = smoothstep(0.9998, 0.9999, sunCosTheta);
    vec3 sunColor = vec3(1.0, 1.0, 0.95) * sunSpot * (1.0 - sunsetFactor * 0.98);
    
    // 日出/日落效果 - 使天空在地平线附近变红
    vec3 horizonColor = mix(rayleighColor, sunsetColor, sunsetFactor);
    float horizonInfluence = smoothstep(0.0, 0.4, 1.0 - zenithCosTheta);
    
    // 组合散射效果
    vec3 scatterColor = horizonColor * rayleighScatter + mieColor * mieScatter;
    
    // 应用太阳高度对整体颜色的影响
    float sunHeightFactor = smoothstep(-0.1, 0.3, sunHeight);
    scatterColor = mix(scatterColor * (0.3 + 0.7 * sunHeightFactor), scatterColor, sunHeightFactor);
    
    // 添加太阳直射光
    scatterColor += sunColor * sunIntensity;
    
    // 地平线增强
    scatterColor = mix(scatterColor, horizonColor, horizonInfluence * sunsetFactor);
    
    // 应用额外的日出效果 - 当太阳刚刚出现时的紫色调
    vec3 sunriseColor = vec3(0.7, 0.3, 0.9);
    float sunriseFactorZenith = smoothstep(-0.2, 0.0, sunHeight);
    float sunriseFactorHorizon = (1.0 - sunriseFactorZenith) * horizonInfluence;
    scatterColor = mix(scatterColor, sunriseColor, sunriseFactorHorizon * 0.3);
    
    // 曝光调整
    scatterColor = 1.0 - exp(-scatterColor * 1.5);
    
    // 确保颜色在有效范围内
    return scatterColor;
}