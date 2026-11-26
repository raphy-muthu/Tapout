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
        float rr = dot(pn, pn);
        // Lens: what is seen through the glass bends more toward the edge.
        float2 q = pn * (0.72 + 0.42 * rr);

        // A tap sends a wave across the surface, bending the light as it passes.
        float wave = 0.0;
        for (int i = 0; i < 3; i++) {
            float age = rippleAges[i];
            if (age >= 0.0 && age < 0.9) {
                float front = age / 0.9 * 1.25;
                float d = length(pn) - front;
                wave += exp(-d * d * 60.0) * (1.0 - age / 0.9) * amplitude;
            }
        }
        q += pn * wave * 0.22;

        float2 centre = float2(tilt.x * 0.40, 0.14 + tilt.y * 0.40);
        float bt = length(q - centre) / 1.30;
        float3 c = mix(hi, mid, saturate(bt / 0.30));
        c = mix(c, deep, saturate((bt - 0.30) / 0.36));
        c = mix(c, edge, saturate((bt - 0.66) / 0.30));

        // Light flowing inside the glass: two slow warped fields, brightest where they cross.
        float t1 = time * amplitude;
        float2 w = q * 2.4 + tilt * 1.1;
        float f1 = sin(w.x * 1.3 + t1 * 0.80 + 1.6 * sin(w.y * 1.1 - t1 * 0.55));
        float f2 = sin(w.y * 1.5 - t1 * 0.62 + 1.4 * sin(w.x * 0.9 + t1 * 0.47));
        float flow = smoothstep(0.10, 0.95, f1 * f2) * (1.0 - smoothstep(0.35, 1.0, rr));
        float veil = smoothstep(0.25, 1.0, -f1 * f2) * (1.0 - smoothstep(0.3, 1.0, rr));
        c = mix(c, hi, 0.58 * flow);
        c = mix(c, deep, 0.34 * veil);

        // Light pooling at the bottom of the glass.
        float pool = 1.0 - saturate(ellipse(pn, float2(-tilt.x * 0.30, 0.80 - tilt.y * 0.18), float2(1.1, 0.50)) / 0.8);
        c = mix(c, hi, 0.55 * pool * pool);

        // The edge falls away into shadow, which is what makes it read as a solid ball.
        float falloff = smoothstep(0.55, 1.0, length(pn - float2(-tilt.x * 0.08, -tilt.y * 0.08)));
        c = mix(c, edge * 0.55, 0.55 * falloff);

        // Reflection of an upper light: a crescent just inside the rim, sliding with the tilt.
        float2 lean = float2(tilt.x * 0.22, tilt.y * 0.22);
        float outer = 1.0 - smoothstep(0.84, 0.94, length(pn - lean * 0.3));
        float cut = smoothstep(0.76, 0.98, length(pn - float2(0.16, 0.22) - lean));
        c = mix(c, float3(1.0), 0.62 * outer * cut * (1.0 - smoothstep(-0.5, 0.45, pn.x + pn.y)));

        // Bounce light along the lower edge, in the state's colour.
        float outer2 = 1.0 - smoothstep(0.90, 0.99, length(pn));
        float cut2 = smoothstep(0.82, 1.02, length(pn - float2(-0.14, -0.20) + lean));
        c = mix(c, mix(mid, float3(1.0), 0.45), 0.75 * outer2 * cut2 * smoothstep(0.0, 0.9, pn.x * 0.5 + pn.y));

        // Main gloss, with a hard hot spot at its heart.
        float2 g = float2(-0.34 + tilt.x * 0.52, -0.48 + tilt.y * 0.52);
        float ge = ellipse(pn, g, float2(0.46, 0.30));
        float gloss = ge < 0.45 ? mix(0.88, 0.28, ge / 0.45) : mix(0.28, 0.0, saturate((ge - 0.45) / 0.55));
        c = mix(c, float3(1.0), gloss);
        float spot = 1.0 - smoothstep(0.35, 1.0, ellipse(pn, g + float2(-0.03, -0.02), float2(0.11, 0.075)));
        c = mix(c, float3(1.0), spot);

        // Small secondary glints.
        float se = 1.0 - saturate(ellipse(pn, float2(0.36 - tilt.x * 0.30, 0.50 - tilt.y * 0.30), float2(0.17, 0.10)));
        c = mix(c, float3(1.0), 0.55 * se);
        float se2 = 1.0 - saturate(ellipse(pn, float2(0.52 - tilt.x * 0.22, 0.30 - tilt.y * 0.22), float2(0.05, 0.05)));
        c = mix(c, float3(1.0), 0.8 * se2);

        // The wave's crest.
        c = mix(c, float3(1.0), saturate(wave) * 0.45);

        out = over(out, c, inside);

        // Fresnel rim, split slightly into warm and cool like thick glass.
        float angle = atan2(pn.y, pn.x);
        float shimmer = 0.5 + 0.5 * sin(angle * 2.0 + t1 * 0.6 + tilt.x * 3.0);
        float warm = 1.0 - smoothstep(0.0, 0.05, abs(length(pn) - 0.955));
        float cool = 1.0 - smoothstep(0.0, 0.05, abs(length(pn) - 0.905));
        out = over(out, mix(mid, float3(1.0), 0.45), 0.34 * warm * shimmer * inside);
        out = over(out, float3(0.68, 0.82, 1.0), 0.24 * cool * (1.0 - shimmer) * inside);
    }

    // Hairline rim.
    float rim = 1.0 - smoothstep(0.0, aa * 1.4, abs(r - (R - aa * 0.7)));
    out = over(out, float3(1.0), 0.34 * rim);

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
