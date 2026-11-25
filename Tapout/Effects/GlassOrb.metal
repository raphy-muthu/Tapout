#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Straight-alpha colour `rgb` with alpha `a`, composited over premultiplied `dst`.
static half4 over(half4 dst, float3 rgb, float a) {
    half ha = half(clamp(a, 0.0, 1.0));
    return half4(half3(rgb) * ha + dst.rgb * (1.0h - ha), ha + dst.a * (1.0h - ha));
}

// Distance from an ellipse's centre, 1 at its edge.
static float ellipse(float2 p, float2 c, float2 radii) {
    return length((p - c) / radii);
}

// Draws the glass orb. The canvas is `canvas` points square (the orb is `orbSize` wide, centred,
// so the glow and ripples have room). Units below: 1.0 is half the orb's width.
// Task 5 (GlassOrbView) passes the arguments in exactly this order; keep it.
[[ stitchable ]] half4 glassOrb(
    float2 position, half4 currentColor,
    float canvas, float orbSize,
    float tiltX, float tiltY, float time, float lightMode,
    float3 hi, float3 mid, float3 deep, float3 edge,
    float3 glow, float glowAlpha,
    float3 rippleColor, float3 rippleAges, float amplitude)
{
    const float unit = orbSize * 0.5;
    float2 p = (position - float2(canvas * 0.5)) / unit;
    float r = length(p);
    const float R = 0.74;                 // sphere radius: the orb is inset 13% each side
    const float aa = 1.5 / unit;          // 1.5 pt
    float2 tilt = float2(tiltX, tiltY);
    half4 out = half4(0);

    // Glow: a radial halo, 1.44x the orb (see OrbView.glow).
    float t = r * 0.5 / 1.018;
    // `time` arrives wrapped at 86400 s (GlassOrbView), so the caustic jumps at most once a day.
    float g = t < 0.38 ? mix(1.0, 0.35, t / 0.38) : mix(0.35, 0.0, saturate((t - 0.38) / 0.30));
    out = over(out, glow, g * glowAlpha);

    // Drop shadow under the sphere.
    float shadow = 1.0 - smoothstep(R * 0.80, R * 1.32, length(p - float2(0.0, 0.16 * R)));
    bool light = lightMode > 0.5;
    out = over(out, light ? float3(0.082, 0.09, 0.106) : float3(0.0), shadow * (light ? 0.18 : 0.5));

    // Glass body.
    float inside = 1.0 - smoothstep(R - aa, R + aa, r);
    if (inside > 0.0) {
        float2 pn = p / R;                                       // -1...1 across the sphere
        float2 centre = float2(tilt.x * 0.24, 0.16 + tilt.y * 0.24);
        float bt = length(pn - centre) / 1.532;
        float3 c = mix(hi, mid, saturate(bt / 0.34));
        c = mix(c, deep, saturate((bt - 0.34) / 0.38));
        c = mix(c, edge, saturate((bt - 0.72) / 0.28));

        // Light pooling at the bottom of the glass. Drawn before the inner shading, because CSS
        // paints inset shadows above the background gradients.
        float pool = 1.0 - saturate(ellipse(pn, float2(-tilt.x * 0.16, 0.84 - tilt.y * 0.10), float2(1.4, 0.68)) / 0.7);
        c = mix(c, float3(1.0), 0.32 * pool);

        // Inner shading, as Orb.dc.html's inset shadows and OrbView's .inner shadows: a little dark
        // along the top inner edge (0.28), a little light along the bottom inner edge (0.14).
        // Positive y is down. (smoothstep needs edge0 < edge1 in Metal, so a falling ramp is 1 - smoothstep.)
        c = mix(c, float3(0.0), 0.28 * smoothstep(0.7, 1.0, length(pn - float2(0.0, 0.12))) * (1.0 - smoothstep(-0.8, 0.1, pn.y)));
        c = mix(c, float3(1.0), 0.14 * smoothstep(0.75, 1.0, length(pn - float2(0.0, -0.10))) * smoothstep(-0.1, 0.8, pn.y));

        // A slow caustic drifting through the glass.
        float a = time * 0.5 * amplitude;
        float caustic = 1.0 - saturate(ellipse(pn, float2(cos(a) * 0.38 + tilt.x * 0.2, sin(a * 1.3) * 0.30), float2(0.6, 0.4)));
        c = mix(c, float3(1.0), 0.17 * caustic);

        // Main gloss, follows the tilt.
        float ge = ellipse(pn, float2(-0.30 + tilt.x * 0.36, -0.52 + tilt.y * 0.36), float2(0.6, 0.4));
        float gloss = ge < 0.45 ? mix(0.92, 0.35, ge / 0.45) : mix(0.35, 0.0, saturate((ge - 0.45) / 0.55));
        c = mix(c, float3(1.0), gloss);

        // Small secondary gloss.
        float se = 1.0 - saturate(ellipse(pn, float2(0.32 - tilt.x * 0.1, 0.56 - tilt.y * 0.1), float2(0.24, 0.14)));
        c = mix(c, float3(1.0), 0.4 * se);

        // Fresnel rim.
        c = mix(c, float3(1.0), 0.2 * saturate((length(pn - tilt * 0.1) - 0.74) / 0.26));

        out = over(out, c, inside);
    }

    // Hairline rim.
    float rim = 1.0 - smoothstep(0.0, aa * 1.4, abs(r - (R - aa * 0.7)));
    out = over(out, float3(1.0), 0.22 * rim);

    // Ripples travelling outward from the sphere.
    for (int i = 0; i < 3; i++) {
        float age = rippleAges[i];
        if (age >= 0.0 && age < 1.5) {
            float q = age / 1.5;
            float e = 1.0 - pow(1.0 - q, 2.2);
            // Peaks at about 1.40 units, inside the canvas's half-width of 1.44, so no ripple is cut flat.
            float radius = R * 1.04 + e * R * 0.85;
            float width = (1.0 + 3.0 * (1.0 - q)) / unit;
            float line = 1.0 - smoothstep(0.0, width, abs(r - radius));
            out = over(out, rippleColor, pow(1.0 - q, 1.6) * 0.6 * line * amplitude);
        }
    }
    return out;
}
