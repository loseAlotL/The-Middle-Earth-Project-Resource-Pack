#ifndef TMEP_ATMOSPHERE_GLSL
#define TMEP_ATMOSPHERE_GLSL

#include <tmep:world.glsl>
#include <tmep:lighting.glsl>

const vec3 ATMOS_ZENITH_DAY = vec3(0.007, 0.0327, 0.2441);
const vec3 ATMOS_MID_DAY = vec3(0.0294, 0.1134, 0.426);
const vec3 ATMOS_HORIZON_DAY = vec3(0.3833, 0.6006, 1.0345);
const float ATMOS_SKY_GRADIENT = 2.4;
const vec3 ATMOS_ZENITH_NIGHT = vec3(0.0035, 0.0035, 0.018);
const vec3 ATMOS_HORIZON_NIGHT = vec3(0.004, 0.014, 0.032);
const float ATMOS_SUNSET_HORIZON = 0.9;
const vec3 ATMOS_TWILIGHT_ZENITH = vec3(0.045, 0.03, 0.15);
const vec3 ATMOS_TWILIGHT_MID = vec3(0.42, 0.14, 0.34);
const vec3 ATMOS_TWILIGHT_SUN = vec3(1.5, 0.55, 0.14);
const vec3 ATMOS_TWILIGHT_AWAY = vec3(0.36, 0.2, 0.38);
const vec3 ATMOS_TWILIGHT_AWAY_MID = vec3(0.06, 0.06, 0.17);
const vec3 ATMOS_EARTH_SHADOW = vec3(0.03, 0.035, 0.085);
const float ATMOS_SKY_VARIATION = 0.08;
const float ATMOS_REGION_SCALE = 0.00012;
const float ATMOS_HALO = 0.22;
const float ATMOS_RAINBOW = 0.35;
const float ATMOS_BIRDS = 0.0;
const float ATMOS_CONTRAILS = 0.0;
const float ATMOS_IRIDESCENCE = 0.5;
float atmosJitter = 0.5;
float atmosStorm = 0.0;
float atmosFlash = 0.0;
float atmosAuroraForce = 0.0;
const float ATMOS_GLORY = 0.6;
const vec3 ATMOS_DAWN_ZENITH = vec3(0.03, 0.055, 0.17);
const vec3 ATMOS_DAWN_MID = vec3(0.34, 0.22, 0.36);
const vec3 ATMOS_DAWN_SUN = vec3(1.3, 0.78, 0.38);
const vec3 ATMOS_DAWN_AWAY = vec3(0.2, 0.23, 0.36);
const float ATMOS_CIRRUS_HEIGHT = 700.0;
const float ATMOS_CIRRUS_COVERAGE = 0.56;
const float ATMOS_CIRRUS_OPACITY = 0.5;
const float ATMOS_AURORA = 1.0;
const float ATMOS_STAR_DENSITY = 0.22;
const float ATMOS_STAR_BRIGHTNESS = 1.0;
const float ATMOS_MILKY_WAY = 1.0;
const float ATMOS_MOON_HALO = 0.14;
const float ATMOS_SHOOTING_STARS = 1.0;
const float ATMOS_SKY_RAYS = 0.22;
const float ATMOS_SUN_GLOW = 1.0;
const float ATMOS_SUN_DISC = 40.0;
const float ATMOS_SUN_SIZE = 0.9;
const float ATMOS_MOON_SIZE = 1.5;
const float ATMOS_SUN_HALO = 8.0;
const float ATMOS_CLOUD_BOTTOM = 300.0;
const float ATMOS_CLOUD_THICKNESS = 90.0;
const float ATMOS_CLOUD_COVERAGE = 0.52;
const float ATMOS_CLOUD_SCALE = 0.0085;
const float ATMOS_CLOUD_FRONTS = 0.1;
const float ATMOS_TOWER_CELL = 1600.0;
const float ATMOS_TOWER_CHANCE = 0.38;
const float ATMOS_TOWER_REACH = 4000.0;
const float ATMOS_TOWER_BASE = 300.0;
const vec2 ATMOS_TOWER_HEIGHT = vec2(600.0, 1000.0);
const vec2 ATMOS_TOWER_RADIUS = vec2(220.0, 340.0);
const float ATMOS_TOWER_BASE_SPREAD = 120.0;
const float ATMOS_TOWER_OUTLINE = 0.6;
const int ATMOS_TOWER_STEPS = 26;
const float ATMOS_TOWER_SPACING = 56.0;
const float ATMOS_TOWER_PUFFS = 0.9;
const float ATMOS_CLOUD_AERIAL = 3200.0;
const float ATMOS_CLOUD_WISPS = 0.4;
const float ATMOS_ALTO_HEIGHT = 480.0;
const float ATMOS_ALTO_COVERAGE = 0.55;
const float ATMOS_ALTO_OPACITY = 0.5;
const float ATMOS_CLOUD_SHARPNESS = 0.05;
const float ATMOS_CLOUD_SUN = 1.15;
const vec3 ATMOS_CLOUD_SHADOW = vec3(0.16, 0.15, 0.3);
const float ATMOS_CLOUD_SILVER = 3.5;
const vec2 ATMOS_CLOUD_WIND = vec2(3.0, 1.2);
const float ATMOS_HAZE_DENSITY = 0.0018;
const float ATMOS_HAZE_HEIGHT = 90.0;
const float ATMOS_HAZE_STRENGTH = 1.0;
const float ATMOS_MORNING_MIST = 1.0;
const float ATMOS_GODRAYS = 0.35;

float atmos_hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float atmos_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(atmos_hash(i), atmos_hash(i + vec2(1.0, 0.0)), u.x), mix(atmos_hash(i + vec2(0.0, 1.0)), atmos_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float atmos_fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        if (i >= octaves) {
            break;
        }
        value += amplitude * atmos_noise(p);
        p = mat2(1.6, 1.2, -1.2, 1.6) * p + vec2(17.3, 9.1);
        amplitude *= 0.5;
    }
    return value;
}

LightState atmos_state(Camera camera) {
    return light_state(camera.daytime / 24000.0, clamp(camera.weather, 0.0, 1.0));
}

void atmos_apply_weather(sampler2D weather, inout LightState state) {
    if (textureSize(weather, 0).x < 2) {
        return;
    }
    vec4 hold = texelFetch(weather, ivec2(1, 0), 0);
    if (hold.a > 0.5) {
        state.rain = hold.r;
        atmosStorm = hold.g;
        atmosFlash = hold.b;
    }
}

vec3 atmos_lightning(vec3 direction, float seconds) {
    float glow = atmosFlash * 1.3;
    if (atmosStorm > 0.01) {
        const float RATE = 5.0;
        float slot = floor(seconds * RATE);
        for (int k = 0; k < 3; k++) {
            float s = slot - float(k);
            float chance = atmos_hash(vec2(s, 17.3));
            if (chance < 1.0 - 0.07 * atmosStorm) {
                continue;
            }
            float age = seconds - s / RATE;
            float angle = atmos_hash(vec2(s, 4.1)) * 6.2831853;
            float elevation = mix(0.06, 0.55, atmos_hash(vec2(s, 9.7)));
            vec3 center = normalize(vec3(cos(angle), elevation, sin(angle)));
            float spread = mix(3.0, 9.0, atmos_hash(vec2(s, 2.3)));
            float flicker = exp(-age * 6.0) * (0.55 + 0.45 * step(0.45, fract(age * 19.0 + chance * 7.0)));
            glow += exp(-acos(clamp(dot(direction, center), -1.0, 1.0)) * spread) * flicker * atmosStorm * 1.6;
        }
    }
    if (glow <= 0.001) {
        return vec3(0.0);
    }
    float grain = atmos_fbm(direction.xz / max(direction.y + 0.12, 0.08) * 1.8 + 5.1, 3);
    return vec3(0.72, 0.8, 1.0) * glow * mix(0.35, 1.4, grain) * smoothstep(-0.02, 0.06, direction.y);
}

vec3 atmos_sun_tint(LightState state) {
    return state.sunColor / 0.58597;
}

