#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:lighting.glsl>
#include <tmep:world.glsl>
#include <tmep:precision.glsl>

uniform sampler2D InSampler;
uniform sampler2D PreviousSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 previous = texelFetch(PreviousSampler, ivec2(0), 0);
    vec4 hold = textureSize(PreviousSampler, 0).x > 1 ? texelFetch(PreviousSampler, ivec2(1, 0), 0) : vec4(0.0);
    float wetness = previous.a > 0.5 ? precise_decode(previous) : 0.0;
    Camera camera = camera_load_lite(InSampler);
    float rain = 0.0;
    float storm = 0.0;
    if (camera.valid && camera.skyValid) {
        float weather = clamp(camera.weather, 0.0, 1.0);
        rain = light_state(camera.daytime / 24000.0, weather).rain;
        storm = clamp((0.66 - weather) / 0.12, 0.0, 1.0);
    }
    bool held = hold.a > 0.5;
    float heldRain = held ? hold.r : rain;
    float heldStorm = held ? hold.g : storm;
    float flash = held ? hold.b : 0.0;
    if (heldRain > 0.5 && rain < heldRain - 0.45) {
        flash = flash < 0.5 ? 1.0 : max(flash * 0.86 - 0.01, 0.0);
        heldRain -= 0.002;
    } else {
        heldRain = rain > heldRain ? rain : max(rain, heldRain - 0.004);
        heldStorm += clamp(storm - heldStorm, -0.004, 0.004);
        flash = max(flash * 0.86 - 0.01, 0.0);
    }
    if (int(gl_FragCoord.x) == 1) {
        fragColor = vec4(heldRain, heldStorm, flash, 1.0);
        return;
    }
    float target = smoothstep(0.1, 0.6, heldRain);
    float rate = target > wetness ? 0.0008 : 0.0003;
    wetness += clamp(target - wetness, -rate, rate);
    fragColor = precise_encode(wetness);
}
