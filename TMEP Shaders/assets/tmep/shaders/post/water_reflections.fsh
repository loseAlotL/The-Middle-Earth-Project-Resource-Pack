#version 330
#extension GL_ARB_separate_shader_objects : require

#define CAMERA_FROM_QUAD

#include <tmep:water_post.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;
uniform sampler2D RipplesSampler;
uniform sampler2D ProbeSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform ReflectionConfig {
    vec4 Reflection;
    vec4 Surface;
    vec4 Sky;
};

layout(location = 0) out vec4 fragColor;

const int OCCLUDER_OFFSETS[5] = int[](0, 2, -2, 4, -4);

float reflectionOriginDistance = 0.0;
float reflectionNearestDistance = 0.0;

float reflectionOriginHorizontal = 0.0;

float sceneBehind(Camera camera, vec2 uv, vec3 point, ivec2 screen, out bool usable) {
    ivec2 center = clamp(ivec2(uv * vec2(screen)), ivec2(0), screen - 1);
    float pointDistance = length(point);
    usable = false;
    for (int i = 0; i < 5; i++) {
        ivec2 pixel = clamp(center + ivec2(OCCLUDER_OFFSETS[i], 0), ivec2(0), screen - 1);
        float depth = water_post_scene_depth(DepthSampler, pixel);
        if (depth <= 0.0 || water_post_is_water_depth(depth) || water_post_is_hand_depth(depth) || camera_is_data_pixel(pixel)) {
            return -1e9;
        }
        vec2 sampleUv = (vec2(pixel) + 0.5) / vec2(screen);
        vec3 scenePoint = camera_relative(camera, sampleUv, depth);
        if (scenePoint.y + camera_world_origin().y > Sky.x - Sky.z) {
            return -1e9;
        }
        float sceneDistance = length(scenePoint);
        if (sceneDistance < reflectionOriginDistance * 0.9 || sceneDistance < reflectionNearestDistance || length(scenePoint.xz) < reflectionOriginHorizontal - 0.3) {
            return -1e9;
        }
        if (sceneDistance > pointDistance * 0.5 || i == 4) {
            usable = true;
            return pointDistance - sceneDistance;
        }
    }
    return -1e9;
}