vec2 atmos_region_point(vec2 xz, float time) {
    return (xz - ATMOS_CLOUD_WIND * time * 0.4) * ATMOS_REGION_SCALE;
}

float atmos_region_towers(vec2 xz, float time) {
    return mix(0.4, 1.0, smoothstep(0.42, 0.62, atmos_fbm(atmos_region_point(xz, time) + 1.3, 3)));
}

float atmos_region_puffs(vec2 xz, float time) {
    return mix(0.35, 1.0, smoothstep(0.34, 0.56, atmos_fbm(atmos_region_point(xz, time) * 1.3 + 7.1, 3)));
}

float atmos_region_cirrus(vec2 xz, float time) {
    return mix(0.25, 1.0, smoothstep(0.36, 0.58, atmos_fbm(atmos_region_point(xz, time) * 0.9 + 13.7, 3)));
}

float atmos_region_alto(vec2 xz, float time) {
    return smoothstep(0.46, 0.64, atmos_fbm(atmos_region_point(xz, time) * 1.1 + 21.9, 3));
}

float atmos_azimuth_away(vec3 direction, vec3 sun) {
    vec3 flatSun = vec3(sun.x, 0.0, sun.z) / max(length(sun.xz), 1e-4);
    return 1.0 - smoothstep(-0.85, 0.35, dot(direction, flatSun));
}

float atmos_away_smooth(vec3 direction, vec3 sun) {
    vec3 flatSun = vec3(sun.x, 0.0, sun.z) / max(length(sun.xz), 1e-4);
    return pow(clamp(0.5 - 0.5 * dot(direction, flatSun), 0.0, 1.0), 1.3);
}

float atmos_dusk_progress(vec3 sun) {
    return 1.0 - smoothstep(-0.16, 0.1, sun.y);
}

float atmos_night_dome(vec3 direction, vec3 sun) {
    float progress = atmos_dusk_progress(sun);
    if (progress <= 0.0) {
        return 0.0;
    }
    vec3 antiFlat = -vec3(sun.x, 0.0, sun.z) / max(length(sun.xz), 1e-4);
    float angle = acos(clamp(dot(direction, antiFlat), -1.0, 1.0));
    return pow(1.0 - smoothstep(0.0, mix(0.8, 2.4, progress), angle), 0.8) * smoothstep(0.0, 0.2, progress);
}

float atmos_horizon_shadow(vec3 direction, vec3 sun) {
    return pow(1.0 - smoothstep(0.0, 0.35, max(direction.y, 0.0)), 1.5) * pow(atmos_away_smooth(direction, sun), 0.7) * smoothstep(0.0, 0.25, atmos_dusk_progress(sun));
}

float atmos_earth_shadow(vec3 direction, vec3 sun) {
    return 1.0 - (1.0 - atmos_night_dome(direction, sun) * mix(0.7, 0.97, atmos_dusk_progress(sun))) * (1.0 - atmos_horizon_shadow(direction, sun) * 0.92);
}

vec3 atmos_shadow_tint(vec3 color, float amount) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(color, vec3(0.55, 0.62, 0.95) * luma * 0.5, amount);
}

vec3 atmos_sky_detail(vec3 direction, vec3 sun, LightState state, bool variation) {
    float up = clamp(direction.y, 0.0, 1.0);
    float day = smoothstep(-0.12, 0.08, sun.y);
    float low = smoothstep(-0.2, 0.0, sun.y) * (1.0 - smoothstep(0.03, 0.4, sun.y));
    vec3 tint = atmos_sun_tint(state);
    float facing = dot(direction, sun);
    float towardSun = pow(max(facing, 0.0) * 0.5 + 0.5, 3.0);
    float gradient = pow(1.0 - up, ATMOS_SKY_GRADIENT);

    vec3 dayColor = mix(mix(ATMOS_ZENITH_DAY, ATMOS_MID_DAY, smoothstep(0.0, 0.55, gradient)), ATMOS_HORIZON_DAY, smoothstep(0.45, 1.0, gradient));
    dayColor = mix(dayColor, vec3(1.25, 1.15, 1.0) * dot(ATMOS_HORIZON_DAY, vec3(0.2126, 0.7152, 0.0722)), pow(max(facing, 0.0), 6.0) * 0.35);
    float dawn = smoothstep(-0.15, 0.15, sun.x);
    vec3 zenithTwilight = mix(ATMOS_TWILIGHT_ZENITH, ATMOS_DAWN_ZENITH, dawn);
    float awaySmooth = atmos_away_smooth(direction, sun);
    vec3 midTwilight = mix(ATMOS_TWILIGHT_AWAY_MID, mix(ATMOS_TWILIGHT_MID, ATMOS_DAWN_MID, dawn), pow(1.0 - awaySmooth, 0.8));
    vec3 sunTwilight = mix(ATMOS_TWILIGHT_SUN * tint / max(tint.r, 1e-3), ATMOS_DAWN_SUN, dawn);
    vec3 awayTwilight = mix(mix(ATMOS_TWILIGHT_AWAY, ATMOS_DAWN_AWAY, dawn) * 0.75, ATMOS_TWILIGHT_AWAY_MID * 1.4, smoothstep(-0.02, 0.06, 0.04 - sun.y));
    vec3 twilightHorizon = mix(awayTwilight, sunTwilight, towardSun);
    vec3 twilight = mix(mix(zenithTwilight, midTwilight, smoothstep(0.0, 0.65, gradient)), twilightHorizon, smoothstep(0.45, 1.0, gradient));
    twilight *= mix(1.0, 0.55, awaySmooth * (1.0 - smoothstep(0.1, 0.3, sun.y)));
    twilight *= mix(0.25, 1.0, smoothstep(-0.2, 0.02, sun.y));
    vec3 night = mix(ATMOS_ZENITH_NIGHT, ATMOS_HORIZON_NIGHT, gradient);

    vec3 sky = mix(night, dayColor, day);
    sky = mix(sky, twilight, low * 0.9);
    if (variation) {
        float hue = atmos_fbm(direction.xz / max(direction.y + 0.35, 0.2) * 1.3 + vec2(3.7, 1.9), 3) - 0.5;
        sky *= 1.0 + hue * ATMOS_SKY_VARIATION * vec3(1.2, 0.8, 1.0);
    }

    float angle = acos(clamp(facing, -1.0, 1.0));
    float visible = smoothstep(-0.1, 0.05, sun.y);
    sky += tint * (exp(-angle * ATMOS_SUN_HALO) * (0.2 + 1.0 * low) + exp(-angle * 2.5) * 0.04 + exp(-angle * 1.4) * 0.9 * low) * ATMOS_SUN_GLOW * visible;
    float earthShadow = atmos_earth_shadow(direction, sun);
    if (earthShadow > 0.0) {
        float deepest = max(atmos_night_dome(direction, sun), atmos_horizon_shadow(direction, sun));
        vec3 shadowColor = ATMOS_EARTH_SHADOW * mix(1.3, 0.45, atmos_dusk_progress(sun)) * mix(1.0, 0.6, deepest);
        sky = mix(sky, min(sky, shadowColor), earthShadow);
    }
    sky = mix(sky, sky * 0.5, smoothstep(0.0, 0.25, -direction.y));
    float gray = dot(sky, vec3(0.2126, 0.7152, 0.0722));
    sky = mix(sky, vec3(gray) * vec3(0.95, 1.0, 1.05) * 0.8, state.rain * mix(0.35, 0.85, atmosStorm));
    return sky * mix(1.0, 0.6, state.rain) * (1.0 - state.rain * 0.25 * pow(1.0 - up, 3.0));
}

vec3 atmos_sky(vec3 direction, vec3 sun, LightState state) {
    return atmos_sky_detail(direction, sun, state, true);
}

vec3 atmos_sky_smooth(vec3 direction, vec3 sun, LightState state) {
    return atmos_sky_detail(direction, sun, state, false);
}

