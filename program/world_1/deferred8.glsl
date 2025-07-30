varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;

varying float isNoon, isNight, sunRiseSet;
varying float isNoonS, isNightS, sunRiseSetS;



#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/camera/colorToolkit.glsl"
#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"
#include "/lib/common/noise.glsl"

#include "/lib/camera/filter.glsl"

#include "/lib/atmosphere/atmosphericScattering.glsl"

#ifdef FSH

#include "/lib/common/gbufferData.glsl"
#include "/lib/atmosphere/fog.glsl"
#include "/lib/common/materialIdMapper.glsl"



float sampleLowFrequencyNoise(vec3 p){
    vec4 low_frequency_noises = texture(depthtex2, p + vec3(0.0, 0.2, 0.0));
    float low_freq_FBM = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + (low_frequency_noises.a * 0.125);
    float base_cloud = remapSaturate(low_frequency_noises.r, -2.0 * (1.0 - low_freq_FBM), 1.0, 0.0, 1.0);
    return base_cloud;
}

float sampleHighFrequencyNoise(vec3 p){
    vec3 high_frequency_noises = texture(colortex2, p + vec3(0.13333, 0.8, 0.76666)).rgb;
    float high_freq_FBM = (high_frequency_noises.r * 0.625) + (high_frequency_noises.g * 0.25) + (high_frequency_noises.b * 0.125);
    return high_freq_FBM;
}

vec2 sampleWeather(vec2 p){
    vec2 weatherData = texture(noisetex, p).rg;
    return weatherData;
}

vec2 cloudHeight_End = cameraPosition.y + vec2(-1200, 1500);

float sampleCloudDensity(vec3 cameraPos, bool doCheaply){
    float height_fraction = getHeightFractionForPoint(cameraPos.y, cloudHeight_End);
    if(height_fraction < 0.0 || height_fraction > 1.0) return 0.0;
    vec3 p = cameraPos;

    vec3 wind_direction = normalize(vec3(1.0, 0.0, 1.0));
    float cloud_speed = 10.0;
    p += wind_direction * frameTimeCounter * cloud_speed;

    float base_cloud = sampleLowFrequencyNoise(p * 0.00020);
    // vec2 weatherData = sampleWeather(p.xz * 0.000015);
    // float coverage = saturate(mix(weatherData.r, weatherData.g, 0.33) - 0.18);
    base_cloud = remapSaturate(base_cloud, 0.75, 1.0, 0.0, 1.0);

    float final_cloud = base_cloud;
	if(!doCheaply){
        float high_freq_FBM = sampleHighFrequencyNoise(p * 0.0035 - 0.025 * wind_direction * frameTimeCounter);
        float high_freq_noise_modifier = lerp(high_freq_FBM, 1.0 - high_freq_FBM, saturate(height_fraction * 10.0));
        final_cloud = remapSaturate(final_cloud, saturate(high_freq_noise_modifier * 0.60), 1.0, 0.0, 1.0);
        float coverage = remapSaturate(height_fraction, 0.0, 0.2, 0.0, 1.0) * 
                         remapSaturate(height_fraction, 0.8, 1.0, 1.0, 0.0);
        final_cloud *= coverage; 
    }

    final_cloud *= 0.0045;
    return saturate(final_cloud);
}

float dualLobPhase(float g0, float g1, float w, float cosTheta, float attenuation){
    return mix(hgPhase1(cosTheta, g0 * attenuation), hgPhase1(cosTheta, g1 * attenuation), w);
}

float powderEffect(float sampleDensity, float cos_angle){
    float powd = 1.0 - fastExp(-sampleDensity * 2.0);
    return lerp(1.0, powd, saturate((-cos_angle * 0.5) + 0.5)); // [-1,1]->[0,1]
}

