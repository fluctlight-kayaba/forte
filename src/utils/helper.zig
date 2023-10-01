const std = @import("std");

pub fn startsWith(first: []const u8, second: []const u8) bool {
    if (second.len > first.len) return false;
    return std.mem.eql(u8, first[0..second.len], second);
}
