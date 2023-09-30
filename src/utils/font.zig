const std = @import("std");
const builtin = @import("builtin");

pub fn Delta(comptime T: type) type {
    return struct {
        x: T,
        y: T,

        pub fn default() Delta(T) {
            return Delta(T){ .x = T(0), .y = T(0) };
        }
    };
}

pub fn allocFontDirectories(allocator: *std.mem.Allocator) ![][]const u8 {
    comptime var os = builtin.os.tag;
    var arr: [][]const u8 = undefined;

    switch (os) {
        .macos, .ios => {
            arr = try allocator.alloc([]const u8, 2);
            arr[0] = "/System/Library/Fonts";
            arr[1] = "~/Library/Fonts";
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