float powderEffectNew(vec3 p, float VoL, float stepCloudDensity){
    float normalizeHeight = getHeightFractionForPoint(p.y, cloudHeight_End);
    float depthProbability = pow(
        clamp(stepCloudDensity * 10.0, 0.0, 1.0),       // clamp(stepCloudDensity * 10.0, 0.0, 1.0)
        remap(normalizeHeight, 0.3, 0.85, 0.5, 2.0));   // remapSaturate(normalizeHeight, 0.3, 0.85, 0.5, 2.0))
    depthProbability += 0.05;
    
    float verticalProbability = pow(remap(normalizeHeight, 0.0, 0.22, 0.1, 1.0), 0.8); // pow(remapSaturate(normalizeHeight, 0.07, 0.22, 0.1, 1.0), 0.8)
    float r = VoL * 0.5 + 0.5;
    r = r * r;
    verticalProbability = verticalProbability * (1.0 - r) + r;
    return depthProbability * verticalProbability;
}



float GetDirectScatterProbability(float CosTheta, float eccentricity, float SilverIntensity, float SilverSpread){
    return max(hgPhase1(CosTheta, eccentricity), SilverIntensity * hgPhase1(CosTheta, (0.99 - SilverSpread)));
}

float GetAttenuationProbability(float sampleDensity, float secondInensity, float secondSpread){
    return max(fastExp(-sampleDensity), (fastExp(-sampleDensity * secondSpread) * secondInensity));
}

float GetInScatterProbability(vec3 p, float ds_loded, float ds_power){
    float height_fraction = getHeightFractionForPoint(p.y, cloudHeight_End);
    ds_loded = saturate(pow(ds_loded, ds_power));
    float depth_probability = 0.05 + pow(ds_loded, remapSaturate(height_fraction, 0.3, 0.85, 0.5, 2.0));
    float vertical_probability = pow(remapSaturate(height_fraction, 0.07, 0.22, 0.2, 1.0), 0.8);
    float in_scatter_probability = depth_probability * vertical_probability;

    return in_scatter_probability;
}

vec3 computeScatteringIntegral(vec3 stepScattering, float density, float transmittance, float stepTransmittance) {
    float sigmaS = density;
    const float sigmaA = 0.0;
    vec3 sigmaE = max(vec3(1e-8f), sigmaA + sigmaS);
    vec3 scatterLitStep = stepScattering * sigmaS;
    scatterLitStep = transmittance * (scatterLitStep - scatterLitStep * stepTransmittance);
    return scatterLitStep / sigmaE;
}

float computeLightPathOpticalDepth(vec3 p, float initialStepSize, vec3 lightWorldDir, int N_SAMPLES) {
    float opticalDepth = 0.0;
    vec3 currentPos = p;
    float prevDensity = sampleCloudDensity(currentPos, false) * 0.66;
    float currentStepSize = initialStepSize;

    for (int i = 1; i <= N_SAMPLES; i++) {
        float t = float(i) / float(N_SAMPLES);
        currentStepSize = mix(initialStepSize, initialStepSize * 5.0, t);
        currentPos += lightWorldDir * currentStepSize;
    
        bool doCheaply = false;
        float currentDensity = sampleCloudDensity(currentPos, doCheaply);
        opticalDepth += 0.5 * (prevDensity + currentDensity) * currentStepSize;
        
        prevDensity = currentDensity;
    }
    
    return opticalDepth;
}

