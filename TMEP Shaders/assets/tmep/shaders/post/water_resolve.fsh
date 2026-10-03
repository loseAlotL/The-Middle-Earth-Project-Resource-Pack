#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D ReflectionSampler;
uniform sampler2D RipplesSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform ResolveConfig {
    vec4 Glint;
    vec4 Blur;
};

layout(location = 0) out vec4 fragColor;

vec3 glint(Camera camera, vec3 normal, vec3 toCamera, float distance) {
    if (!camera_has_daytime(camera)) {
        return vec3(0.0);
    }
    float alpha2 = Glint.y + distance * 0.00004 * Glint.w;
    vec3 sun = camera_sun_direction(camera);
    vec3 moon = -sun;
    vec3 sunColor = mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.95, 0.86), smoothstep(0.05, 0.4, sun.y)) * smoothstep(-0.03, 0.08, sun.y);
    vec3 moonColor = vec3(0.55, 0.62, 0.85) * 0.15 * smoothstep(-0.03, 0.08, moon.y);
    float sunSpecular = water_ggx(normal, toCamera, sun, WATER_F0, alpha2);
    float moonSpecular = water_ggx(normal, toCamera, moon, WATER_F0, alpha2);
    return (sunColor * sunSpecular + moonColor * moonSpecular) * Glint.x;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec3 scene = camera_scene_color(InSampler, pixel);
    if (!water_post_is_water_pixel(DepthSampler, pixel)) {
        fragColor = vec4(scene, 1.0);
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid || camera_is_data_pixel(pixel)) {
        fragColor = vec4(scene, 1.0);
        return;
    }

    ivec2 screen = textureSize(DepthSampler, 0);
    float depth = max(water_post_scene_depth(DepthSampler, pixel), 1e-7);
    vec3 origin = camera_relative(camera, texCoord, depth);
    float distance = max(length(origin), 1e-3);
    vec3 viewDirection = origin / distance;
    vec3 world = origin + camera_world_origin();
    vec3 sparkle = vec3(0.0);
    if (Glint.x > 0.0) {
        vec2 ripple = water_post_ripple_gradient(RipplesSampler, world.xz, GameTime * 1200.0);
        vec3 glintNormal = normalize(vec3(-ripple.x * Glint.z, 1.0, -ripple.y * Glint.z));
        sparkle = glint(camera, glintNormal, -viewDirection, distance);
    }

    float grazing = water_post_grazing(viewDirection);
    float radius = mix(Blur.x, Blur.y, grazing);
    vec4 accumulated = vec4(0.0);
    float weights = 0.0;
    int rows = int(Blur.w);
    int columns = rows > 0 ? 1 : 0;
    float spread = max(float(rows), 1.0);
    for (int i = -rows; i <= rows; i++) {
        for (int j = -columns; j <= columns; j++) {
            vec2 offset = vec2(float(j) * radius * Blur.z, float(i) * radius / spread);
            ivec2 tap = clamp(pixel + ivec2(round(offset)), ivec2(0), screen - 1);
            if (!water_post_is_water_depth(water_post_scene_depth(DepthSampler, tap))) {
                continue;
            }
            float weight = exp(-float(i * i) / (spread * spread * 0.5)) * (j == 0 ? 1.0 : 0.6);
            accumulated += texelFetch(ReflectionSampler, tap, 0) * weight;
            weights += weight;
        }
    }
    vec4 reflection = weights > 0.0 ? accumulated / weights : vec4(0.0);
    fragColor = vec4(scene * (1.0 - reflection.a) + reflection.rgb + sparkle, 1.0);
}
