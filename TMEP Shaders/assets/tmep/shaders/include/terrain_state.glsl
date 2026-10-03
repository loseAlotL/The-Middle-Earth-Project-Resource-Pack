#ifndef TMEP_TERRAIN_STATE_GLSL
#define TMEP_TERRAIN_STATE_GLSL

#include <tmep:lighting.glsl>

LightState vertexLightState() {
    LightState state;
    state.sun = v_Sun.xyz;
    state.sunColor = v_SunColor.rgb;
    state.exposure = v_SunColor.a;
    state.sunVisibility = v_Vis.x;
    state.moonVisibility = v_Vis.y;
    state.twilight = v_Vis.z;
    state.rain = v_Vis.w;
    return state;
}

#endif