vec4 atmos_cirrus(vec3 origin, vec3 direction, float time, vec3 sun, LightState state) {
    if (direction.y < 0.02 || origin.y > ATMOS_CIRRUS_HEIGHT) {
        return vec4(0.0);
    }
    float t = (ATMOS_CIRRUS_HEIGHT - origin.y) / direction.y;
    vec2 p = origin.xz + direction.xz * t + ATMOS_CLOUD_WIND * time * 1.6;
    vec2 wind = normalize(ATMOS_CLOUD_WIND);
    vec2 stretched = vec2(dot(p, wind) * 0.0005, dot(p, vec2(-wind.y, wind.x)) * 0.0032);
    float amount = smoothstep(0.38, 0.7, atmos_fbm(p * 0.00025 + 5.3, 3)) * ATMOS_CIRRUS_OPACITY * smoothstep(0.02, 0.15, direction.y) * exp(-t / 9000.0) * (1.0 - state.rain * 0.8);
    if (amount <= 0.002) {
        return vec4(0.0);
    }
    amount *= atmos_region_cirrus(origin.xz + direction.xz * t, time);
    if (amount <= 0.002) {
        return vec4(0.0);
    }
    float streaks = atmos_fbm(stretched + atmos_fbm(p * 0.0015, 2) * 1.2, 4);
    float cover = smoothstep(ATMOS_CIRRUS_COVERAGE, ATMOS_CIRRUS_COVERAGE + 0.2, streaks) * amount;
    vec3 tint = atmos_sun_tint(state);
    float facing = max(dot(direction, sun), 0.0);
    vec3 color = mix(vec3(1.0), tint, 0.3 + 0.7 * (1.0 - smoothstep(0.05, 0.4, sun.y))) * (state.sunVisibility * (1.0 + 1.5 * pow(facing, 4.0))) + vec3(0.03, 0.04, 0.08) * state.moonVisibility;
    return vec4(color * cover, cover);
}

vec3 atmos_star_hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yzz) * p.zyx);
}

vec3 atmos_celestial_frame(vec3 direction, vec3 sun) {
    float angle = atan(-sun.x, sun.y);
    float c = cos(angle);
    float s = sin(angle);
    return vec3(direction.x * c + direction.y * s, -direction.x * s + direction.y * c, direction.z);
}

vec3 atmos_stars(vec3 direction, vec3 sun, float time) {
    vec3 d = atmos_celestial_frame(direction, sun);
    vec3 total = vec3(0.0);
    for (int layer = 0; layer < 2; layer++) {
        float scale = layer == 0 ? 180.0 : 420.0;
        vec3 grid = d * scale;
        vec3 cell = floor(grid);
        vec3 h = atmos_star_hash(cell + float(layer) * 71.0);
        if (h.x < ATMOS_STAR_DENSITY * (layer == 0 ? 0.35 : 1.0)) {
            vec3 center = (cell + 0.2 + 0.6 * atmos_star_hash(cell + 13.7)) / scale;
            float dist = length(normalize(center) - d) * scale;
            float size = layer == 0 ? 0.22 : 0.14;
            float point = exp(-dist * dist / (size * size));
            float twinkle = 0.7 + 0.3 * sin(time * (2.0 + h.y * 4.0) + h.z * 40.0);
            vec3 color = mix(vec3(0.65, 0.78, 1.0), vec3(1.0, 0.86, 0.7), h.y);
            total += color * point * twinkle * (layer == 0 ? 1.4 : 0.6) * (0.4 + h.z);
            if (layer == 0 && h.z > 0.88) {
                vec3 offset = d - normalize(center);
                vec3 axisA = normalize(cross(normalize(center), vec3(0.0, 0.0, 1.0)));
                vec3 axisB = cross(normalize(center), axisA);
                vec2 local = vec2(dot(offset, axisA), dot(offset, axisB)) * scale;
                float cross4 = exp(-abs(local.x) * 1.2) * exp(-abs(local.y) * 14.0) + exp(-abs(local.y) * 1.2) * exp(-abs(local.x) * 14.0);
                total += color * cross4 * twinkle * 1.6;
            }
        }
    }
    float band = exp(-pow(d.x * 0.9 + d.z * 0.45, 2.0) * 9.0);
    vec2 skyPlane = vec2(dot(d, vec3(0.35, 1.1, -0.8)), dot(d, vec3(-0.9, 0.3, 0.75)));
    float dust = atmos_fbm(skyPlane * 5.0, 4);
    float lanes = atmos_fbm(skyPlane * 14.0 + 3.0, 4);
    float nebula = atmos_fbm(skyPlane * 2.5 + 9.0, 3);
    vec3 hue = mix(mix(vec3(0.95, 0.35, 0.75), vec3(0.3, 0.75, 1.0), nebula), vec3(0.75, 0.55, 1.0), dust * 0.5);
    float glow = band * (0.35 + 0.65 * smoothstep(0.3, 0.8, dust)) * (1.0 - 0.7 * smoothstep(0.5, 0.75, lanes));
    vec3 milky = hue * (glow * 0.045 + pow(band, 6.0) * 0.03) * ATMOS_MILKY_WAY;
    float slot = floor(time / 6.0);
    vec3 meteorSeed = atmos_star_hash(vec3(slot, 3.1, 7.7));
    vec3 meteor = vec3(0.0);
    float progress = fract(time / 6.0) * 4.0;
    if (meteorSeed.x < 0.55 * ATMOS_SHOOTING_STARS && progress < 1.0) {
        vec3 start = normalize(vec3(meteorSeed.y * 2.0 - 1.0, 0.45 + meteorSeed.z * 0.5, atmos_star_hash(vec3(slot, 9.0, 1.0)).x * 2.0 - 1.0));
        vec3 travel = normalize(cross(start, vec3(meteorSeed.z - 0.5, 1.0, meteorSeed.y - 0.5)));
        vec3 head = normalize(start + travel * progress * 0.35);
        vec3 tail = normalize(start + travel * max(progress - 0.25, 0.0) * 0.35);
        vec3 segment = head - tail;
        float along = clamp(dot(direction - tail, segment) / max(dot(segment, segment), 1e-6), 0.0, 1.0);
        float miss = length(direction - (tail + segment * along));
        meteor = vec3(0.85, 0.92, 1.0) * exp(-miss * 2200.0) * along * along * sin(progress * 3.14159) * 0.6;
    }
    return (total * 0.035 * ATMOS_STAR_BRIGHTNESS + milky) * smoothstep(0.0, 0.25, direction.y + 0.05) + meteor;
}

