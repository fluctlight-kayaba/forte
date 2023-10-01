const std = @import("std");
const builtin = @import("builtin");
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

pub const FontWeight = enum {
    ExtraLight,
    Light,
    Regular,
    Medium,
    Bold,
    ExtraBold,
    Black,
};

pub const Font = struct {
    path: []const u8,
    name: []const u8,
    weight: FontWeight,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator, name: []const u8, uri: []const u8, weight: FontWeight) !Font {
        var path = try allocator.alloc(u8, uri.len + 1 + name.len);
        _ = try std.fmt.bufPrint(path, "{s}/{s}", .{ uri, name });

        return Font{
            .name = name,
            .path = path,
            .weight = weight,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Font) void {
        self.allocator.free(self.path);
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
            arr[0] = home_font_path;
            arr[1] = "/System/Library/Fonts";
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

const FontError = error{
    FontNotFound,
};

pub fn findFont(allocator: *std.mem.Allocator, font: anytype) !Font {
    var font_uri: ?[]const u8 = null;
    var font_name: []const u8 = undefined;
    var system_font_dirs = try allocFontDirectories(allocator);
    defer allocator.free(system_font_dirs);

    for (system_font_dirs) |uri| {
        var dir = try std.fs.openIterableDirAbsolute(uri, .{});
        var iterator = dir.iterate();

        while (try iterator.next()) |file| {
            if (helper.startsWith(file.name, font.name)) {
                font_uri = uri;
                font_name = font.name;
                break;
            }
        }

        if (font_uri == null) {
            defer allocator.free(uri);
        }
    }

    if (font_uri) |uri| {
        return Font.init(allocator, font_name, uri, .Medium);
    } else {
        return FontError.FontNotFound;
    }
}
