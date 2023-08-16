const std = @import("std");
const dusk = @import("mach-dusk");
const core = @import("core");
const gpu = core.gpu;

pub const App = struct {
    pipeline: *gpu.RenderPipeline,
    queue: *gpu.Queue,

    pub const GPUInterface = dusk.Interface;

    pub fn init(app: *App) !void {
        try core.init(.{});

        const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));

        // Fragment state
        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };
        const fragment = gpu.FragmentState.init(.{
            .module = shader_module,
            .entry_point = "fragment_main",
            .targets = &.{color_target},
        });
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
            .fragment = &fragment,
            .vertex = gpu.VertexState{
                .module = shader_module,
                .entry_point = "vertex_main",
            },
        };

        app.pipeline = core.device.createRenderPipeline(&pipeline_descriptor);
        app.queue = core.device.getQueue();

        shader_module.release();
    }

    pub fn deinit(app: *App) void {
        core.deinit();
        _ = app;
    }

    pub fn update(app: *App) !bool {
        var iter = core.pollEvents();
        while (iter.next()) |event| {
            switch (event) {
                .close => return true,
                else => {},
            }
        }

        const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
        const color_attachment = gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        };

        const encoder = core.device.createCommandEncoder(null);
        const render_pass_info = gpu.RenderPassDescriptor.init(.{
            .color_attachments = &.{color_attachment},
        });
        const pass = encoder.beginRenderPass(&render_pass_info);
        pass.setPipeline(app.pipeline);
        pass.draw(3, 1, 0, 0);
        pass.end();
        pass.release();

        var command = encoder.finish(null);
        encoder.release();

        app.queue.submit(&[_]*gpu.CommandBuffer{command});
        command.release();
        core.swap_chain.present();
        back_buffer_view.release();

        return false;
    }
};