void cloudRayMarching(vec3 oriColor, vec3 startPos, vec3 worldPos, inout float transmittance, inout vec3 scattering, inout float cloudHitLength){
    transmittance = 1.0;
    scattering = vec3(0.0);

    vec3 worldDir = normalize(worldPos);
    float worldDis = length(worldPos);

    vec2 dis = intersectHorizontalAABB(startPos, worldDir, cloudHeight_End);    // 与云层交点的距离, 返回 vec2(min max)
    vec2 stepDis = calculateStepDistances(dis.x, dis.y, worldDis);    // 返回 到步进起点的距离，在起点后步进到终点的距离
    if(stepDis.y < 0.0001 || stepDis.x > 20000){
        // transmittance = 0.0;
        return;
    }

    float alpha = 0.0;

    float rayLength = stepDis.y;
    float stepSize = CLOUD_LARGE_STEP;
    float t = 0.0;
    int emptySteps = 0;
    bool inCloud = false;

    vec3 oriStartPos = startPos;
    startPos += worldDir * stepDis.x;
    startPos += worldDir * CLOUD_SMALL_STEP * temporalBayer64(gl_FragCoord.xy);

    vec3 hitPos = startPos;
    bool isHit = false;

    for(int i = 0; i < CLOUD_MAX_STEPS; i++){
        if(stepDis.x + t > 20000 || t >= rayLength + CLOUD_LARGE_STEP || t > CLOUD_MAX_DISTANCE || transmittance < 0.01){
            break;
        }
        vec3 pos = startPos + t * worldDir;
        float density;
        if(!inCloud){
            density = sampleCloudDensity(pos, true);
            if (density > 0.00001){
                t -= stepSize;
                stepSize = CLOUD_SMALL_STEP;
                inCloud = true;
                emptySteps = 0;
                continue;
            }
        }else{
            density = sampleCloudDensity(pos, false);
            if(density > 0.0000075){
                if(!isHit){
                    hitPos = pos;
                    isHit = true;
                }



                float opticalDepth = stepSize * density;
                float stepTransmittance = GetAttenuationProbability(opticalDepth, 0.6, 0.2);    // float sampleDensity, float secondInensity, float secondSpread
                transmittance *= stepTransmittance;

                float VoL = dot(worldDir, lightWorldDir);
                float iVoL = dot(worldDir, -lightWorldDir);

                // float lightPathOpticalDepth = computeLightPathOpticalDepth(pos, 50, lightWorldDir, 3);
                // float attenuation = GetAttenuationProbability(lightPathOpticalDepth, 0.6, 0.2);
				float attenuation = 1.0;

                float inScatter = GetInScatterProbability(pos, opticalDepth, 1.5);

                float phase = GetDirectScatterProbability(VoL, 0.2, 0.6, 0.4);  // float CosTheta, float eccentricity, float SilverIntensity, float SilverSpread
                

                vec3 stepScattering = attenuation * inScatter * phase * endColor;
                float sigmaS = density;
                scattering += computeScatteringIntegral(stepScattering, sigmaS, transmittance, stepTransmittance);



                emptySteps = 0;
            }else{
                emptySteps++;
                if(emptySteps >= CLOUD_EMPTY_STEPS){
                    stepSize = CLOUD_LARGE_STEP;
                    inCloud = false;
                }
            }
        }

        t += stepSize;
    }
    cloudHitLength = length(hitPos - oriStartPos);
}


vec3 drawStars(vec3 worldDir){
    vec3 uv = worldDir;
    uv *= STARS_DENSITY * 1.25;
    vec3 ipos = floor(uv);
    vec3 fpos = fract(uv);
    vec3 targetPoint = rand3_3(ipos + sin(frameTimeCounter * 0.5) * 0.00005);

    float dist = length(fpos - targetPoint);
    float size = STARS_SIZE;
    float isStar = 1.0 - step(size, dist);

    return 0.45 * endColor * vec3(1.0, 0.9, 0.7) * isStar;
}

float fakeCaustics(vec3 pos){
    float height = 64.0;

    // 点积向上向量和光照方向向量得到cos值   预定高度和实际高度的高度差
    float cosUpSunpos = abs(dot(vec3(0.0,1.0,0.0), lightWorldDir));
    float hDiff = abs(height - pos.y);

    // 高度差 * （1除以cos）得到斜边长度   sqrt（斜边的平方-邻边的平方）得到对边长度
    float hyp = hDiff * (1 / cosUpSunpos + 0.01);
    float dist = sqrt(hyp * hyp - hDiff * hDiff);

    // 单位化光照向量，乘上对边长度得到偏移向量
    vec3 unit = normalize(vec3(lightWorldDir.x, 0.0, lightWorldDir.z));
    vec3 offset = dist * unit;

    vec2 waveUV = vec2(0.0);
    if(pos.y < 64){
        waveUV = pos.xz + offset.xz;
    }else{
        waveUV = pos.xz - offset.xz;
    }

    // worley 伪造焦散，最后用pow值调整曲线
    float caustics  = texture(depthtex2, vec3(waveUV * 0.015, 0.0) + frameTimeCounter * 0.025).g;


    return caustics;
}

