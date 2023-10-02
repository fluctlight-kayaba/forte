const std = @import("std");
const core = @import("mach-core");
const freetype = @import("mach-freetype");

const Size = core.Size;

pub const Cell = struct {
    char: u8,
    foreground: u32,
    background: u32,
};

pub fn computeFontCellSize(face: freetype.Face) Size {
    return Size{
        .width = pixelFromI16(face.maxAdvanceWidth()),
        .height = pixelFromI16(face.maxAdvanceHeight()),
    };
}

pub fn pixelFromI16(value: i16) u32 {
    return @as(u32, @intCast(value)) / 64;
}