void main() {
    fragColor = vec4(0.0);
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    if (!water_post_is_water_pixel(DepthSampler, pixel)) {
        return;
    }
    Camera camera = camera_load(InSampler);
    if (!camera.valid || camera_is_data_pixel(pixel)) {
        return;
    }

    ivec2 screen = textureSize(DepthSampler, 0);
    float depth = water_post_scene_depth(DepthSampler, pixel);
    vec3 origin = camera_relative(camera, texCoord, depth);
    reflectionOriginHorizontal = length(origin.xz);
    float distance = length(origin);
    reflectionOriginDistance = distance;
    vec3 viewDirection = origin / distance;
    vec3 world = origin + camera_world_origin();

    float distortion = Surface.x * exp(-distance / Surface.z) * (1.0 - water_post_grazing(viewDirection) * 0.85);
    vec2 gradient = water_post_ripple_gradient(RipplesSampler, world.xz, GameTime * 1200.0) * distortion;
    vec3 normal = normalize(vec3(-gradient.x, 1.0, -gradient.y));
    vec3 direction = reflect(viewDirection, normal);
    direction = normalize(vec3(direction.x, max(direction.y, 0.02), direction.z));

    float nv = max(dot(normal, -viewDirection), 0.0);
    float fresnel = WATER_F0 + (1.0 - WATER_F0) * pow(1.0 - nv, 5.0);
    mat4 viewProjection = camera.projection * camera.view;

    float stepLength = Reflection.w;
    float travelled = 0.15 + fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715)))) * Reflection.w;
    bool hit = false;
    bool exited = false;
    vec2 hitUv = vec2(0.0);
    vec2 lastUv = vec2(-1.0);
    int steps = int(Reflection.z);
    for (int i = 0; i < steps; i++) {
        float previous = travelled;
        travelled += stepLength;
        if (travelled > Reflection.y) {
            break;
        }
        bool visible;
        vec3 point = origin + direction * travelled;
        reflectionNearestDistance = length(origin + direction * previous) - 0.35 - stepLength * 0.15;
        vec2 uv = water_post_project(viewProjection, point, visible);
        if (!visible) {
            exited = true;
            break;
        }
        lastUv = uv;
        bool usable;
        float behind = sceneBehind(camera, uv, point, screen, usable);
        if (usable && behind > 0.0 && behind < min(stepLength * 2.0 + 0.5, max(1.5, length(point) * 0.12))) {
            float low = previous;
            float high = travelled;
            for (int j = 0; j < 6; j++) {
                float middle = (low + high) * 0.5;
                vec3 probe = origin + direction * middle;
                bool probeVisible;
                vec2 probeUv = water_post_project(viewProjection, probe, probeVisible);
                bool probeUsable;
                float probeBehind = sceneBehind(camera, probeUv, probe, screen, probeUsable);
                if (probeUsable && probeBehind > 0.0) {
                    high = middle;
                    uv = probeUv;
                } else {
                    low = middle;
                }
            }
            hit = true;
            hitUv = uv;
            break;
        }
        stepLength *= 1.15;
    }

    float cameraHeight = camera_world_origin().y;
    float parallax = cameraHeight < Sky.x && world.y < Sky.x ? smoothstep(0.0, Sky.y, Sky.x - cameraHeight) : 0.0;
    vec3 skyDirection = direction;
    if (parallax > 0.0 && direction.y > 0.001) {
        vec3 cloudPoint = origin + direction * min((Sky.x - world.y) / direction.y, 4096.0);
        skyDirection = normalize(mix(direction, normalize(cloudPoint), parallax));
    }
    skyDirection = normalize(vec3(skyDirection.x, max(skyDirection.y, 0.02), skyDirection.z));
    vec3 skyPoint = skyDirection * 4096.0;
    vec4 probe = skyDirection.y > 0.0 ? texture(ProbeSampler, water_post_probe_uv(skyDirection)) : vec4(0.0);
    vec3 skyColor = probe.rgb;
    float skyWeight = probe.a > 0.5 ? 1.0 : 0.0;

    bool skyVisible;
    vec2 skyUv = water_post_project(viewProjection, skyPoint, skyVisible);
    if (skyVisible) {
        ivec2 skyPixel = clamp(ivec2(skyUv * vec2(screen)), ivec2(0), screen - 1);
        float skyDepth = water_post_scene_depth(DepthSampler, skyPixel);
        vec3 skyScenePoint = camera_relative(camera, skyUv, max(skyDepth, 1e-7));
        bool distant = skyDepth <= 0.0 || (!water_post_is_water_depth(skyDepth) && length(skyScenePoint) > Reflection.y && skyScenePoint.y > origin.y + 2.0);
        if (distant && !camera_is_data_pixel(skyPixel)) {
            vec2 skyEdge = min(skyUv, 1.0 - skyUv);
            float screenConfidence = smoothstep(0.0, Surface.y, min(skyEdge.x, skyEdge.y));
            vec3 screenSky = camera_scene_color(InSampler, water_post_scene_pixel(DepthSampler, skyPixel));
            skyColor = skyWeight > 0.0 ? mix(skyColor, screenSky, screenConfidence) : screenSky;
            skyWeight = max(skyWeight, screenConfidence);
        }
    }

    vec3 reflection = skyColor;
    float strength = skyWeight * Surface.w;
    float reach = 1.0 - smoothstep(Reflection.y * 0.6, Reflection.y, travelled);
    if (!hit && exited && lastUv.x >= 0.0) {
        ivec2 edgePixel = water_post_scene_pixel(DepthSampler, clamp(ivec2(lastUv * vec2(screen)), ivec2(0), screen - 1));
        float edgeDepth = water_post_scene_depth(DepthSampler, edgePixel);
        if (edgeDepth > 0.0 && !water_post_is_water_depth(edgeDepth) && !camera_is_data_pixel(edgePixel)) {
            float stretch = 0.75 * reach * smoothstep(0.85, 0.97, lastUv.y) * smoothstep(0.0, Surface.y, min(lastUv.x, 1.0 - lastUv.x));
            reflection = mix(reflection, camera_scene_color(InSampler, edgePixel), stretch);
            strength = mix(strength, Reflection.x, stretch);
        }
    }
    if (hit) {
        vec2 edge = min(hitUv, 1.0 - hitUv);
        float confidence = smoothstep(0.0, Surface.y, edge.x) * max(smoothstep(0.0, Surface.y, edge.y), hitUv.y > 0.5 ? 0.75 : 0.0) * reach;
        vec3 terrain = camera_scene_color(InSampler, water_post_scene_pixel(DepthSampler, clamp(ivec2(hitUv * vec2(screen)), ivec2(0), screen - 1)));
        reflection = skyWeight > 0.0 ? mix(skyColor, terrain, confidence) : terrain;
        strength = mix(strength, Reflection.x, confidence);
    }

    float weight = clamp(fresnel * strength, 0.0, 1.0);
    fragColor = vec4(reflection * weight, weight);
}
