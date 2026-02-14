float d_p2a = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r + atmosphere_h).y;
float d_p2e = RaySphereIntersection(earthPos, worldDir, vec3(0.0), earth_r).x;
float d = d_p2e > 0.0 ? d_p2e : d_p2a;
float dist1 = skyB > 0.5 ? d : worldDis1;

float cloudTransmittance = 1.0;
vec3 cloudScattering = vec3(0.0);
float cloudHitLength = 0.0;
#ifdef VOLUMETRIC_CLOUDS
	cloudRayMarching(color.rgb, camera, worldDir * dist1, cloudTransmittance, cloudScattering, cloudHitLength);
#endif

vec3 skyBaseColor = texture(colortex1, texcoord * 0.5 + 0.5).rgb * SKY_BASE_COLOR_BRIGHTNESS;
vec3 celestial = drawCelestial(worldDir, cloudTransmittance, true);

color.rgb = skyBaseColor;	
color.rgb += celestial;
cloudTransmittance = max(cloudTransmittance, 0.0);
cloudScattering = max(cloudScattering, vec3(0.0));
color.rgb = color.rgb * cloudTransmittance + cloudScattering * 5.0;

if(cloudTransmittance < 1.0){
	color.rgb = mix(skyBaseColor + celestial, color.rgb, 
			mix(saturate(1.0 * pow(getLuminance(cloudScattering), 1.0)), exp(-cloudHitLength / (9000 * (1.0 + 1.0 * sunRiseSetS))) * 0.90, 0.60));
}