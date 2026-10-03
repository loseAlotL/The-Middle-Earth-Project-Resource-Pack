#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:oit.glsl>
#include <tmep:water_depth.glsl>
#include <tmep:camera_data.glsl>

uniform sampler2D Sampler0;
uniform sampler2D DepthBoundsSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

float waterFromBounds(vec4 bounds) {
    float waterDeviceDepth = ProjMat[3][2] / max(bounds.g, 1e-4) - ProjMat[2][2];
    #ifndef RENDERPEARL_DEPTH_IS_ZERO_TO_ONE
    waterDeviceDepth = waterDeviceDepth * 0.5 + 0.5;
    #endif
    return water_depth_mark_flag(clamp(waterDeviceDepth, 0.0, 1.0), water_bounds_underside(bounds.a) ? 0.75 : 0.5);
}

void main() {
    ivec2 pixelCoords = ivec2(gl_FragCoord.xy);
    if (pixelCoords == camera_transparency_flag_pixel(textureSize(Sampler0, 0))) {
        fragColor = vec4(CAMERA_TRANSPARENCY_FLAG, 1.0);
        gl_FragDepth = 1.0;
        return;
    }
    vec4 accumulatedColor = texelFetch(Sampler0, pixelCoords, 0);

    float sampledTransmittance = sampleTransmittance(pixelCoords, 100000.0f, 1.0);
    float coverage = 1.0 - (sampledTransmittance < OIT_FULLY_OPAQUE_TOTAL_TRANSMITTANCE ? 0.0 : sampledTransmittance);

    // Additive surfaces contribute colour but no coverage, so they only show up in rgb.
    // Discard pixels that have neither coverage nor additive light.
    if (coverage < 0.00001 && dot(accumulatedColor.rgb, vec3(1.0)) < 0.00001) {
        discard;
    }

    // Additive-only pixels have accumulatedColor.a ~ 0 (no coverage), so we skip the renormalization and let their
    // premultiplied light pass through untouched.
    float normalization = accumulatedColor.a > 0.00001 ? coverage / accumulatedColor.a : 1.0;
    fragColor = vec4(accumulatedColor.rgb * normalization, coverage);

    vec4 bounds = texelFetch(DepthBoundsSampler, pixelCoords, 0);
    float closestBoundDeviceDepth = bounds.b;
    if (!water_depth_is_water(closestBoundDeviceDepth) && water_bounds_marked(bounds.a)) {
        closestBoundDeviceDepth = waterFromBounds(bounds);
    }
    bool nearWater = bounds.b <= 0.0 && !water_depth_is_water(closestBoundDeviceDepth);
    if (!nearWater && !water_depth_is_water(closestBoundDeviceDepth)) {
        const ivec2 probes[4] = ivec2[](ivec2(2, 0), ivec2(-2, 0), ivec2(0, 2), ivec2(0, -2));
        for (int i = 0; i < 4; i++) {
            nearWater = nearWater || water_bounds_marked(texelFetch(DepthBoundsSampler, pixelCoords + probes[i], 0).a);
        }
    }
    if (nearWater) {
        for (int y = -2; y <= 2; y++) {
            for (int x = -2; x <= 2; x++) {
                vec4 candidate = texelFetch(DepthBoundsSampler, pixelCoords + ivec2(x, y), 0);
                if (water_bounds_marked(candidate.a)) {
                    float candidateDepth = water_depth_is_water(candidate.b) ? candidate.b : waterFromBounds(candidate);
                    if (!water_depth_is_water(closestBoundDeviceDepth) || candidateDepth > closestBoundDeviceDepth) {
                        closestBoundDeviceDepth = candidateDepth;
                    }
                }
            }
        }
    }
    if (!water_depth_is_water(closestBoundDeviceDepth) && bounds.b <= 0.0) {
        const ivec2 directions[8] = ivec2[](ivec2(0, -1), ivec2(0, 1), ivec2(-1, 0), ivec2(1, 0), ivec2(-1, -1), ivec2(1, -1), ivec2(-1, 1), ivec2(1, 1));
        for (int ring = 1; ring <= 16; ring++) {
            float found = -1.0;
            for (int i = 0; i < 8; i++) {
                vec4 candidate = texelFetch(DepthBoundsSampler, pixelCoords + directions[i] * ring * 3, 0);
                if (water_bounds_marked(candidate.a) && water_depth_is_water(candidate.b)) {
                    found = max(found, candidate.b);
                }
            }
            if (found > 0.0) {
                closestBoundDeviceDepth = found;
                break;
            }
        }
    }
    gl_FragDepth = closestBoundDeviceDepth;
}
