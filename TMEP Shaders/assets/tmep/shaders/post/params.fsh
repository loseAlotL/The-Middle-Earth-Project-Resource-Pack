#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:world.glsl>
#include <tmep:shader_params.glsl>
#include <tmep:lighting.glsl>

uniform sampler2D InSampler;
uniform sampler2D PreviousSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

float raw(int index) {
    return camera_slot(InSampler, CAMERA_DATA_PARAM_SLOT + index);
}

void main() {
    int index = int(gl_FragCoord.x);
    if (index >= SMOOTH_COUNT) {
        fragColor = vec4(0.0);
        return;
    }
    cameraScreenSize = textureSize(InSampler, 0);
    bool valid = abs(camera_slot(InSampler, CAMERA_DATA_MAGIC_SLOT) - CAMERA_DATA_MAGIC) < 0.25;
    vec4 previousTexel = texelFetch(PreviousSampler, ivec2(index, 0), 0);
    bool hasPrevious = previousTexel.a > 0.5;
    float previous = hasPrevious ? precise_decode(previousTexel) : 0.0;
    if (!valid) {
        fragColor = index == SMOOTH_SURFACED || index == SMOOTH_TRANSPARENCY ? previousTexel : precise_encode(previous);
        return;
    }
    if (index == SMOOTH_TRANSPARENCY) {
        vec3 flag = texelFetch(InSampler, camera_transparency_flag_pixel(cameraScreenSize), 0).rgb;
        if (all(lessThan(abs(flag - CAMERA_TRANSPARENCY_FLAG), vec3(1.5 / 255.0)))) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        } else if (previousTexel.b > 0.5) {
            fragColor = previousTexel;
        } else {
            fragColor = precise_encode(GameTime);
            fragColor.b = 1.0;
        }
        return;
    }
    if (index == SMOOTH_SURFACED) {
        bool underwater = abs(camera_slot(InSampler, CAMERA_DATA_FOG_START_SLOT) + 8.0) < 0.5 && camera_slot(InSampler, CAMERA_DATA_FOG_END_SLOT) <= 96.5;
        if (underwater) {
            fragColor = precise_encode(GameTime);
            fragColor.b = 1.0;
        } else {
            fragColor = previousTexel;
        }
        return;
    }

    uint colorBits = uint(round(raw(PARAM_FOG_COLOR) * 65535.0));
    uint flags = uint(round(raw(PARAM_FLAGS) * 65535.0));
    int style = int(round(raw(PARAM_GRADE_STYLE) * 65535.0));
    float power = raw(PARAM_EMITTER_POWER) * 65535.0;
    float rate = 0.02;
    float target = 0.0;

    if (index == SMOOTH_HEAT) {
        target = raw(PARAM_HEAT);
    } else if (index == SMOOTH_FOG_R) {
        target = float((colorBits >> 11u) & 31u) / 31.0;
    } else if (index == SMOOTH_FOG_G) {
        target = float((colorBits >> 5u) & 63u) / 63.0;
    } else if (index == SMOOTH_FOG_B) {
        target = float(colorBits & 31u) / 31.0;
    } else if (index == SMOOTH_FOG_DENSITY) {
        target = raw(PARAM_FOG_DENSITY);
    } else if (index == SMOOTH_GRADE_STYLE) {
        float current = precise_decode(texelFetch(PreviousSampler, ivec2(SMOOTH_GRADE_AMOUNT, 0), 0));
        float wanted = float(clamp(style, 0, 15)) / 15.0;
        fragColor = precise_encode(current < 0.02 || !hasPrevious ? wanted : previous);
        return;
    } else if (index == SMOOTH_GRADE_AMOUNT) {
        float currentStyle = precise_decode(texelFetch(PreviousSampler, ivec2(SMOOTH_GRADE_STYLE, 0), 0));
        bool sameStyle = abs(currentStyle - float(clamp(style, 0, 15)) / 15.0) < 0.01;
        target = sameStyle ? raw(PARAM_GRADE_AMOUNT) : 0.0;
        rate = sameStyle ? 0.015 : 0.04;
    } else if (index == SMOOTH_WRAITH) {
        target = raw(PARAM_WRAITH);
    } else if (index == SMOOTH_GLOOM) {
        target = raw(PARAM_GLOOM);
    } else if (index == SMOOTH_ASH) {
        target = (flags & 1u) != 0u ? 1.0 : 0.0;
    } else if (index == SMOOTH_AURORA) {
        target = (flags & 2u) != 0u ? 1.0 : 0.0;
        rate = 0.005;
    } else if (index == SMOOTH_EERIE) {
        target = (flags & 4u) != 0u ? 1.0 : 0.0;
        rate = 0.008;
    } else if (index == SMOOTH_EMITTER_STRENGTH) {
        target = mod(power, 256.0) / 255.0;
        rate = 0.08;
    } else if (index == SMOOTH_RAIN_SCREEN) {
        float daytime = camera_slot(InSampler, CAMERA_DATA_DAYTIME_SLOT);
        float weather = camera_slot(InSampler, CAMERA_DATA_WEATHER_SLOT);
        float rain = daytime >= 0.0 && weather >= 0.0 && weather <= 1.01 ? light_state(daytime / 24000.0, clamp(weather, 0.0, 1.0)).rain : 0.0;
        float sky = camera_slot(InSampler, CAMERA_DATA_SKY_SLOT);
        target = rain * smoothstep(0.86, 0.97, sky);
        rate = 0.03;
    } else if (index == SMOOTH_EMITTER_RADIUS) {
        target = floor(power / 256.0) / 255.0;
        rate = 1.0;
    }
    float value = hasPrevious ? previous + (target - previous) * rate : target;
    if (abs(target - value) < 0.0005) {
        value = target;
    }
    fragColor = precise_encode(value);
}
