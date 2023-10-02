const std = @import("std");
const builtin = @import("builtin");
const freetype = @import("mach-freetype");
const helper = @import("../utils/helper.zig");

pub fn FontDelta(comptime T: type) type {
    return struct {
        const Self = @This();
        x: T,
        y: T,

        pub fn default() Self(T) {
            return Self(T){ .x = T(0), .y = T(0) };
        }
    };
}

pub const FontError = error{
    FontNotFound,
};

pub const Font = struct {
    const Self = @This();

    const Weight = enum {
        ExtraLight,
        Light,
        Regular,
        Medium,
        Bold,
        ExtraBold,
        Black,
    };

    const InitOptions = struct {
        name: []const u8,
        weight: ?Weight = null,
    };

    path: []const u8,
    name: []const u8,
    file: std.fs.File,
    file_buffer: []u8,
    face: freetype.Face,
    weight: Weight,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator, options: InitOptions) !Self {
        var system_font_dirs = try allocFontDirectories(allocator);
        defer allocator.free(system_font_dirs);

        for (system_font_dirs) |uri| {
            var opern_dir = try std.fs.openIterableDirAbsolute(uri, .{});
            var iterator = opern_dir.iterate();

            while (try iterator.next()) |dir| {
                if (helper.startsWith(dir.name, options.name)) {
                    var path = try allocator.alloc(u8, uri.len + 1 + dir.name.len);
                    _ = try std.fmt.bufPrint(path, "{s}/{s}", .{ uri, dir.name });
                    const file = try std.fs.openFileAbsolute(path, .{});
                    var buffer = try allocator.alloc(u8, try file.getEndPos());
                    _ = try file.readAll(buffer);
                    var lib = try freetype.Library.init();
                    var face = try lib.createFaceMemory(buffer, 0);

                    return Self{
                        .name = options.name,
                        .path = path,
                        .file = file,
                        .file_buffer = buffer,
                        .face = face,
                        .weight = options.weight orelse Weight.Regular,
                        .allocator = allocator,
                    };
                }
            }
        }

        return FontError.FontNotFound;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.path);
        self.allocator.free(self.file_buffer);
        self.file.close();
    }
};

pub fn allocFontDirectories(allocator: *std.mem.Allocator) ![][]const u8 {
    comptime var os = builtin.os.tag;
    const home = std.os.getenv("HOME") orelse unreachable;
    var arr: [][]const u8 = undefined;

    switch (os) {
        .macos, .ios => {
            var home_font_path = try allocator.alloc(u8, home.len + "/Library/Fonts".len);
            _ = try std.fmt.bufPrint(home_font_path, "{s}/Library/Fonts", .{home});
            arr = try allocator.alloc([]const u8, 2);
            arr[0] = "/System/Library/Fonts";
            arr[1] = home_font_path;
        },
        .linux => {
            arr = try allocator.alloc([]const u8, 1);
            arr[0] = "/usr/share/fonts";
        },
        .windows => {
            arr = try allocator.alloc([]const u8, 1);
            arr[0] = "C:\\Windows\\Fonts";
        },
        else => unreachable,
    }

    return arr;
}
