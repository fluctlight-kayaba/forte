const std = @import("std");

const Color = struct {
    const Self = @This();

    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn fromU32(color: u32) Self {
        return Self{
            .r = @as(u8, @intCast(color >> 24)),
            .g = @as(u8, @intCast((color >> 16) & 0xFF)),
            .b = @as(u8, @intCast((color >> 8) & 0xFF)),
            .a = @as(u8, @intCast(color & 0xFF)),
        };
    }

    pub fn asU32(self: *Self) u32 {
        return @as(u32, @intCast(self.r)) << 24 | @as(u32, @intCast(self.g)) << 16 | @as(u32, @intCast(self.b)) << 8 | @as(u32, @intCast(self.a));
    }
};

///  (bearingY)
///   │
///   ├───────────────┐
///   │               │
///   │               │
///   │   (bitmap)    │
///   │               │
/// ──┼───────────────┼── (advanceWidth)
///   │    ↑          │
///   │ (brearingX)   │
///   │               │
///   └───────────────┘
pub const GlyphInfo = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    advanceWidth: f32,
    bearingX: f32,
    bearingY: f32,
};

/// Manages a single texture atlas.
///
/// The strategy for filling an atlas looks roughly like this:
///
/// ```text
///                           (width, height)
///   ┌─────┬─────┬─────┬─────┬─────┐
///   │ 10  │     │     │     │     │ <- Empty spaces; can be filled while
///   │     │     │     │     │     │    glyph_height < height - row_baseline
///   ├─────┼─────┼─────┼─────┼─────┤
///   │ 5   │ 6   │ 7   │ 8   │ 9   │
///   │     │     │     │     │     │
///   ├─────┼─────┼─────┼─────┴─────┤ <- Row height is tallest glyph in row; this is
///   │ 1   │ 2   │ 3   │ 4         │    used as the baseline for the following row.
///   │     │     │     │           │ <- Row considered full when next glyph doesn't
///   └─────┴─────┴─────┴───────────┘    fit in the row.
/// (0, 0)  x->
/// ```
pub const Atlas = struct {
    const Self = @This();

    texture: [][]Color,
    glyphs: std.HashMap(u32, GlyphInfo),

    pub fn init(allocator: *std.mem.Allocator, width: usize, height: usize) Self {
        var texture = try allocator.alloc([]Color, height);
        errdefer allocator.free(texture);

        for (texture) |*row| {
            row.* = try allocator.alloc(Color, width);
            errdefer allocator.free(row.*);
        }

        var glyphs = std.HashMap(u32, GlyphInfo).init(allocator);

        return Self{
            .texture = texture,
            .glyphs = glyphs,
        };
    }

    pub fn addGlyph(self: *Self, codePoint: u32, glyphInfo: GlyphInfo) void {
        _ = self.glyphs.put(codePoint, glyphInfo) catch unreachable;
    }

    pub fn getGlyph(self: *Self, codePoint: u32) GlyphInfo {
        return self.glyphs.get(codePoint) orelse unreachable;
    }
};
