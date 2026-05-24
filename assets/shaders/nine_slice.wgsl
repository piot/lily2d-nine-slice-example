//! Nine Slice Shader
//!
//! Renders "UI panels".
//!
//! A nine-slice divides a sprite into a 3x3 grid. Corners does not stretch, edges stretch in
//! one direction, and the center cell stretches in both directions.


struct NineSliceUniform {
    view_proj: mat4x4<f32>,
};

@group(0) @binding(0)
var<uniform> globals: NineSliceUniform;

@group(0) @binding(1)
var atlas_tex: texture_2d<f32>;

@group(0) @binding(2)
var atlas_sampler: sampler;

struct VsIn {
    @location(0) corner: u32, // 0..15

    // Instance attributes
    @location(1) target_position: vec2<f32>,
    @location(2) screen_x: vec4<f32>, // 4 column edges in local pixels
    @location(3) screen_y: vec4<f32>, // 4 row edges in local pixels
    @location(4) uv_x: vec4<f32>,     // matching u coordinates in atlas
    @location(5) uv_y: vec4<f32>,     // matching v coordinates in atlas
    @location(6) tint: vec4<f32>,
    @location(7) depth: f32,          // z before view_proj transform, should be negative
};

struct VSOut {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) tint: vec4<f32>,
};


@vertex
fn vs_main(in: VsIn) -> VSOut {
    let col = in.corner % 4u;
    let row = in.corner / 4u;

    let local_pos = vec2<f32>(in.screen_x[col], in.screen_y[row]) + in.target_position;
    let uv = vec2<f32>(in.uv_x[col], in.uv_y[row]);

    var out: VSOut;

    out.position = globals.view_proj * vec4<f32>(local_pos, in.depth, 1.0);
    out.uv = uv;
    out.tint = in.tint;

    return out;
}


@fragment
fn fs_main(in: VSOut) -> @location(0) vec4<f32> {
    return textureSample(atlas_tex, atlas_sampler, in.uv) * in.tint;
}
