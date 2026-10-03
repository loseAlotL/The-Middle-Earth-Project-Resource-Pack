#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:atmosphere.glsl>
#include <tmep:precision.glsl>
#include <tmep:shader_params.glsl>

uniform sampler2D InSampler;
uniform sampler2D BloomSampler;
uniform sampler2D CameraSampler;
uniform sampler2D HeightSampler;
uniform sampler2D LightSampler;
uniform sampler2D ExposureSampler;
uniform sampler2D HeatSampler;
uniform sampler2D ParamsSampler;
uniform sampler2D DropletsSampler;
uniform sampler2D NoticeSampler;
uniform sampler2D NoticeSmallSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform GradeConfig {
    vec4 Bloom;
    vec4 Shadows;
    vec4 Highlights;
    vec4 Tone;
    vec4 Flare;
    vec4 Spill;
    vec4 Dark;
    vec4 Golden;
    vec4 Rain;
    vec4 Heat;
    vec4 Drops;
};

layout(location = 0) out vec4 fragColor;

float sceneLuma(vec2 uv) {
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
        return 1.0;
    }
    return dot(texture(InSampler, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec3 lensFlare(Camera camera, float aspect) {
    vec3 sun = camera_sun_direction(camera);
    float up = smoothstep(-0.03, 0.06, sun.y);
    if (up <= 0.0) {
        return vec3(0.0);
    }
    vec4 clip = camera.projection * camera.view * vec4(sun * 4096.0, 1.0);
    if (clip.w <= 0.0) {
        return vec3(0.0);
    }
    vec2 sunUv = clip.xy / clip.w * 0.5 + 0.5;
    vec2 edge = min(sunUv, 1.0 - sunUv);
    float onScreen = smoothstep(-0.25, 0.0, min(edge.x, edge.y));
    if (onScreen <= 0.0) {
        return vec3(0.0);
    }
    float visible = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398;
        vec2 probe = sunUv + vec2(cos(a) / aspect, sin(a)) * 0.006;
        float clear = (any(lessThan(probe, vec2(0.0))) || any(greaterThan(probe, vec2(1.0)))) ? 1.0 : texture(CameraSampler, probe).a;
        visible += clear * clear;
    }
    visible = visible / 8.0 * onScreen * up;
    if (visible <= 0.001) {
        return vec3(0.0);
    }
    LightState state = atmos_state(camera);
    vec3 tint = mix(vec3(1.0), atmos_sun_tint(state), 0.55);
    float drama = mix(0.12, 1.0, 1.0 - smoothstep(0.08, 0.45, sun.y));
    vec2 d = (texCoord - sunUv) * vec2(aspect, 1.0);
    float r = length(d);
    float angle = atan(d.y, d.x);
    float time = GameTime * 1200.0;
    float shimmer = 0.85 + 0.15 * sin(time * 2.0 + angle * 7.0);
    float crossArm = pow(abs(cos(angle * 2.0)), 6000.0) * Flare.y / (r * 6.0 + 0.25) * exp(-r * 1.1);
    float diagonal = pow(abs(cos(angle * 2.0 + 0.785398)), 1200.0) * Flare.y * 0.55 / (r * 14.0 + 0.3) * exp(-r * 3.0);
    vec2 around = vec2(cos(angle), sin(angle));
    float fine = pow(atmos_noise(around * 9.0 + vec2(time * 0.15, 0.0)), 7.0) * 1.4 + pow(atmos_noise(around * 23.0 - vec2(0.0, time * 0.1)), 9.0) * 1.2;
    float rays = fine * exp(-r * mix(14.0, 7.0, drama)) * shimmer * mix(0.4, 1.0, drama);
    float core = exp(-r * 35.0) * 1.6 + exp(-r * 7.0) * 0.35;
    float streak = exp(-abs(d.y) * 260.0) * exp(-abs(d.x) * 1.6) * 0.3;
    float ring = exp(-pow((r - 0.16) * 60.0, 2.0)) * 0.05;
    vec3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (r * 4.0 + vec3(0.0, 0.33, 0.67)));
    vec3 spikeColor = mix(tint, vec3(1.0, 0.42, 0.85), smoothstep(0.03, 0.4, r) * 0.75);
    crossArm *= drama;
    diagonal *= drama;
    vec3 flare = spikeColor * (crossArm + diagonal) * shimmer + tint * (core + rays) + vec3(0.75, 0.85, 1.0) * streak * drama + rainbow * ring;

    vec3 ghosts = vec3(0.0);
    vec2 axis = vec2(0.5) - sunUv;
    const vec4 GHOSTS[5] = vec4[](vec4(0.55, 0.035, 1.0, 0.0), vec4(0.9, 0.06, 0.0, 1.0), vec4(1.25, 0.02, 0.5, 0.5), vec4(1.6, 0.09, 0.25, 0.9), vec4(2.05, 0.045, 0.9, 0.3));
    for (int i = 0; i < 5; i++) {
        vec2 center = sunUv + axis * GHOSTS[i].x;
        float dist = length((texCoord - center) * vec2(aspect, 1.0));
        float size = GHOSTS[i].y;
        float disc = smoothstep(size, size * 0.7, dist) * (0.6 + 0.4 * smoothstep(size * 0.5, size, dist));
        vec3 color = mix(vec3(1.0, 0.45, 0.75), vec3(0.4, 0.9, 1.0), GHOSTS[i].z) * mix(1.0, 0.7, GHOSTS[i].w);
        ghosts += color * disc * 0.06;
    }
    return (flare * Flare.x + ghosts * Flare.z * drama) * visible * (1.0 - state.rain);
}