vec3 atmos_celestial(vec3 direction, vec3 sun, LightState state) {
    vec3 tint = atmos_sun_tint(state);
    float sunCos = cos(radians(ATMOS_SUN_SIZE));
    float night = max(smoothstep(-0.02, 0.12, -sun.y), (1.0 - smoothstep(-0.06, 0.06, sun.y)) * atmos_azimuth_away(direction, sun) * 0.6);
    float sunDisc = smoothstep(sunCos - (1.0 - sunCos) * 0.5, sunCos, dot(direction, sun)) * smoothstep(-0.05, 0.02, sun.y);
    vec3 moon = -sun;
    float moonFacing = dot(direction, moon);
    float moonCos = cos(radians(ATMOS_MOON_SIZE));
    float moonDisc = smoothstep(moonCos - (1.0 - moonCos) * 0.4, moonCos, moonFacing);
    vec3 up = abs(moon.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 right = normalize(cross(up, moon));
    vec3 top = cross(moon, right);
    vec2 local = vec2(dot(direction, right), dot(direction, top)) / max(sin(radians(ATMOS_MOON_SIZE)), 1e-4);
    float maria = smoothstep(0.45, 0.7, atmos_fbm(local * 2.2 + 4.1, 4));
    vec3 moonSurface = mix(vec3(0.95, 0.96, 1.0), vec3(0.62, 0.66, 0.78), maria) * (1.0 - 0.25 * dot(local, local));
    float moonAngle = acos(clamp(moonFacing, -1.0, 1.0));
    float corona = exp(-pow((moonAngle - radians(ATMOS_MOON_SIZE) * 5.0) * 40.0, 2.0)) * 0.08;
    vec3 moonHalo = vec3(0.45, 0.55, 0.95) * (exp(-moonAngle * 18.0) * 0.5 + exp(-moonAngle * 4.0) * 0.15 + corona) * ATMOS_MOON_HALO;
    vec3 moonLight = (moonSurface * moonDisc * 0.9 + moonHalo) * smoothstep(-0.05, 0.08, moon.y);
    vec3 stars = night * (1.0 - state.rain) > 0.001 ? atmos_stars(direction, sun, GameTime * 1200.0) * night * (1.0 - state.rain) * (1.0 - moonDisc) : vec3(0.0);
    return (tint * sunDisc * ATMOS_SUN_DISC + moonLight) * (1.0 - state.rain * 0.9) + stars;
}

vec3 atmos_basis_right(vec3 center) {
    vec3 up = abs(center.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    return normalize(cross(up, center));
}

vec3 atmos_optics(vec3 direction, vec3 sun, LightState state, float cirrus) {
    vec3 result = vec3(0.0);
    float sunUp = smoothstep(-0.02, 0.06, sun.y);
    float rainbowChance = clamp(state.rain * 4.0, 0.0, 1.0) * clamp((1.0 - state.rain) * 3.0, 0.0, 1.0);
    if (sunUp <= 0.0 || (cirrus * ATMOS_HALO <= 0.001 && rainbowChance * ATMOS_RAINBOW <= 0.0)) {
        return result;
    }
    float theta = degrees(acos(clamp(dot(direction, sun), -1.0, 1.0)));
    float ring = exp(-pow((theta - 22.0) / 1.1, 2.0));
    vec3 ringColor = mix(vec3(1.0, 0.55, 0.35), vec3(0.8, 0.9, 1.0), smoothstep(21.2, 23.2, theta));
    result += ringColor * ring * ATMOS_HALO * cirrus * sunUp * 0.25;
    float low = 1.0 - smoothstep(0.1, 0.5, sun.y);
    vec3 flatSun = normalize(vec3(sun.x, 0.0, sun.z) + vec3(1e-4));
    float dogAngle = radians(22.0 + 8.0 * max(sun.y, 0.0));
    for (int side = -1; side <= 1; side += 2) {
        float a = dogAngle * float(side);
        vec3 dogFlat = vec3(flatSun.x * cos(a) - flatSun.z * sin(a), 0.0, flatSun.x * sin(a) + flatSun.z * cos(a));
        vec3 dog = normalize(dogFlat * sqrt(max(1.0 - sun.y * sun.y, 0.0)) + vec3(0.0, sun.y, 0.0));
        vec3 offset = direction - dog;
        vec3 right = atmos_basis_right(dog);
        vec2 local = vec2(dot(offset, right), offset.y) / radians(1.0);
        float spot = exp(-(local.x * local.x * 0.25 + local.y * local.y * 1.2));
        vec3 spectrum = 0.55 + 0.45 * cos(6.2831853 * (local.x * float(side) * 0.12 + vec3(0.0, 0.33, 0.67)));
        result += spectrum * spot * ATMOS_HALO * cirrus * low * sunUp * 0.9;
    }
    float bowAngle = degrees(acos(clamp(dot(direction, -sun), -1.0, 1.0)));
    float bowStrength = clamp(state.rain * 4.0, 0.0, 1.0) * mix(0.55, 1.0, clamp((1.0 - state.rain) * 3.0, 0.0, 1.0)) * (1.0 - atmosStorm) * sunUp * smoothstep(0.0, 0.05, direction.y);
    if (bowStrength > 0.0) {
        float primary = clamp((42.3 - bowAngle) / 2.0, 0.0, 1.0);
        float band = exp(-pow((bowAngle - 41.3) / 1.2, 2.0));
        vec3 bow = (0.5 + 0.5 * cos(6.2831853 * (primary * 0.8 + vec3(0.0, 0.33, 0.67)))) * band;
        float secondary = exp(-pow((bowAngle - 51.5) / 1.6, 2.0));
        bow += (0.5 + 0.5 * cos(6.2831853 * ((1.0 - clamp((bowAngle - 50.5) / 2.2, 0.0, 1.0)) * 0.8 + vec3(0.0, 0.33, 0.67)))) * secondary * 0.4;
        result += bow * bowStrength * ATMOS_RAINBOW;
    }
    return result;
}

float atmos_aurora_region(vec3 origin) {
    float region = atmos_fbm(origin.xz * 0.00025 + vec2(41.7, -13.3), 3);
    float north = smoothstep(0.0, 6000.0, -origin.z) * 0.25;
    return max(smoothstep(0.5, 0.66, region + north), atmosAuroraForce) * ATMOS_AURORA;
}

vec3 atmos_airglow(vec3 direction, float night, float time) {
    if (direction.y <= -0.02) {
        return vec3(0.0);
    }
    vec2 p = direction.xz / (direction.y + 0.35) * 2.5 + vec2(time * 0.004, -time * 0.0025);
    float patches = 0.45 + 0.85 * atmos_fbm(p, 2);
    float green = exp(-pow((direction.y - 0.13) / 0.07, 2.0));
    float red = exp(-pow((direction.y - 0.32) / 0.16, 2.0));
    return (vec3(0.3, 1.0, 0.45) * green * 0.011 + vec3(1.0, 0.28, 0.24) * red * 0.0045) * patches * night;
}

float atmos_aurora_activity(float time) {
    return 0.22 + 0.2 * atmos_noise(vec2(time * 0.0021, 7.3));
}

vec3 atmos_aurora(vec3 origin, vec3 direction, vec3 sun, LightState state, float time) {
    float night = smoothstep(0.05, 0.25, -sun.y) * (1.0 - state.rain);
    if (ATMOS_AURORA <= 0.0 || night <= 0.0) {
        return vec3(0.0);
    }
    vec3 airglow = atmos_airglow(direction, night, time);
    if (direction.y <= 0.03) {
        return airglow;
    }
    float strength = max(atmos_aurora_region(origin), atmos_aurora_activity(time)) * night;
    vec3 total = vec3(0.0);
    for (int i = 0; i < 6; i++) {
        float layer = float(i) / 5.0;
        float height = 2600.0 + layer * 1400.0;
        vec2 p = direction.xz / direction.y * height * 0.00035 + origin.xz * 0.00002;
        float drift = time * 0.012;
        float fold = atmos_fbm(vec2(p.x * 0.6 + drift, p.y * 0.25 - drift * 0.4), 2);
        float ribbon = exp(-pow((p.y + (fold - 0.5) * 3.2 - sin(p.x * 0.7 + drift * 3.0) * 0.6) * 2.4, 2.0));
        float rays = 0.55 + 0.45 * atmos_noise(vec2(p.x * 9.0 + drift * 20.0, layer * 3.0));
        vec3 tint = mix(vec3(0.15, 1.0, 0.45), vec3(0.65, 0.25, 1.0), smoothstep(0.35, 1.0, layer));
        total += tint * ribbon * rays * (1.0 - layer * 0.55);
    }
    float fade = smoothstep(0.03, 0.2, direction.y) * (1.0 - smoothstep(0.75, 1.0, direction.y) * 0.6);
    return total * 0.018 * strength * fade + airglow;
}

vec4 atmos_contrail(vec3 direction, vec3 sun, LightState state, float time) {
    if (ATMOS_CONTRAILS <= 0.0 || direction.y < 0.05) {
        return vec4(0.0);
    }
    float slot = floor(time / 90.0);
    vec3 seed = atmos_star_hash(vec3(slot, 41.0, 2.0));
    if (seed.x > 0.45 * ATMOS_CONTRAILS) {
        return vec4(0.0);
    }
    float age = time - slot * 90.0;
    vec3 normal = normalize(vec3(seed.y - 0.5, 0.35 + seed.z * 0.3, atmos_star_hash(vec3(slot, 3.0, 9.0)).x - 0.5));
    vec3 a = atmos_basis_right(normal);
    vec3 b = cross(normal, a);
    float along = atan(dot(direction, b), dot(direction, a));
    float start = seed.z * 6.2831853;
    float head = start + age * 0.018;
    float behind = mod(head - along + 3.14159265, 6.2831853) - 3.14159265;
    if (behind < 0.0 || behind > 1.1) {
        return vec4(0.0);
    }
    float trailAge = behind / 0.018;
    float width = radians(0.08 + trailAge * 0.012);
    float miss = abs(dot(direction, normal));
    float line = exp(-pow(miss / width, 2.0)) * exp(-trailAge / 45.0) * smoothstep(0.0, 1.0, trailAge) * 0.7;
    float plane = exp(-pow(length(vec2(miss, behind * 0.02)) / radians(0.05), 2.0)) * smoothstep(0.0, 3.0, age);
    vec3 tint = mix(vec3(1.0), atmos_sun_tint(state), 0.4);
    float alpha = clamp(line, 0.0, 1.0) * state.sunVisibility * (1.0 - state.rain);
    return vec4(tint * (alpha * 1.4 + plane * 3.0 * state.sunVisibility), alpha);
}

float atmos_segment(vec2 p, vec2 a, vec2 b, out float along) {
    vec2 ab = b - a;
    along = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-12), 0.0, 1.0);
    return length(p - a - ab * along);
}

