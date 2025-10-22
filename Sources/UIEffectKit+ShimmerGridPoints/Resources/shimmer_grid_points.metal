#include <metal_stdlib>
using namespace metal;

// Grid point shaped as either circle (star-like with sparkle) or diamond
// with subtle wiggle and synchronized wave rhythms.

struct GridPoint {
    float2 origin;      // grid origin in pixels
    float2 jitter;      // per-point jitter phase seeds
    float2 size;        // (baseRadius, blur)
    float2 props;       // (shapeType 0=circle 1=diamond, baseIntensity)
    float2 wave;        // (rowPhase, colPhase)
};

struct VertexIn {
    float2 position;    // quad -0.5..0.5
};

struct Uniforms {
    float2 drawableSize;
    float time;
    float3 baseColor;
    float waveSpeed;
    float waveStrength;
    float blurMin;
    float blurMax;
    float intensityMin;
    float intensityMax;
    int shapeMode;     // 0 mixed, 1 circles, 2 diamonds
    int enableWiggle;  // bool
    float2 hoverPos;   // in pixels
    float hoverRadius;
    float hoverBoost;
};

struct VertexOut {
    float4 position [[position]];
    float2 localPos;    // -1..1 quad space
    float blur;
    float type;
    float intensity;
    float2 originPx;    // pass to fragment for hover falloff
};

vertex VertexOut SGP_Vertex(const device VertexIn *vertices [[buffer(0)]],
                            const device GridPoint *points [[buffer(1)]],
                            constant Uniforms &U [[buffer(2)]],
                            uint vertexId [[vertex_id]],
                            uint instanceId [[instance_id]]) {
    VertexIn vin = vertices[vertexId];
    GridPoint p = points[instanceId];

    float baseRadius = clamp(p.size.x, 4.0, 8.0);
    float blur = clamp(p.size.y, U.blurMin, U.blurMax);

    // Global wave to create ordered rhythm; traveling wave along grid
    float phase = p.wave.x + p.wave.y;
    float wave = 0.5 + 0.5 * sin(U.waveSpeed * U.time + phase);
    float radius = baseRadius * mix(1.0 - 0.15 * U.waveStrength, 1.0 + 0.15 * U.waveStrength, wave);
    // Blur is also modulated by wave strength
    blur = clamp( mix(blur * (1.0 - 0.5 * U.waveStrength), blur * (1.0 + 0.5 * U.waveStrength), wave), U.blurMin, U.blurMax);

    // Optional small wiggle of position; disabled by default to keep grid locked
    float2 wiggle = float2(0.0);
    if (U.enableWiggle != 0) {
        float rand01 = fract(sin(p.jitter.x * 12.9898 + p.jitter.y * 78.233) * 43758.5453);
        float wiggleAmp = mix(4.0, 8.0, rand01);
        wiggle = float2(
            sin(U.time * 2.3 + p.jitter.x),
            cos(U.time * 2.0 + p.jitter.y)
        ) * wiggleAmp;
    }

    float2 offsetPx = vin.position * (radius * 2.0);
    float2 ndc = float2(
        (p.origin.x + wiggle.x) / max(U.drawableSize.x, 1.0) * 2.0 - 1.0,
        1.0 - (p.origin.y + wiggle.y) / max(U.drawableSize.y, 1.0) * 2.0
    );

    VertexOut outv;
    float2 offsetNdc = float2(
        (offsetPx.x / max(U.drawableSize.x, 1.0)) * 2.0,
        -(offsetPx.y / max(U.drawableSize.y, 1.0)) * 2.0
    );
    outv.position = float4(ndc + offsetNdc, 0.0, 1.0);
    outv.localPos = vin.position * 2.0; // -1..1
    outv.blur = blur;
    outv.type = p.props.x;
    outv.originPx = p.origin + wiggle;

    float baseIntensity = clamp(p.props.y, U.intensityMin, U.intensityMax);
    float flicker = 0.85 + 0.30 * sin(U.time * 3.0 + p.jitter.x * 1.7 + p.jitter.y * 0.6);
    outv.intensity = saturate(baseIntensity * mix(1.0 - 0.2 * U.waveStrength, 1.0 + 0.2 * U.waveStrength, wave) * flicker);
    return outv;
}

fragment float4 SGP_Fragment(VertexOut in [[stage_in]], constant Uniforms &U [[buffer(0)]]) {
    float2 pos = in.localPos; // -1..1

    float mask;
    float typeSel = in.type;
    if (U.shapeMode == 1) typeSel = 0.0;
    else if (U.shapeMode == 2) typeSel = 1.0;

    if (typeSel < 0.5) {
        // Circular point with soft sparkle falloff
        float r = length(pos);
        float feather = max(in.blur, 0.03);
        mask = smoothstep(1.0, 1.0 - feather, r);
        float sparkle = 1.0 + 0.25 * pow(max(0.0, 1.0 - r), 8.0);
        mask *= sparkle;
    } else {
        // Diamond rotated 45°: L1 norm (|x| + |y|)
        float edge = (abs(pos.x) + abs(pos.y));
        float feather = max(in.blur * 0.9, 0.03);
        mask = smoothstep(1.0, 1.0 - feather, edge);
    }

    // Hover boost: radial falloff in pixels
    float2 toHover = in.originPx - U.hoverPos;
    float d2 = dot(toHover, toHover);
    float r = U.hoverRadius;
    float hoverAtten = (U.hoverRadius > 0.0) ? exp(-d2 / max(1.0, r * r)) : 0.0;
    float boost = 1.0 + U.hoverBoost * hoverAtten;

    float a = clamp(mask * in.intensity * boost, 0.02, 0.95);
    float3 c = U.baseColor * (0.8 + 0.2 * in.intensity);
    return float4(c * a, a);
}