vec3 gradeStyle(vec3 color, int style) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    if (style == GRADE_MORDOR) {
        vec3 ash = mix(vec3(luma), color, 0.5) * vec3(1.14, 0.84, 0.66);
        return ash * ash * (3.0 - 2.0 * ash) * 0.92;
    }
    if (style == GRADE_BARROW) {
        return mix(vec3(luma), color, 0.3) * vec3(0.78, 0.96, 0.9) * 0.82;
    }
    if (style == GRADE_LORIEN) {
        vec3 gold = mix(vec3(luma), color, 1.1) * vec3(1.08, 1.03, 0.84);
        return gold + vec3(1.0, 0.9, 0.55) * smoothstep(0.35, 0.9, luma) * 0.06;
    }
    if (style == GRADE_SHIRE) {
        return mix(vec3(luma), color, 1.15) * vec3(1.05, 1.03, 0.94);
    }
    if (style == GRADE_MORIA) {
        return mix(vec3(luma), color, 0.55) * vec3(0.84, 0.9, 1.02) * 0.78;
    }
    if (style == GRADE_ANGMAR) {
        return mix(vec3(luma), color, 0.4) * vec3(0.86, 0.94, 1.12) * 0.9;
    }
    return color;
}

vec3 ashFall(vec3 color, float amount, float aspect) {
    float seconds = GameTime * 1200.0;
    for (int layer = 0; layer < 3; layer++) {
        float depth = float(layer);
        float scale = 26.0 + depth * 22.0;
        vec2 grid = texCoord * vec2(aspect, 1.0) * scale + vec2(seconds * (0.35 + depth * 0.15) + sin(seconds * 0.4 + depth) * 0.6, seconds * (0.9 + depth * 0.5));
        vec2 cell = floor(grid);
        float chance = atmos_hash(cell + depth * 17.0);
        if (chance > 0.86) {
            vec2 spot = vec2(atmos_hash(cell + 3.1), atmos_hash(cell + 7.7));
            float speck = smoothstep(0.1 - depth * 0.025, 0.0, length(fract(grid) - spot));
            bool ember = chance > 0.985;
            vec3 tone = ember ? vec3(1.0, 0.45, 0.12) * 1.4 : vec3(0.32, 0.3, 0.29);
            color = ember ? color + tone * speck * amount : mix(color, tone, speck * amount * 0.75);
        }
    }
    return color;
}

vec3 drawNotice(vec3 color, sampler2D notice, vec2 center, float width, float aspect, float strength) {
    vec2 size = vec2(width, width * aspect * float(textureSize(notice, 0).y) / float(textureSize(notice, 0).x));
    vec2 local = (texCoord - (center - size * 0.5)) / size;
    if (strength <= 0.0 || any(lessThan(local, vec2(0.0))) || any(greaterThan(local, vec2(1.0)))) {
        return color;
    }
    vec4 banner = texture(notice, vec2(local.x, 1.0 - local.y));
    return mix(color, banner.rgb, banner.a * strength);
}