vec4 atmos_birds(vec3 direction, float time) {
    if (ATMOS_BIRDS <= 0.0 || direction.y < -0.02) {
        return vec4(0.0);
    }
    float slot = floor(time / 40.0);
    vec3 seed = atmos_star_hash(vec3(slot, 17.0, 5.0));
    if (seed.x > 0.5 * ATMOS_BIRDS) {
        return vec4(0.0);
    }
    float age = time - slot * 40.0;
    float azimuth = seed.y * 6.2831853;
    float elevation = radians(10.0 + seed.z * 22.0);
    float heading = (atmos_star_hash(vec3(slot, 2.0, 8.0)).x - 0.5) * 1.0;
    vec3 start = vec3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation));
    if (dot(direction, start) < 0.85) {
        return vec4(0.0);
    }
    vec3 right = atmos_basis_right(start);
    vec3 up = cross(start, right);
    vec2 travel = vec2(cos(heading), sin(heading));
    vec2 side = vec2(-travel.y, travel.x);
    vec2 flock = travel * (age - 20.0) * 0.007;
    vec2 local = vec2(dot(direction - start, right), dot(direction - start, up)) - flock;
    float silhouette = 0.0;
    for (int i = 0; i < 7; i++) {
        float rank = float((i + 1) / 2);
        float wingSide = (i % 2 == 0) ? 1.0 : -1.0;
        vec3 jitter = atmos_star_hash(vec3(slot, float(i), 4.0)) - 0.5;
        vec2 slotOffset = i == 0 ? vec2(0.0) : (-travel * rank * 0.022 + side * wingSide * rank * 0.017);
        slotOffset += (jitter.xy * 0.012) + vec2(sin(time * 0.3 + float(i)), cos(time * 0.23 + float(i) * 2.0)) * 0.002;
        vec2 p = local - slotOffset;
        float span = 0.0065 * (0.8 + 0.4 * (jitter.z + 0.5));
        vec2 q = p / span;
        q.x = abs(q.x);
        float burst = smoothstep(-0.2, 0.4, sin(time * 0.45 + float(i) * 1.9 + jitter.z * 6.0));
        float beat = sin(time * (3.0 + jitter.z) * 3.14159 + float(i) * 1.3) * burst;
        vec2 shoulder = vec2(0.06, 0.0);
        vec2 elbow = vec2(0.45, 0.22 + beat * 0.25);
        vec2 tip = vec2(1.0, -0.02 + beat * 0.55);
        float t1;
        float t2;
        float d1 = atmos_segment(q, shoulder, elbow, t1);
        float d2 = atmos_segment(q, elbow, tip, t2);
        float thick1 = mix(0.085, 0.06, t1);
        float thick2 = mix(0.06, 0.018, t2);
        float wing = max(smoothstep(thick1, thick1 * 0.45, d1), smoothstep(thick2, thick2 * 0.45, d2));
        float body = smoothstep(0.1, 0.05, length(q * vec2(1.6, 1.0) - vec2(0.0, 0.02)));
        silhouette = max(silhouette, max(wing, body));
    }
    float fade = smoothstep(0.0, 4.0, age) * (1.0 - smoothstep(34.0, 40.0, age));
    return vec4(vec3(0.1, 0.12, 0.18), silhouette * fade * 0.8);
}

float atmos_cloud_shape(vec3 position, float time, int octaves) {
    vec2 p = (position.xz + ATMOS_CLOUD_WIND * time) * ATMOS_CLOUD_SCALE;
    vec2 warp = vec2(atmos_noise(p * 0.5 + 3.1), atmos_noise(p * 0.5 + 7.7)) - 0.5;
    float clusters = atmos_fbm(p * 0.45 + warp * 0.6, 3);
    float puffs = atmos_fbm(p * 1.8 + warp + vec2(position.y * 0.012, -position.y * 0.008), octaves);
    return clusters * 0.65 + puffs * 0.35;
}

const float ATMOS_OVERCAST_HEIGHT = ATMOS_CLOUD_BOTTOM + ATMOS_CLOUD_THICKNESS + 40.0;

float atmos_cloud_bias(vec2 xz, float time) {
    float front = atmos_fbm((xz + ATMOS_CLOUD_WIND * time) * ATMOS_CLOUD_SCALE * 0.07 + 11.0, 2) - 0.5;
    return -front * ATMOS_CLOUD_FRONTS + (1.0 - atmos_region_puffs(xz, time)) * 0.22;
}

vec4 atmos_overcast(vec3 origin, vec3 direction, float time, vec3 sun, LightState state, vec3 skyLinear) {
    float amount = smoothstep(0.02, 0.45, state.rain);
    if (amount <= 0.0) {
        return vec4(0.0);
    }
    float t = abs(ATMOS_OVERCAST_HEIGHT - origin.y) / max(abs(direction.y), 0.03);
    vec2 p = (origin.xz + direction.xz * t - ATMOS_CLOUD_WIND * time * 1.5) * 0.0024;
    float body = atmos_fbm(p, 5);
    float billow = 1.0 - abs(atmos_fbm(p * 2.6 + 7.3, 4) * 2.0 - 1.0);
    float rolls = atmos_fbm(vec2(p.x * 1.4 + p.y * 0.5, p.y * 3.2) + 2.1, 3);
    float thickness = clamp(body * 0.55 + billow * 0.3 + rolls * 0.25 - 0.1, 0.0, 1.0);
    thickness = mix(thickness, 0.85, atmosStorm * 0.5);
    float horizon = smoothstep(0.0, 0.12, direction.y);
    float lum = dot(skyLinear, vec3(0.2126, 0.7152, 0.0722));
    float overhead = smoothstep(0.02, 0.55, direction.y);
    float underside = mix(1.1, mix(0.66, 0.46, atmosStorm), smoothstep(0.2, 0.85, thickness)) * mix(1.08, 0.9, overhead);
    underside = mix(0.8, underside, horizon);
    vec3 color = lum * underside * mix(vec3(0.9, 0.93, 0.98), vec3(0.74, 0.8, 0.92), atmosStorm) * mix(0.95, 0.5, atmosStorm);
    float cover = max(overhead, smoothstep(0.25, 0.62, atmos_fbm(p * 0.35 + 3.3, 3)) * 0.85);
    float rim = cover * (1.0 - cover) * 4.0;
    float warm = (1.0 - smoothstep(0.02, 0.35, sun.y)) * smoothstep(-0.14, 0.0, sun.y) * (1.0 - atmosStorm);
    float toward = pow(max(dot(direction, sun), 0.0) * 0.5 + 0.5, 2.0);
    vec3 tint = atmos_sun_tint(state);
    color = mix(color, color * tint * 1.3, warm * 0.6) + tint * lum * warm * toward * (0.35 + rim * 0.8) * (1.2 - thickness);
    color *= 1.0 + rim * 0.2 * (1.0 - atmosStorm);
    float thin = smoothstep(0.05, 0.3, thickness);
    amount *= mix(mix(0.1, 1.0, cover), 1.0, atmosStorm) * mix(0.8, 1.0, thin);
    return vec4(color, amount);
}

