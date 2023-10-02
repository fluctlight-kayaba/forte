const std = @import("std");
const core = @import("mach-core");

const Size = core.Size;

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

    size: u32,
    texture: [][]Color,
    glyphs: std.HashMap(u32, GlyphInfo),
    current_row: u32,
    row_baseline: u32,
    last_tallest_height: u32,
    row_remaining_width: u32,

    pub fn init(allocator: *std.mem.Allocator, size: u32) Self {
        var texture = try allocator.alloc([]Color, size);
        errdefer allocator.free(texture);

        for (texture) |*row| {
            row.* = try allocator.alloc(Color, size);
            errdefer allocator.free(row.*);
        }

        var glyphs = std.HashMap(u32, GlyphInfo).init(allocator);

        return Self{
            .size = size,
            .texture = texture,
            .glyphs = glyphs,
            .current_row = 0,
            .row_baseline = 0,
            .row_tallest_height = 0,
            .row_remaining_width = size,
        };
    }

    pub fn addGlyph(self: *Self, codePoint: u32, glyphInfo: GlyphInfo) void {
        if (self.row_remaining_width >= glyphInfo.width) {
            glyphInfo.x = self.row_remaining_width - glyphInfo.width;
            glyphInfo.y = self.row_baseline;
            _ = self.glyphs.put(codePoint, glyphInfo) catch unreachable;
            self.row_remaining_width -= glyphInfo.width;
        } else {
            glyphInfo.x = 0;
            glyphInfo.y = self.last_tallest_height;
            self.current_row += 1;
            self.row_remaining_width = self.size - glyphInfo.width;
            self.row_baseline = self.last_tallest_height;
            self.last_tallest_height = glyphInfo.height;
        }

        if (glyphInfo.height > self.last_tallest_height) {
            self.last_tallest_height = glyphInfo.height;
        }
    }

    pub fn getGlyph(self: *Self, codePoint: u32) GlyphInfo {
        return self.glyphs.get(codePoint) orelse unreachable;
    }
};
