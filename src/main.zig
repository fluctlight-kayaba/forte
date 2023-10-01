const std = @import("std");
const core = @import("mach-core");
const freetype = @import("mach-freetype");
const font = @import("config/font.zig");
const gpu = core.gpu;

pub const App = @This();

title_timer: core.Timer,
pipeline: *gpu.RenderPipeline,

const OutlinePrinter = struct {
    library: freetype.library,
    face: freetype.Face,
    font_size: f32,
};

pub fn init(app: *App) !void {
    try core.init(.{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    var ft = try font.findFont(&allocator, .{ .name = "OperatorMonoNerdFontMono-Medium" });
    defer ft.deinit();

    const font_file = try std.fs.openFileAbsolute(ft.path, .{});
    defer font_file.close();
    var font_buffer = try allocator.alloc(u8, try font_file.getEndPos());
    defer allocator.free(font_buffer);
    _ = try font_file.readAll(font_buffer);

    std.debug.print("font: {s}\n", .{ft.path});
    std.debug.print("First 10 bytes of the TTF file: ", .{});
    for (font_buffer[0..10]) |byte| {
        std.debug.print("{x} ", .{byte});
    }
    std.debug.print("\n", .{});

    var lib = try freetype.Library.init();
    var font_face = try lib.createFaceMemory(font_buffer, 0);
    std.debug.print("font face: {any}\n", .{font_face});

    const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });
    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_main",
        },
    };
    const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

    app.* = .{ .title_timer = try core.Timer.start(), .pipeline = pipeline };
}

pub fn deinit(app: *App) void {
    defer core.deinit();
    app.pipeline.release();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .close => return true,
            else => {},
        }
    }

    const queue = core.queue;
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

    queue.submit(&[_]*gpu.CommandBuffer{command});
    command.release();
    core.swap_chain.present();
    back_buffer_view.release();

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Triangle [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}