float droplets(vec2 coord) {
    return texture(DropletsSampler, fract(coord)).r;
}

float exitWaterMask(vec2 uv, float aspect, float exitWater) {
    vec2 scale = vec2(0.5, 0.25 + exitWater * exitWater * 0.25) * vec2(aspect, 1.0);
    float noise = droplets((uv - vec2(0.0, exitWater)) * scale);
    return sqrt(min(max(noise - (1.0 - sqrt(exitWater)) * 0.95, 0.0) * (1.0 + exitWater), 1.0)) * 0.3 * smoothstep(0.03, 0.2, exitWater);
}

float rainMask(vec2 uv, float aspect, float seconds, float amount) {
    vec2 scale = vec2(0.4, 0.32) * vec2(aspect, 1.0);
    float threshold = mix(0.52, 0.44, amount);
    float mask = 0.0;
    for (int i = 0; i < 3; i++) {
        float phase = seconds / 3.0 + float(i) / 3.0;
        float slot = floor(phase);
        float life = fract(phase);
        float weight = smoothstep(0.0, 0.06, life) * (1.0 - smoothstep(0.45, 1.0, life));
        vec2 offset = vec2(atmos_hash(vec2(slot, float(i))), atmos_hash(vec2(float(i) + 3.1, slot + 7.3)));
        float noise = droplets(uv * scale + offset + vec2(0.0, max(life - 0.3, 0.0) * max(life - 0.3, 0.0) * 0.5));
        mask = max(mask, sqrt(max(noise - threshold, 0.0) * 4.0) * weight);
    }
    return mask * 0.08 * amount;
}