float atmos_cloud_density(vec3 p, float time, float coverage, int octaves, float detail) {
    float fraction = (p.y - ATMOS_CLOUD_BOTTOM) / ATMOS_CLOUD_THICKNESS;
    if (fraction <= 0.0 || fraction >= 1.0) {
        return 0.0;
    }
    float threshold = coverage + fraction * fraction * 0.3;
    float density = smoothstep(threshold, threshold + ATMOS_CLOUD_SHARPNESS, atmos_cloud_shape(p, time, octaves));
    if (detail > 0.01 && density > 0.0 && density < 0.98) {
        vec2 q = (p.xz + ATMOS_CLOUD_WIND * time * 1.3) * ATMOS_CLOUD_SCALE * 7.0 + vec2(p.y * 0.05, p.y * -0.03);
        float wisp = abs(atmos_fbm(q + (atmos_fbm(q * 0.5, 2) - 0.5) * 2.0, 3) * 2.0 - 1.0);
        density = clamp(density - wisp * ATMOS_CLOUD_WISPS * detail * (1.0 - density * density), 0.0, 1.0);
        density = smoothstep(0.0, 1.0, density);
    }
    return density * smoothstep(0.0, 0.06, fraction);
}

vec2 atmos_cell_hash(vec2 p) {
    return vec2(atmos_hash(p), atmos_hash(p + 17.3));
}

float atmos_cells(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float nearest = 9.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(float(x), float(y));
            vec2 r = o + atmos_cell_hash(i + o) - f;
            nearest = min(nearest, dot(r, r));
        }
    }
    return sqrt(nearest);
}

vec4 atmos_altocumulus(vec3 origin, vec3 direction, float time, vec3 sun, LightState state, vec3 skyColor) {
    if (direction.y < 0.02 || origin.y > ATMOS_ALTO_HEIGHT) {
        return vec4(0.0);
    }
    float t = (ATMOS_ALTO_HEIGHT - origin.y) / direction.y;
    vec2 p = origin.xz + direction.xz * t + ATMOS_CLOUD_WIND * time * 1.3;
    float patches = smoothstep(ATMOS_ALTO_COVERAGE, ATMOS_ALTO_COVERAGE + 0.18, atmos_fbm(p * 0.0011 + 21.0, 3)) * atmos_region_alto(origin.xz + direction.xz * t, time);
    if (patches <= 0.0) {
        return vec4(0.0);
    }
    vec2 warp = (vec2(atmos_fbm(p * 0.006, 3), atmos_fbm(p * 0.006 + 4.0, 3)) - 0.5) * 2.2;
    vec2 cellP = p * 0.017 + warp;
    float cell = atmos_cells(cellP) * mix(0.8, 1.3, atmos_fbm(p * 0.02 + 9.0, 2));
    float fray = mix(0.5, atmos_fbm(p * 0.09, 3), 1.0 - smoothstep(1500.0, 4000.0, t));
    float puff = smoothstep(0.68, 0.25, cell + (fray - 0.5) * 0.4) * smoothstep(0.2, 0.55, atmos_fbm(p * 0.03 + 3.0, 2));
    float lit = smoothstep(0.7, 0.0, atmos_cells(cellP + normalize(sun.xz + vec2(1e-4)) * 0.18));
    float cover = puff * patches * ATMOS_ALTO_OPACITY * smoothstep(0.02, 0.14, direction.y) * exp(-t / 7000.0) * (1.0 - state.rain * 0.8);
    vec3 tint = atmos_sun_tint(state);
    float lowSun = 1.0 - smoothstep(0.05, 0.4, sun.y);
    vec3 sunLight = mix(vec3(1.0, 0.98, 0.95), tint, 0.25 + 0.75 * lowSun) * state.sunVisibility * (0.55 + 0.9 * lit) * (1.0 + 1.5 * pow(max(dot(direction, sun), 0.0), 5.0));
    vec3 shade = mix(ATMOS_CLOUD_SHADOW * max(state.sunVisibility, 0.02), skyColor * 1.1, 0.5) * 0.8;
    vec3 moon = vec3(0.3, 0.38, 0.6) * 0.08 * state.moonVisibility;
    vec3 alto = max(sunLight + shade + moon, skyColor * 0.9 * state.moonVisibility);
    alto = mix(alto, skyColor * 1.1, (1.0 - exp(-t / ATMOS_CLOUD_AERIAL)) * 0.7);
    return vec4(alto * cover, cover);
}

vec4 atmos_clouds(vec3 origin, vec3 direction, float limit, float time, vec3 sun, LightState state, int steps, vec3 skyColor) {
    if (steps <= 0) {
        return vec4(0.0);
    }
    float bottom = ATMOS_CLOUD_BOTTOM;
    float top = ATMOS_CLOUD_BOTTOM + ATMOS_CLOUD_THICKNESS;
    bool below = origin.y < bottom;
    bool above = origin.y > top;
    if ((below && direction.y < 0.01) || (above && direction.y > -0.01)) {
        return vec4(0.0);
    }
    float enter;
    float leave;
    if (below || above) {
        float t0 = (bottom - origin.y) / direction.y;
        float t1 = (top - origin.y) / direction.y;
        enter = min(t0, t1);
        leave = max(t0, t1);
    } else {
        enter = 0.0;
        leave = abs(direction.y) > 1e-3 ? max((bottom - origin.y) / direction.y, (top - origin.y) / direction.y) : 800.0;
        leave = min(leave, 800.0);
    }
    if (leave <= 0.0 || enter > min(limit, 6000.0)) {
        return vec4(0.0);
    }
    float jitter = atmosJitter;
    float coverage = mix(ATMOS_CLOUD_COVERAGE, ATMOS_CLOUD_COVERAGE - mix(0.26, 0.44, atmosStorm), state.rain) + atmos_cloud_bias(origin.xz + direction.xz * enter, time) * (1.0 - state.rain * mix(0.45, 0.85, atmosStorm));
    vec3 tint = atmos_sun_tint(state);
    bool moonLit = sun.y < -0.02;
    vec3 lightSource = moonLit ? -sun : sun;
    float facing = max(dot(direction, lightSource), 0.0);
    float lowSun = 1.0 - smoothstep(0.05, 0.4, sun.y);
    vec3 cloudTint = mix(vec3(1.0, 0.98, 0.95), tint, 0.2 + 0.8 * lowSun);
    cloudTint = mix(cloudTint, vec3(1.0, 0.72, 0.68), smoothstep(-0.15, 0.15, sun.x) * lowSun * 0.55);
    cloudTint = mix(cloudTint, vec3(0.92, 0.94, 0.97), state.rain);
    vec3 sunLight = moonLit ? vec3(0.32, 0.4, 0.62) * 0.03 * state.moonVisibility : cloudTint * state.sunVisibility * ATMOS_CLOUD_SUN;
    sunLight *= (1.0 - state.rain * 0.85) * (1.0 - atmosStorm * 0.6);
    float daylight = max(state.sunVisibility, 0.02);
    vec3 shade = mix(ATMOS_CLOUD_SHADOW * daylight, skyColor * mix(1.2, 0.75, state.moonVisibility), 0.5);
    shade = mix(shade, vec3(dot(shade, vec3(0.2126, 0.7152, 0.0722))) * 1.1, state.rain * 0.85) * mix(1.0, 0.6, atmosStorm);
    vec3 lightDirection = normalize(vec3(lightSource.x, max(lightSource.y, 0.08), lightSource.z));
    float detail = 1.0 - smoothstep(700.0, 2000.0, enter);
    int octaves = steps >= 8 ? 5 : 4;
    bool sliced = below || above;
    float sliceHeight = ATMOS_CLOUD_THICKNESS / float(steps);
    float marchLength = (min(leave, enter + 340.0) - enter) / float(steps);
    float transmittance = 1.0;
    vec3 light = vec3(0.0);
    for (int i = 0; i < 16; i++) {
        if (i >= steps) {
            break;
        }
        float t;
        float stepLength;
        if (sliced) {
            float height = below ? bottom + sliceHeight * (float(i) + jitter) : top - sliceHeight * (float(i) + jitter);
            t = (height - origin.y) / direction.y;
            stepLength = min(sliceHeight / abs(direction.y), 90.0);
        } else {
            t = enter + marchLength * (float(i) + jitter);
            stepLength = marchLength;
        }
        if (t > limit) {
            break;
        }
        vec3 p = origin + direction * t;
        float density = atmos_cloud_density(p, time, coverage, octaves, detail);
        if (density > 0.01) {
            float toward = atmos_cloud_density(p + lightDirection * 12.0, time, coverage, 3, 0.0) + atmos_cloud_density(p + lightDirection * 32.0, time, coverage, 3, 0.0) * 0.7;
            float overhead = atmos_cloud_density(p + vec3(0.0, 18.0, 0.0), time, coverage, 2, 0.0);
            float shadow = exp(-toward * 2.0) + 0.5 * exp(-toward * 0.45);
            float fraction = clamp((p.y - bottom) / ATMOS_CLOUD_THICKNESS, 0.0, 1.0);
            float powder = 1.0 - exp(-density * 4.0);
            float silver = moonLit ? 0.8 + 0.9 * pow(facing, 24.0) * (1.0 - density * 0.6) : 0.8 + ATMOS_CLOUD_SILVER * pow(facing, 5.0) * (1.0 - density * 0.6);
            vec3 lit = sunLight * shadow * silver * mix(0.6, 1.0, powder) + shade * mix(0.35, 0.95, fraction) * mix(1.0, 0.7, overhead);
            float absorbed = 1.0 - exp(-density * stepLength * 0.12);
            light += transmittance * absorbed * lit;
            transmittance *= 1.0 - absorbed;
            if (transmittance < 0.03) {
                break;
            }
        }
    }
    float alpha = 1.0 - transmittance;
    float aerial = 1.0 - exp(-enter / ATMOS_CLOUD_AERIAL);
    light = mix(light, skyColor * 1.05 * alpha, aerial * 0.85);
    float fade = exp(-enter / 5200.0) * (sliced ? smoothstep(0.01, 0.07, abs(direction.y)) : 1.0);
    return vec4(light * fade, alpha * fade);
}

