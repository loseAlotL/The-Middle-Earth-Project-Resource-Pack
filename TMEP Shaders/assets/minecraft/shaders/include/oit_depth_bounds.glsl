#ifndef MINECRAFT_OIT_DEPTH_BOUNDS_GLSL
#define MINECRAFT_OIT_DEPTH_BOUNDS_GLSL
#define TMEP_OIT_FLAGS

#include <tmep:water_depth.glsl>

layout(location = 0) out vec4 fragColor;

bool oitDepthBoundsWater = false;
bool oitDepthBoundsUnderside = false;
bool oitDepthBoundsHand = false;
bool oitDepthBoundsRain = false;

void calculateDepthBounds(float fragmentDeviceDepth, float alpha) {
    float fragmentLinearDepth = deviceToLinearDepth(fragmentDeviceDepth);
    float opaqueFragmentDeviceDepth = alpha > OIT_FULLY_OPAQUE_ALPHA ? fragmentDeviceDepth : 0.0;
    float flag = 0.0;
    if (oitDepthBoundsUnderside) {
        opaqueFragmentDeviceDepth = WATER_DEPTH_UNDERSIDE_MARK;
        flag = 0.75;
    } else if (oitDepthBoundsWater) {
        opaqueFragmentDeviceDepth = WATER_DEPTH_DEEP_MARK;
        flag = 0.5;
    } else if (oitDepthBoundsHand) {
        flag = 0.25;
    } else if (oitDepthBoundsRain) {
        flag = 0.125;
    }
    fragColor = vec4(-fragmentLinearDepth, fragmentLinearDepth, water_depth_mark_flag(fragmentDeviceDepth, flag), opaqueFragmentDeviceDepth);
}

#endif
