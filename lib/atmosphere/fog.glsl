// 杨超wantnon: iq高度雾注解
// https://zhuanlan.zhihu.com/p/61138643

float fogVisibility(vec4 worldPos){
    float N_SAMPLE = VOLUME_LIGHT_SAMPLES;

    float dist = length(worldPos.xyz);
    dist = min(dist, shadowDistance);
    float ds = dist / N_SAMPLE;

    vec3 startPos = vec3(0.0);
    vec3 rayDir = normalize(worldPos.xyz);
    vec3 dStep = ds * rayDir;

    startPos += temporalBayer64(gl_FragCoord.xy) * dStep;

    float visibility = 0.0;
    for(int i = 0; i < N_SAMPLE; i++){
        vec3 p = startPos + i * dStep;
        p = getShadowPos(vec4(p, 1.0)).xyz;
        visibility += texture(shadowtex0, p).r;
    }
    visibility /= N_SAMPLE;

    return saturate(visibility);
}

float MiePhase_fog(float cos_theta, float g){
    float g2 = g * g;

    return (1 - g2) / (4.0 * PI * pow((1 + g2 - 2 * g * cos_theta), 3.0 / 2.0));
}

vec3 applyFog(vec3 oriColor, float worldDis, vec3 cameraPos, vec3 worldDir, float fogVis){
    vec3 rayOri_pie= cameraPos + worldDir * fog_startDis;

    vec2 data = vec2(-max(0, rayOri_pie.y - fog_startHeight) * fog_b, -max(0, worldDis - fog_startDis) * worldDir.y * fog_b);
    vec2 expData = fastExp(data);
    float opticalThickness = fog_a * mix(1.0, fogVis, 0.65) * expData.x * (1.0 - expData.y) / worldDir.y;
    float extinction = fastExp(-opticalThickness);
    float fogAmount = 1 - extinction;

    float cos_theta = dot(worldDir, lightWorldDir);

    vec3 fogColor = mix(skyColor * 3.0, 
                    sunColor * 0.45,
                    fogVis * MiePhase_fog(cos_theta, 0.45));

    // return oriColor + fogColor * fogAmount;
    return mix(oriColor, fogColor, fogAmount);
}