#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 localPosition;
    float2 uv;
    uint shardIndex;
    uint padding;
};

struct ShardUniform {
    float4x4 transform;
    float4 parameters;
};

struct GlobalUniform {
    float2 viewportSize;
    float2 targetSize;
    float elapsed;
    float padding;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float opacity;
};

vertex VertexOut BGT_Vertex(
    uint vertexID [[vertex_id]],
    const device VertexIn *vertices [[buffer(0)]],
    const device ShardUniform *shardUniforms [[buffer(1)]],
    constant GlobalUniform &globalUniform [[buffer(2)]]
) {
    VertexIn vin = vertices[vertexID];
    ShardUniform shard = shardUniforms[vin.shardIndex];

    float4 localPosition = float4(vin.localPosition, 0.0, 1.0);
    float4 worldPosition = shard.transform * localPosition;

    float2 viewport = max(globalUniform.viewportSize, float2(1.0));
    float2 target = max(globalUniform.targetSize, float2(1.0));
    float2 inset = (viewport - target) * 0.5;

    float2 adjusted = float2(worldPosition.x + inset.x, worldPosition.y + inset.y);

    float2 ndc;
    ndc.x = (adjusted.x / viewport.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (adjusted.y / viewport.y) * 2.0;

    VertexOut output;
    output.position = float4(ndc, 0.0, 1.0);
    output.uv = vin.uv;
    output.opacity = shard.parameters.x;
    return output;
}

fragment float4 BGT_Fragment(
    VertexOut input [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    sampler colorSampler [[sampler(0)]]
) {
    float4 color = float4(0.0);
    if (!is_null_texture(colorTexture)) {
        color = colorTexture.sample(colorSampler, input.uv);
        color.rgb *= input.opacity;
        color.a *= input.opacity;
    }
    return color;
}
