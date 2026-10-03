#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:lighting.glsl>
#include <minecraft:globals.glsl>

layout(std140) uniform LightmapInfo {
    float SkyFactor;
    float BlockFactor;
    float NightVisionFactor;
    float DarknessScale;
    float BossOverlayWorldDarkeningFactor;
    float BrightnessFactor;
    vec3 BlockLightTint;
    vec3 SkyLightColor;
    vec3 AmbientColor;
    vec3 NightVisionColor;
} lightmapInfo;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

float get_brightness(float level) {
    return level / (4.0 - 3.0 * level);
}

vec3 notGamma(vec3 color) {
    float maxComponent = max(max(color.x, color.y), color.z);
    float maxInverted = 1.0f - maxComponent;
    float maxScaled = 1.0f - maxInverted * maxInverted * maxInverted * maxInverted;
    return color * (maxScaled / max(maxComponent, 1e-5));
}

float parabolicMixFactor(float level) {
    return (2.0 * level - 1.0) * (2.0 * level - 1.0);
}

vec3 vanillaLight(float block_level, float sky_level) {
    float block_brightness = get_brightness(block_level) * lightmapInfo.BlockFactor;
    float sky_brightness = get_brightness(sky_level) * lightmapInfo.SkyFactor;
    vec3 color = lightmapInfo.AmbientColor;
    color += lightmapInfo.SkyLightColor * sky_brightness;
    vec3 BlockLightColor = mix(lightmapInfo.BlockLightTint, vec3(1.0), 0.9 * parabolicMixFactor(block_level));
    color += BlockLightColor * block_brightness;
    return color;
}

void main() {
    float block_level = floor(texCoord.x * 16) / 15;
    float sky_level = floor(texCoord.y * 16) / 15;
    ivec2 texel = ivec2(texCoord * 16.0);

    bool clocked = sun_clock_encoded(lightmapInfo.AmbientColor);
    float phase = clamp(lightmapInfo.AmbientColor.r / SUN_CLOCK_RANGE, 0.0, 1.0);
    float weather = 1.0;
    vec3 color;
    if (clocked) {
        weather = clamp(lightmapInfo.SkyFactor / light_clear_sky(phase), 0.0, 1.0);
        LightState state = light_state(phase, weather);
        vec3 averageNormal = normalize(vec3(0.3, 0.8, 0.5));
        vec3 full = light_world(state, averageNormal, sky_level, block_level * mix(0.94, 1.0, lightmapInfo.BlockFactor), false);
        vec3 skyOnly = light_world(state, averageNormal, sky_level, 0.0, false);
        vec3 light = skyOnly * mix(1.0, LIGHT_NIGHT_LEVEL, state.moonVisibility) + max(full - skyOnly, vec3(0.0));
        color = light_tonemap(light * 0.214) / 0.5;
    } else {
        color = vanillaLight(block_level, sky_level);
    }

    vec3 nightVisionColor = lightmapInfo.NightVisionColor * lightmapInfo.NightVisionFactor;
    color = max(color, nightVisionColor);
    color = mix(color, color * vec3(0.7, 0.6, 0.6), lightmapInfo.BossOverlayWorldDarkeningFactor);
    color = color - vec3(lightmapInfo.DarknessScale);
    color = clamp(color, 0.0, 1.0);
    color = mix(color, notGamma(color), clamp(lightmapInfo.BrightnessFactor, 0.0, 1.0) * (clocked ? 0.35 : 1.0));

    uint code = sun_clock_code(lightmapInfo.AmbientColor);
    if (texel == ivec2(15, 15)) {
        color = sun_clock_embed(color, code);
    } else if (texel == ivec2(14, 15)) {
        color = sun_clock_embed(color, code >> 6u);
    } else if (texel == ivec2(13, 15)) {
        color = sun_clock_embed(color, uint(weather * 62.0 + 0.5));
    } else if (texel.y == 15 && texel.x >= 10 && texel.x <= 12) {
        uint eighths = uint(GameTime * 24000.0 * 8.0) % 192000u;
        color = sun_clock_embed(color, eighths >> (6u * uint(12 - texel.x)));
    }

    fragColor = vec4(color, 1.0);
}
