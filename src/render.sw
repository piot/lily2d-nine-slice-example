//! Nine Slice Rendering Example

use lily::wgpu_types::{Vec4f, Vec2f, Mat4f}
use lily::wgpu
use lily::gm
mod simulation::{ExampleSimulation}

/// Must match the WGSL `NineSliceUniform` struct layout.
#[repr(uniform)]
struct NineSliceUniform {
    view_proj: Mat4f,
}

struct NineSliceInstance {
    /// Target world position
    target_position: Vec2f,
    /// Four column boundaries in local pixels: [left, left+border, right-border, right].
    screen_x: Vec4f,
    /// Four row boundaries in local pixels: [bottom, bottom+border, top-border, top].
    screen_y: Vec4f,
    /// [0..1]
    uv_x: Vec4f,
    /// [0..1]
    uv_y: Vec4f,
    /// RGBA color multiplier for the widget.
    tint: Vec4f,
    /// Z depth.
    depth: F32,
}



const NINE_SLICE_CORNERS: Block<U32; 16> = [
    0,  1,  2,  3,
    4,  5,  6,  7,
    8,  9,  10, 11,
    12, 13, 14, 15,
]

/// Static index buffer: 9 quads × 2 triangles × 3 indices = 54 index entries.
const NINE_SLICE_INDICES: Block<U16; 54> = [
    0,  1,  4,   4,  1,  5   // quad 0: top-left corner
    1,  2,  5,   5,  2,  6
    2,  3,  6,   6,  3,  7
    4,  5,  8,   8,  5,  9
    5,  6,  9,   9,  6,  10
    6,  7,  10,  10, 7,  11
    8,  9,  12,  12, 9,  13
    9,  10, 13,  13, 10, 14
    10, 11, 14,  14, 11, 15
]

struct ExampleRender {
    nine_slices_atlas_texture: wgpu::TextureHandle
    nine_slices_atlas_texture_view: wgpu::TextureViewHandle

    nine_slice_pipeline_layout: wgpu::PipelineLayoutHandle
    nine_slice_uniform_bind_group_layout: wgpu::BindGroupLayoutHandle
    nine_slice_texture_bind_group_layout: wgpu::BindGroupLayoutHandle

    nine_slice_corners: wgpu::BufferHandle
    nine_slice_indices: wgpu::BufferHandle

    nine_slice_pipeline: wgpu::RenderPipelineHandle
    nine_slice_uniform_bind_group: wgpu::BindGroupHandle
    nine_slice_texture_bind_group: wgpu::BindGroupHandle

    nine_slice_uniform_buffer: wgpu::BufferHandle

    nine_slice_instance_buffer: wgpu::BufferHandle
}

impl ExampleRender {
    fn new() -> ExampleRender {
        nine_slices_atlas_texture := wgpu::create_texture_png(@textures/nine_slice.png, Rgba8Unorm, RenderAndSample, 'nine slices atlas')
        nine_slices_atlas_texture_view := wgpu::create_texture_view(nine_slices_atlas_texture, 'nine slices atlas view')

        nine_slice_sampler_config := wgpu::SamplerConfig {
            address_mode: ClampToEdge
            mag_filter: Linear
            min_filter: Linear
        }

        nine_slice_sampler:= wgpu::create_sampler(nine_slice_sampler_config, 'linear sampler for msdf atlas')

        nine_slice_corners := wgpu::create_vertex_buffer(NINE_SLICE_CORNERS, 'nine slice corners')
        nine_slice_indices := wgpu::create_index_buffer_u16(NINE_SLICE_INDICES, 'nine slice indices')
        nine_slice_instance_buffer := wgpu::create_buffer(256 * size_of::<NineSliceInstance>, Vertex, 'nine slice instance buffer')

        nine_slice_uniform := NineSliceUniform {
            view_proj: gm::Mat4::ortho_2d_pixel_near_far_int(512, 512, 0, 256).to_mat4f()
        }

        nine_slice_uniform_buffer := wgpu::create_uniform_buffer(nine_slice_uniform, 'nine slice uniform')

        nine_slice_uniform_bind_group_layout := wgpu::create_bind_group_layout([
            { binding: 0, ty: Buffer(Uniform) },
        ], 'nine slice uniform bind group layout')

        nine_slice_texture_bind_group_layout := wgpu::create_bind_group_layout([
            { binding: 0, ty: Texture },
            { binding: 1, ty: Sampler }
        ], 'nine slice texture bind group layout')

        nine_slice_uniform_bind_group := wgpu::create_bind_group(nine_slice_uniform_bind_group_layout, [
            Buffer(nine_slice_uniform_buffer),
        ], 'nine slice uniform bind group')

        nine_slice_texture_bind_group := wgpu::create_bind_group(nine_slice_texture_bind_group_layout, [
            TextureView(nine_slices_atlas_texture_view),
            Sampler(nine_slice_sampler)
        ], 'nine slice texture bind group')

        nine_slice_pipeline_layout := wgpu::create_pipeline_layout([nine_slice_uniform_bind_group_layout, nine_slice_texture_bind_group_layout], 'nine slice pipeline layout')

        // Slot 0: Grid Corner Index
        nine_slice_corner_layout := wgpu::VertexBufferLayout {
            array_stride: 4
            vertex_attribute: [
                wgpu::VertexAttribute {
                    offset: 0
                    location: 0
                    format: Uint32
                },
            ],
            vertex_attribute_count: 1
            step_mode: Vertex
        }

        // Slot 1: Nine Slice layout
        nine_slice_instance_layout := wgpu::VertexBufferLayout {
            array_stride: size_of::<NineSliceInstance>
            vertex_attribute: [
                wgpu::VertexAttribute {
                    offset: offset_of::<NineSliceInstance::target_position>
                    location: 1
                    format: Float32x2
                },
                wgpu::VertexAttribute {
                    offset: offset_of::<NineSliceInstance::screen_x>
                    location: 2
                    format: Float32x4
                },
                wgpu::VertexAttribute {
                    offset: offset_of::<NineSliceInstance::screen_y>
                    location: 3
                    format: Float32x4
                },
                wgpu::VertexAttribute {
                    offset: offset_of::<NineSliceInstance::uv_x>
                    location: 4
                    format: Float32x4
                },
                wgpu::VertexAttribute {
                    offset: offset_of::<NineSliceInstance::uv_y>
                    location: 5
                    format: Float32x4
                },
                wgpu::VertexAttribute {
                    offset: offset_of::<NineSliceInstance::tint>
                    location: 6
                    format: Float32x4
                },
                wgpu::VertexAttribute {
                    offset: offset_of::<NineSliceInstance::depth>
                    location: 7
                    format: Float32
                },
            ],
            vertex_attribute_count: 7
            step_mode: Instance
        }

        nine_slice_pipeline := wgpu::create_render_pipeline(
            nine_slice_pipeline_layout,
            [nine_slice_corner_layout, nine_slice_instance_layout],
            @shaders/nine_slice.wgsl,
            Alpha, None, false,
            'nine slice pipeline'
        )

        {
            nine_slices_atlas_texture: nine_slices_atlas_texture
            nine_slices_atlas_texture_view: nine_slices_atlas_texture_view

            nine_slice_corners: nine_slice_corners
            nine_slice_indices: nine_slice_indices
            nine_slice_instance_buffer: nine_slice_instance_buffer
            nine_slice_uniform_buffer: nine_slice_uniform_buffer
            nine_slice_uniform_bind_group_layout: nine_slice_uniform_bind_group_layout
            nine_slice_texture_bind_group_layout: nine_slice_texture_bind_group_layout
            nine_slice_uniform_bind_group: nine_slice_uniform_bind_group
            nine_slice_texture_bind_group: nine_slice_texture_bind_group
            nine_slice_pipeline_layout: nine_slice_pipeline_layout
            nine_slice_pipeline: nine_slice_pipeline
        }
    }