struct Tower {
    vec2 center;
    float radius;
    float height;
    float seed;
};

bool atmos_tower(vec2 cell, float time, out Tower tower) {
    vec3 h = atmos_star_hash(vec3(cell, 5.3));
    tower.radius = mix(ATMOS_TOWER_RADIUS.x, ATMOS_TOWER_RADIUS.y, h.y);
    tower.height = mix(ATMOS_TOWER_HEIGHT.x, ATMOS_TOWER_HEIGHT.y, h.z);
    vec2 spread = vec2(atmos_star_hash(vec3(cell, 8.1)).xy) - 0.5;
    tower.center = (cell + 0.5) * ATMOS_TOWER_CELL + spread * max(ATMOS_TOWER_CELL - 4.2 * tower.radius, 0.0);
    tower.seed = h.x * 97.0;
    return h.x < ATMOS_TOWER_CHANCE * atmos_region_towers(tower.center + ATMOS_CLOUD_WIND * time * 0.6, time);
}

float atmos_worley3(vec3 p) {
    vec3 base = floor(p);
    vec3 f = p - base;
    float nearest = 9.0;
    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec3 o = vec3(float(x), float(y), float(z));
                vec3 r = o + atmos_star_hash(base + o) - f;
                nearest = min(nearest, dot(r, r));
            }
        }
    }
    return sqrt(nearest);
}

float atmos_tower_density(Tower tower, vec3 p, float detail, bool surface) {
    vec3 shape = atmos_star_hash(vec3(tower.seed, 3.3, 7.1));
    float wobble = atmos_fbm(p.xz * 0.004 + tower.seed, 2) - 0.5;
    float bottom = ATMOS_TOWER_BASE + (shape.x - 0.5) * ATMOS_TOWER_BASE_SPREAD + wobble * 50.0;
    float h = (p.y - bottom) / tower.height;
    if (h <= 0.0 || h >= 1.0) {
        return 0.0;
    }
    float R = tower.radius;
    vec2 lean = vec2(sin(h * 2.3 + tower.seed), cos(h * 1.7 + tower.seed)) * 0.18 * R;
    vec2 offset = p.xz - tower.center - lean;
    float waist = mix(0.2, 0.45, shape.y);
    float taper = mix(0.4, 0.7, shape.z);
    float profile = R * (0.8 + 0.2 * smoothstep(0.0, waist, h)) * (1.0 - taper * smoothstep(waist, 1.0, h)) * sqrt(max(1.0 - h * h * h, 0.0));
    vec2 around = offset / max(length(offset), 1.0);
    float outline = atmos_fbm(around * 1.3 + vec2(h * 2.5, -h * 1.7) + tower.seed * 0.37, 3);
    profile *= 1.0 + (outline - 0.5) * 2.0 * ATMOS_TOWER_OUTLINE;
    float envelope = 1.0 - length(offset) / max(profile, 1.0);
    float baseFade = smoothstep(0.0, 0.03, h);
    if (!surface) {
        return smoothstep(0.0, 0.12, envelope) * baseFade;
    }
    float bite = ATMOS_TOWER_PUFFS * mix(0.4, 1.0, clamp(h / 0.1, 0.0, 1.0));
    if (envelope < -0.45 * bite) {
        return 0.0;
    }
    if (envelope > 0.55 * bite) {
        return baseFade;
    }
    vec3 q = p + tower.seed * 37.0;
    float puffs = 0.55 * (1.0 - atmos_worley3(q / 140.0)) + 0.3 * (1.0 - atmos_worley3((q + 16.0 * tower.seed) / 60.0));
    puffs += detail > 0.01 ? 0.15 * detail * (1.0 - atmos_worley3((q + 34.0 * tower.seed) / 25.0)) + 0.075 * (1.0 - detail) : 0.075;
    float shaped = envelope + (puffs - 0.55) * bite;
    return smoothstep(-0.04, 0.14, shaped) * baseFade;
}

