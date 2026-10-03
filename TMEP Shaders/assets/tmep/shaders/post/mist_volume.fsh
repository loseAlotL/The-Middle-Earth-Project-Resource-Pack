#version 330
#extension GL_ARB_separate_shader_objects : require

#include <tmep:world.glsl>

uniform sampler2D InSampler;
uniform sampler2D DepthSampler;

layout(location = 0) in vec2 texCoord;

layout(std140) uniform MistVolumeConfig {
    vec4 BoxMin;
    vec4 BoxMax;
    vec4 MistColor;
    vec4 GlowColor;
    vec4 Shape;
    vec4 Motion;
};

layout(location = 0) out vec4 fragColor;

float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    float n000 = hash13(i);
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
    return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
               mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

float fbm3(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 3; i++) {
        value += amplitude * noise3(p);
        p = p * 2.07 + vec3(11.3, 7.1, 3.7);
        amplitude *= 0.5;
    }
    return value;
}

float interleavedGradientNoise(vec2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

vec2 intersectBox(vec3 origin, vec3 direction, vec3 boxMin, vec3 boxMax) {
    vec3 inverseDirection = 1.0 / direction;
    vec3 t0 = (boxMin - origin) * inverseDirection;
    vec3 t1 = (boxMax - origin) * inverseDirection;
    vec3 near = min(t0, t1);
    vec3 far = max(t0, t1);
    return vec2(max(max(near.x, near.y), near.z), min(min(far.x, far.y), far.z));
}

float density(vec3 world, vec3 drift) {
    vec3 boxMin = BoxMin.xyz;
    vec3 boxMax = BoxMax.xyz;
    vec3 inside = min(world - boxMin, boxMax - world);
    float edge = smoothstep(0.0, Shape.y, min(min(inside.x, inside.z), inside.y + Shape.y * 0.5));
    float height = exp(-max(world.y - boxMin.y, 0.0) * Shape.w);
    vec3 p = mod(world, 1024.0) * Shape.x + drift;
    float n = fbm3(p);
    float wisps = smoothstep(Shape.z, 1.0, n);
    return MistColor.a * edge * height * wisps;
}

void main() {
    ivec2 pixel = ivec2(gl_FragCoord.xy);
    vec3 scene = camera_scene_color(InSampler, pixel);
    Camera camera = camera_load(InSampler);
    if (!camera.valid) {
        fragColor = vec4(scene, 1.0);
        return;
    }

    float depth = texelFetch(DepthSampler, pixel, 0).r;
    vec3 direction = camera_ray(camera, texCoord);
    float sceneDistance = depth > 0.0 ? length(camera_relative(camera, texCoord, depth)) : 1e5;

    vec3 origin = camera_world_origin();
    vec2 hit = intersectBox(origin, direction, BoxMin.xyz, BoxMax.xyz);
    float start = max(hit.x, 0.0);
    float end = min(hit.y, sceneDistance);
    if (end <= start) {
        fragColor = vec4(scene, 1.0);
        return;
    }

    float angle = GameTime * 6.2831853 * Motion.x;
    vec3 drift = vec3(cos(angle), sin(angle * 2.0) * 0.35, sin(angle)) * Motion.y;

    int steps = int(Motion.z);
    float stepLength = (end - start) / float(steps);
    float t = start + stepLength * interleavedGradientNoise(gl_FragCoord.xy);
    float transmittance = 1.0;
    vec3 light = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        vec3 world = origin + direction * t;
        float sigma = density(world, drift);
        float absorbed = 1.0 - exp(-sigma * stepLength);
        vec3 tint = mix(MistColor.rgb, GlowColor.rgb, clamp(sigma * GlowColor.a, 0.0, 1.0));
        light += transmittance * absorbed * tint;
        transmittance *= 1.0 - absorbed;
        if (transmittance < 0.01) {
            break;
        }
        t += stepLength;
    }

    fragColor = vec4(scene * transmittance + light, 1.0);
}