    #[host_call]
    fn render(mut self, sim: ExampleSimulation) {
        normalized_int_time := sim.time % 628
        normalized_float_time := (normalized_int_time.float() * 0.1)

        sway := normalized_float_time.cos()
        sway_alternate := normalized_float_time.sin()

        slow_sway := (normalized_float_time/4.0).cos()
        slow_sway_alternate := (normalized_float_time/4.0).sin()

        mut instances: Block<NineSliceInstance; 32>
        mut nine_slice_count = 0


        // --- CPU: build the 4x4 grids once per widget (shader only indexes them) ---
        target_position := Vec2f { x: 200.0 + slow_sway * 100.0, y: 200.0 + slow_sway_alternate * 150.0 }
        tw := 100.0 + sway * 20.0
        th := 120.0 + sway_alternate * 40.0
        border_left := 16.0
        border_top := 16.0
        border_right := 16.0
        border_bottom := 16.0
        atlas_w := 256.0
        atlas_h := 64.0
        atlas_left := 0.0
        atlas_top := 0.0
        atlas_right := 39.0
        atlas_bottom := 37.0

        instances[nine_slice_count] = NineSliceInstance {
            target_position: target_position
            screen_x: Vec4f { x: 0.0, y: border_left, z: tw - border_right, w: tw }
            screen_y: Vec4f { x: th, y: th - border_top, z: border_bottom, w: 0.0 }
            // TODO: this should be cached, doesn't change in runtime
            uv_x: Vec4f {
                x: atlas_left.div(atlas_w)
                y: (atlas_left + border_left).div(atlas_w)
                z: (atlas_right - border_right).div(atlas_w)
                w: atlas_right.div(atlas_w)
            }
            // TODO: this should be cached, doesn't change in runtime
            uv_y: Vec4f {
                x: atlas_top.div(atlas_h)
                y: (atlas_top + border_top).div(atlas_h)
                z: (atlas_bottom - border_bottom).div(atlas_h)
                w: atlas_bottom.div(atlas_h)
            }
            tint: Vec4f { x: 1.0, y: 1.0, z: 1.0, w: 1.0 }
            depth: -128.0
        }
        nine_slice_count += 1


        .nine_slice_instance_buffer.write(instances)

        // PASS: Render nine slice
        {
            mut render_pass: wgpu::RenderPass
            render_pass.depth_attachment = -1

            render_pass.set_pipeline(.nine_slice_pipeline)
            render_pass.set_bind_group( group_index: 0, bind_group: .nine_slice_uniform_bind_group )
            render_pass.set_bind_group( group_index: 1, bind_group: .nine_slice_texture_bind_group )
            render_pass.set_vertex_buffer( slot: 0, vertex_buffer: .nine_slice_corners )
            render_pass.set_vertex_buffer( slot: 1, vertex_buffer: .nine_slice_instance_buffer )
            render_pass.set_index_buffer( .nine_slice_indices )
            render_pass.draw_indexed( [0, 54], [0, nine_slice_count] ) // 16 vertices, 9 quads, 18 triangles

            wgpu::add_pass(render_pass, 'render nine slices to screen')
        }
    }

    #[host_call]
    fn resize(mut self) {
        
    }
}