vec4 atmos_towers(vec3 origin, vec3 direction, float limit, float time, vec3 sun, LightState state, vec3 skyColor) {
    float horizontal = length(direction.xz);
    if (horizontal < 1e-4) {
        return vec4(0.0);
    }
    vec2 shift = ATMOS_CLOUD_WIND * time * 0.6;
    vec2 start = origin.xz - shift;
    vec2 heading = direction.xz / horizontal;
    float reach = min(limit, ATMOS_TOWER_REACH);
    bool moonLit = sun.y < -0.02;
    vec3 lightSource = moonLit ? -sun : sun;
    vec3 lightDirection = normalize(vec3(lightSource.x, max(lightSource.y, 0.08), lightSource.z));
    float facing = max(dot(direction, lightSource), 0.0);
    float lowSun = 1.0 - smoothstep(0.05, 0.4, sun.y);
    vec3 tint = atmos_sun_tint(state);
    vec3 cloudTint = mix(vec3(1.0, 0.98, 0.95), tint, 0.2 + 0.8 * lowSun);
    cloudTint = mix(cloudTint, vec3(1.0, 0.72, 0.68), smoothstep(-0.15, 0.15, sun.x) * lowSun * 0.55);
    cloudTint = mix(cloudTint, vec3(0.92, 0.94, 0.97), state.rain);
    vec3 sunLight = moonLit ? vec3(0.32, 0.4, 0.62) * 0.03 * state.moonVisibility : cloudTint * state.sunVisibility * ATMOS_CLOUD_SUN;
    sunLight *= (1.0 - state.rain * 0.85) * (1.0 - atmosStorm * 0.6);
    vec3 shade = mix(ATMOS_CLOUD_SHADOW * max(state.sunVisibility, 0.02), skyColor * mix(1.2, 0.75, state.moonVisibility), 0.5);
    shade = mix(shade, vec3(dot(shade, vec3(0.2126, 0.7152, 0.0722))) * 1.1, state.rain * 0.85) * mix(1.0, 0.6, atmosStorm);

    vec2 cell = floor(start / ATMOS_TOWER_CELL);
    vec2 stepDir = sign(heading);
    vec2 safe = stepDir * max(abs(heading), vec2(1e-5));
    vec2 tDelta = abs(ATMOS_TOWER_CELL / safe);
    vec2 tMax = ((cell + max(stepDir, 0.0)) * ATMOS_TOWER_CELL - start) / safe;
    float travelled = 0.0;
    float transmittance = 1.0;
    vec3 light = vec3(0.0);
    float firstHit = -1.0;
    for (int visit = 0; visit < 10; visit++) {
        if (travelled / horizontal > reach || transmittance < 0.03) {
            break;
        }
        Tower tower;
        if (atmos_tower(cell, time, tower)) {
            vec2 rel = start - tower.center;
            float b = dot(rel, heading);
            float c = dot(rel, rel) - pow(tower.radius * 2.1, 2.0);
            float disc = b * b - c;
            if (disc > 0.0) {
                float root = sqrt(disc);
                float h0 = (-b - root) / horizontal;
                float h1 = (-b + root) / horizontal;
                float lowest = ATMOS_TOWER_BASE - ATMOS_TOWER_BASE_SPREAD * 0.5 - 30.0;
                float highest = ATMOS_TOWER_BASE + ATMOS_TOWER_BASE_SPREAD * 0.5 + 30.0 + tower.height;
                float y0 = abs(direction.y) > 1e-5 ? (lowest - origin.y) / direction.y : -1e9;
                float y1 = abs(direction.y) > 1e-5 ? (highest - origin.y) / direction.y : 1e9;
                float ta = max(max(h0, min(y0, y1)), 0.0);
                float tb = min(min(h1, max(y0, y1)), reach);
                if (abs(direction.y) <= 1e-5 && (origin.y < lowest || origin.y > highest)) {
                    tb = -1.0;
                }
                if (tb > ta) {
                    float detail = 1.0 - smoothstep(1500.0, 4000.0, ta);
                    vec3 anchoredOrigin = vec3(origin.x - shift.x, origin.y, origin.z - shift.y);
                    vec3 absDirection = abs(direction);
                    int axis = absDirection.x >= absDirection.y && absDirection.x >= absDirection.z ? 0 : (absDirection.y >= absDirection.z ? 1 : 2);
                    float axisDirection = direction[axis];
                    float axisOrigin = anchoredOrigin[axis];
                    float span = (tb - ta) * abs(axisDirection);
                    float spacing = ATMOS_TOWER_SPACING * exp2(max(ceil(log2(span / (ATMOS_TOWER_SPACING * float(ATMOS_TOWER_STEPS)))), 0.0));
                    float axisSign = axisDirection >= 0.0 ? 1.0 : -1.0;
                    float entry = (axisOrigin + axisDirection * ta) / spacing - atmosJitter;
                    float firstPlane = (axisSign > 0.0 ? ceil(entry) : floor(entry)) + atmosJitter;
                    float stepLength = spacing / max(abs(axisDirection), 1e-4);
                    float previous = -1.0;
                    for (int i = 0; i < ATMOS_TOWER_STEPS + 1; i++) {
                        float plane = (firstPlane + axisSign * float(i)) * spacing;
                        float t = (plane - axisOrigin) / axisDirection;
                        if (t > tb) {
                            break;
                        }
                        vec3 p = origin + direction * t;
                        vec3 local = vec3(p.x - shift.x, p.y, p.z - shift.y);
                        float sampled = atmos_tower_density(tower, local, detail, true);
                        float density = previous < 0.0 ? sampled : 0.5 * (sampled + previous);
                        previous = sampled;
                        if (density > 0.01) {
                            if (firstHit < 0.0) {
                                firstHit = t;
                            }
                            float toward = atmos_tower_density(tower, local + lightDirection * 30.0, 0.0, false) + atmos_tower_density(tower, local + lightDirection * 90.0, 0.0, false) * 0.8;
                            float shadow = exp(-toward * 1.8) + 0.45 * exp(-toward * 0.4);
                            float fraction = clamp((p.y - ATMOS_TOWER_BASE) / tower.height, 0.0, 1.0);
                            float silver = moonLit ? 0.8 + 0.9 * pow(facing, 24.0) * (1.0 - density * 0.6) : 0.8 + ATMOS_CLOUD_SILVER * pow(facing, 5.0) * (1.0 - density * 0.6);
                            vec3 lit = sunLight * shadow * silver + shade * mix(0.3, 1.0, fraction);
                            float absorbed = 1.0 - exp(-density * stepLength * 0.08);
                            light += transmittance * absorbed * lit;
                            transmittance *= 1.0 - absorbed;
                            if (transmittance < 0.03) {
                                break;
                            }
                        }
                    }
                }
            }
        }
        if (tMax.x < tMax.y) {
            travelled = tMax.x;
            tMax.x += tDelta.x;
            cell.x += stepDir.x;
        } else {
            travelled = tMax.y;
            tMax.y += tDelta.y;
            cell.y += stepDir.y;
        }
    }
    float alpha = 1.0 - transmittance;
    if (alpha <= 0.0) {
        return vec4(0.0);
    }
    float distance = max(firstHit, 0.0);
    light = mix(light, skyColor * 1.05 * alpha, (1.0 - exp(-distance / 9000.0)) * 0.6);
    float fade = 1.0 - smoothstep(ATMOS_TOWER_REACH * 0.75, ATMOS_TOWER_REACH, distance);
    return vec4(light * fade, alpha * fade);
}

vec3 atmos_spectrum(float t) {
    return 0.5 + 0.5 * cos(6.2831853 * (t + vec3(0.0, 0.33, 0.67)));
}

vec3 atmos_cloud_optics(vec3 direction, vec3 sun, LightState state, float alpha) {
    if (alpha <= 0.02 || state.sunVisibility <= 0.0) {
        return vec3(0.0);
    }
    float strength = state.sunVisibility * (1.0 - state.rain);
    float theta = degrees(acos(clamp(dot(direction, sun), -1.0, 1.0)));
    float thin = alpha * (1.0 - alpha) * 4.0;
    vec3 result = vec3(0.0);
    if (theta < 22.0) {
        float bands = theta * 0.18 + thin * 0.5;
        result += mix(vec3(1.0), atmos_spectrum(bands), 0.75) * exp(-theta / 7.0) * thin * ATMOS_IRIDESCENCE;
    }
    float anti = degrees(acos(clamp(dot(direction, -sun), -1.0, 1.0)));
    if (anti < 9.0) {
        vec3 glory = atmos_spectrum(anti * 0.32) * smoothstep(9.0, 3.0, anti) * 0.35 + vec3(1.0, 0.95, 0.9) * exp(-anti * anti * 0.6) * 0.5;
        result += glory * smoothstep(0.3, 0.8, alpha) * ATMOS_GLORY;
    }
    return result * strength;
}

float atmos_haze_amount(float distance, float cameraHeight, float pointHeight, LightState state, float daytime) {
    float morning = 1.0 - smoothstep(0.0, 1200.0, min(abs(daytime - 23300.0), abs(daytime + 700.0)));
    float density = ATMOS_HAZE_DENSITY * (1.0 + morning * ATMOS_MORNING_MIST + state.rain * 1.5);
    float height = 0.5 * (cameraHeight + pointHeight);
    float falloff = exp(-max(height - 63.0, 0.0) / ATMOS_HAZE_HEIGHT);
    float optical = pow(distance * density * falloff, 1.3);
    return (1.0 - exp(-optical)) * ATMOS_HAZE_STRENGTH;
}

#endif