void main() {
    vec3 color = texelFetch(InSampler, ivec2(gl_FragCoord.xy), 0).rgb;
    vec2 warp = vec2(0.0);
    Camera camera = camera_load_lite(CameraSampler);
    float aspect = ScreenSize.x / max(ScreenSize.y, 1.0);
    float regionalHeat = params_get(ParamsSampler, SMOOTH_HEAT) * (0.3 + 0.7 * smoothstep(0.75, 0.2, texCoord.y));
    float emitterHeat = 0.0;
    float emitterStrength = params_get(ParamsSampler, SMOOTH_EMITTER_STRENGTH);
    if (emitterStrength > 0.002 && camera.valid) {
        vec3 offset = params_emitter_offset(camera_slot(CameraSampler, CAMERA_DATA_PARAM_SLOT + PARAM_EMITTER_X), camera_slot(CameraSampler, CAMERA_DATA_PARAM_SLOT + PARAM_EMITTER_Y), camera_slot(CameraSampler, CAMERA_DATA_PARAM_SLOT + PARAM_EMITTER_Z));
        vec4 clip = camera.projection * camera.view * vec4(offset, 1.0);
        if (clip.w > 0.1) {
            vec2 center = clip.xy / clip.w * 0.5 + 0.5;
            float radius = params_get(ParamsSampler, SMOOTH_EMITTER_RADIUS) * 255.0 * 0.25;
            float screenRadius = max(radius * camera.projection[1][1] * 0.5 / clip.w, 1e-4);
            vec2 d = vec2((texCoord.x - center.x) * aspect, texCoord.y - center.y - screenRadius * 0.5);
            emitterHeat = emitterStrength * (1.0 - smoothstep(0.2, 1.3, length(d) / screenRadius));
        }
    }
    float nearHeat = max(regionalHeat, emitterHeat);
    if (Heat.x > 0.0) {
        for (int i = 0; i < 4; i++) {
            nearHeat = max(nearHeat, texture(HeatSampler, texCoord - vec2(0.0, Heat.y * 1.6 * float(i) / 3.0)).r);
        }
    }
    if (nearHeat > 0.002 && Heat.x > 0.0) {
        float seconds = GameTime * 1200.0;
        vec2 p = texCoord * vec2(aspect, 1.0) * 7.0;
        float rise = seconds * Heat.z;
        vec2 swirl = vec2(atmos_fbm(p + vec2(0.0, -rise * 0.7), 3), atmos_fbm(p + vec2(5.2, 1.3 - rise * 0.7), 3)) - 0.5;
        float heat = 0.0;
        for (int i = 0; i < 4; i++) {
            float lift = float(i) / 3.0;
            vec2 source = texCoord - vec2(swirl.x * Heat.y * 0.8 * lift, Heat.y * 1.6 * lift);
            heat = max(heat, texture(HeatSampler, source).r * (1.0 - lift * 0.55));
        }
        heat = max(heat, max(regionalHeat, emitterHeat) * 0.25);
        if (heat > 0.004) {
            vec2 curl = vec2(atmos_fbm(p * 1.8 + swirl * 2.5 + vec2(1.7, -rise * 1.6), 3), atmos_fbm(p * 1.8 + swirl * 2.5 + vec2(8.3, -rise * 1.3), 3)) - 0.5;
            float wisps = smoothstep(0.3, 0.75, atmos_fbm(p * 0.9 + swirl * 1.5 + vec2(3.1, -rise * 1.1), 3));
            float amount = min(heat * 4.0, 1.0) * mix(0.35, 1.0, wisps);
            warp += curl * vec2(1.0, 1.4) * amount * Heat.x * vec2(1.0 / aspect, 1.0);
        }
    }
    vec2 sampleUv = texCoord + warp;
    float exitWater = camera.valid && !camera.underwater ? exp2(-6.64 * params_surfaced_seconds(ParamsSampler) / Drops.z) * Drops.y : 0.0;
    if (exitWater > 0.03) {
        float mask = exitWaterMask(texCoord, aspect, min(exitWater, 1.0));
        sampleUv = 0.5 + (sampleUv - 0.5) * (1.0 - mask);
    }
    float rainScreen = params_get(ParamsSampler, SMOOTH_RAIN_SCREEN) * Drops.x;
    if (rainScreen > 0.01) {
        float seconds = GameTime * 1200.0;
        float mask = rainMask(texCoord, aspect, seconds, min(rainScreen, 1.0));
        sampleUv = 0.5 + (sampleUv - 0.5) * (1.0 - mask);
    }
    if (sampleUv != texCoord) {
        color = texture(InSampler, clamp(sampleUv, vec2(0.0), vec2(1.0))).rgb;
    }
    vec3 bloom = texture(BloomSampler, texCoord).rgb * Bloom.x;
    color = 1.0 - (1.0 - color) * (1.0 - clamp(bloom, 0.0, 1.0));
    vec3 spill = texture(LightSampler, texCoord).rgb;
    spill = mix(spill, vec3(dot(spill, vec3(0.2126, 0.7152, 0.0722))) * vec3(1.0, 0.86, 0.66), Spill.w);
    color += color * spill * Spill.x + spill * Spill.y;
    if (Spill.z > 0.0) {
        float exposure = precise_decode(texelFetch(ExposureSampler, ivec2(0), 0)) * 2.0;
        color = 1.0 - pow(1.0 - clamp(color, 0.0, 1.0), vec3(exposure));
    }
    float darkLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color *= mix(1.0, smoothstep(0.0, Dark.x, darkLuma), Dark.y);
    float warmth = (color.r - color.b) / max(color.r + color.g + color.b, 1e-4);
    float scotopic = Dark.z * (1.0 - smoothstep(0.015, 0.16, darkLuma)) * (1.0 - smoothstep(-0.06, 0.08, warmth));
    color = mix(color, vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))) * vec3(0.62, 0.78, 1.0) * 1.1, scotopic);

    int style = params_grade_style(ParamsSampler);
    float styleAmount = params_get(ParamsSampler, SMOOTH_GRADE_AMOUNT);
    if (style > 0 && styleAmount > 0.001) {
        color = mix(color, gradeStyle(color, style), styleAmount);
    }
    float gloom = params_get(ParamsSampler, SMOOTH_GLOOM);
    if (gloom > 0.001) {
        color = pow(max(color, vec3(0.0)), vec3(1.0 + gloom * 0.7)) * (1.0 - gloom * 0.45);
    }
    float wraith = params_get(ParamsSampler, SMOOTH_WRAITH);
    if (wraith > 0.001) {
        vec2 centered = texCoord - 0.5;
        vec3 ghost = texture(InSampler, 0.5 + centered * (1.0 - 0.025 * wraith) + vec2(sin(GameTime * 1200.0 * 0.6), cos(GameTime * 1200.0 * 0.45)) * 0.003 * wraith).rgb;
        color = mix(color, max(color, ghost * 0.9), wraith * 0.4);
        float ghostLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        color = mix(color, vec3(ghostLuma) * vec3(0.84, 0.92, 1.06), wraith * 0.75);
        color *= 1.0 - wraith * 0.65 * smoothstep(0.3, 0.85, length(centered * vec2(aspect, 1.0)) / max(aspect * 0.5, 0.5));
    }
    float ash = params_get(ParamsSampler, SMOOTH_ASH);
    if (ash > 0.001) {
        color = ashFall(color, ash, aspect);
    }

    bool outside = camera.valid && camera.skyValid && !camera.underwater;
    if (Rain.x < 1.0 && outside) {
        float wet = smoothstep(0.02, 0.5, atmos_state(camera).rain);
        if (wet > 0.0) {
            float rainLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));
            color = mix(color, vec3(rainLuma) * vec3(0.94, 0.97, 1.03), Rain.y * wet);
            color *= mix(1.0, Rain.x, wet);
        }
    }
    if (Golden.x > 0.0 && outside) {
        float height = camera_sun_direction(camera).y;
        float window = smoothstep(-0.14, -0.01, height) * (1.0 - smoothstep(0.1, 0.38, height)) * (1.0 - atmos_state(camera).rain);
        if (window > 0.0) {
            vec3 warm = mix(vec3(1.3, 0.7, 0.48), vec3(1.18, 0.9, 0.62), smoothstep(0.02, 0.3, height));
            warm = mix(vec3(1.12, 0.72, 0.9), warm, smoothstep(-0.1, 0.01, height));
            float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
            vec3 tinted = color * warm;
            tinted *= luma / max(dot(tinted, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
            color = mix(color, tinted, Golden.x * window * smoothstep(0.02, 0.35, luma));
            color = mix(color, color * vec3(0.88, 0.93, 1.1), Golden.y * window * (1.0 - smoothstep(0.08, 0.35, luma)));
        }
    }
    if (Flare.x > 0.0 && outside) {
        vec3 flare = lensFlare(camera, ScreenSize.x / max(ScreenSize.y, 1.0));
        color = 1.0 - (1.0 - color) * (1.0 - clamp(flare, 0.0, 1.0));
    }

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec3 tint = mix(Shadows.rgb, Highlights.rgb, smoothstep(0.12, 0.8, luma));
    color = mix(color, color * tint, Tone.x);

    luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float saturation = max(max(color.r, color.g), color.b) - min(min(color.r, color.g), color.b);
    color = mix(vec3(luma), color, 1.0 + Tone.y * (1.0 - saturation));

    color = mix(color, color * color * (3.0 - 2.0 * color), Tone.z);
    if (Flare.w > 0.0) {
        vec2 corner = gl_FragCoord.xy - vec2(ScreenSize.x - 520.0, ScreenSize.y - 520.0);
        if (all(greaterThanEqual(corner, vec2(0.0))) && all(lessThan(corner, vec2(512.0)))) {
            vec4 cell = texelFetch(HeightSampler, ivec2(corner / 2.0), 0);
            float height = (floor(cell.r * 255.0 + 0.5) * 256.0 + floor(cell.g * 255.0 + 0.5)) / 128.0 - 64.0;
            color = cell.a > 0.25 ? vec3(clamp((height - 40.0) / 80.0, 0.0, 1.0)) * (cell.a > 0.75 ? vec3(0.6, 1.0, 0.6) : vec3(0.5, 0.7, 1.0)) : vec3(0.15, 0.0, 0.0);
        }
    }
    float transparencyOff = params_transparency_off_seconds(ParamsSampler);
    if (transparencyOff >= 1.5) {
        float intro = smoothstep(1.5, 2.0, transparencyOff) * (1.0 - smoothstep(9.0, 10.0, transparencyOff));
        color = drawNotice(color, NoticeSampler, vec2(0.5, 0.62), 0.42, aspect, intro);
        float corner = smoothstep(9.5, 10.5, transparencyOff);
        color = drawNotice(color, NoticeSmallSampler, vec2(1.0 - 0.012 - 0.11, 0.97), 0.22, aspect, corner);
    }
    if (Heat.w > 0.5) {
        color = mix(color, vec3(1.0, 0.0, 0.0), clamp(texture(HeatSampler, texCoord).r * 4.0, 0.0, 0.8));
    }
    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
