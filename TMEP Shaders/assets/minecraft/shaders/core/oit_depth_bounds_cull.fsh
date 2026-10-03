#version 330
#extension GL_ARB_separate_shader_objects : require

#include <minecraft:oit_common.glsl>
#include <tmep:water_depth.glsl>

uniform sampler2D DepthBoundsSampler;

layout(location = 0) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

void main() {
    ivec2 pixelCoords = ivec2(gl_FragCoord.xy);
    vec4 depthBounds = texelFetch(DepthBoundsSampler, pixelCoords, 0);

    if (water_bounds_marked(depthBounds.a)) {
        fragColor = depthBounds;
        gl_FragDepth = 0.0;
        return;
    }

    float closestBoundLinearDepthNegated = depthBounds.r;
    float furthestBoundLinearDepth = depthBounds.g;
    float closestBoundDeviceDepth = depthBounds.b;
    float opaqueOitDeviceDepth = depthBounds.a;

    float opaqueOitLinearDepth = deviceToLinearDepth(opaqueOitDeviceDepth);

    fragColor = vec4(closestBoundLinearDepthNegated, min(furthestBoundLinearDepth, opaqueOitLinearDepth), closestBoundDeviceDepth, opaqueOitDeviceDepth);
    gl_FragDepth = opaqueOitDeviceDepth;
}