vec3 underWaterFog(vec3 color, vec3 worldDir, float worldDis){
    const float numCount = 10.0;
    float stepSize = 6.0;
    float stepSum = numCount * stepSize;
    vec3 stepVec = stepSize * worldDir;

    float density = 0.0;
    int c = 0;
    vec3 p = stepVec * temporalBayer64(gl_FragCoord.xy);
    for(int i = 0; i < numCount; ++i){
        if(length(p) > worldDis) break;
		
		vec3 shadowPos = getShadowPos(vec4(p, 1.0)).xyz;
        float z_sample = textureLod(shadowtex1, shadowPos.st, 0).r;
        if(shadowPos.z < z_sample){
            float caustics = pow(fakeCaustics(p + cameraPosition), 5.0);
        	density += caustics;
        }
        ++c;
        p += stepVec;
    }
    density /= c + 0.01;
    // density = (density * min(worldDis, stepSum) + max(worldDis - stepSum, 0.0)) / worldDis;
    float eyeBrightness = eyeBrightnessSmooth.y / 240.0;
    density = mix(1.0, density * 20, 0.66);

    float phase0 = hgPhase1(dot(sunWorldDir, worldDir), 0.25);
    float phase1 = hgPhase1(dot(sunWorldDir, worldDir), 0.55) * 0.5;
    float phase = phase0 + phase1;

    vec3 underWaterFogColor = 0.065 * density * phase * endColor;
    color.rgb = mix(color, underWaterFogColor, 0.5 * pow(saturate(worldDis / 60.0), 1.0));

    // color += rand2_1(texcoord + sin(frameTimeCounter)) / 102.0;
    return vec3(color);
}


void main() {
	vec4 color = texture(colortex0, texcoord);

	float depth0 = texture(depthtex0, texcoord).r;
	vec4 viewPos0 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth0, 1.0));
	vec4 worldPos0 = viewPosToWorldPos(viewPos0);
	float worldDis0 = length(worldPos0);

	float depth1 = texture(depthtex1, texcoord).r;
    vec4 viewPos1 = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth1, 1.0));
	vec4 worldPos1 = viewPosToWorldPos(viewPos1);
	float worldDis1 = length(worldPos1);

	vec3 viewDir = normalize(viewPos1.xyz);
	vec3 worldDir = normalize(worldPos1.xyz);

	vec3 fogColor = mix(endColor * 10.0, endColor, pow(abs(dot(upWorldDir, worldDir)), 0.45)) * 0.0012;
	if(skyB > 0.5){
		color.rgb = fogColor;
		color.rgb += drawStars(worldDir);

        float dist1 = min(20000.0, worldDis0);

        float cloudTransmittance = 1.0;
        vec3 cloudScattering = vec3(0.0);
        float cloudHitLength = 0.0;
        #ifdef VOLUMETRIC_CLOUDS
            cloudRayMarching(color.rgb, camera, worldDir * dist1, cloudTransmittance, cloudScattering, cloudHitLength);
        #endif
        color.rgb = color.rgb * cloudTransmittance + cloudScattering * 2.;
	}
	
	color.rgb = underWaterFog(color.rgb, worldDir, worldDis0);

	// color.rgb = vec3(texture(colortex1, texcoord).rgb);
	color.rgb = max(color.rgb, BLACK);

/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunWorldDir = normalize(vec3(0.0, 1.0, tan(-sunPathRotation * PI / 180.0)));
    moonWorldDir = sunWorldDir;
    lightWorldDir = sunWorldDir;

	sunViewDir = normalize((gbufferModelView * vec4(sunWorldDir, 0.0)).xyz);
	moonViewDir = sunViewDir;
	lightViewDir = sunViewDir;

	isNoon = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION);
	isNight = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION);
	sunRiseSet = saturate(1 - isNoon - isNight);

	isNoonS = saturate(dot(sunWorldDir, upWorldDir) * NOON_DURATION_SLOW);
	isNightS = saturate(dot(moonWorldDir, upWorldDir) * NIGHT_DURATION_SLOW);
	sunRiseSetS = saturate(1 - isNoon - isNight);

	sunColor = getSunColor() * (1.0 - 0.95  * isNight);
	skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif