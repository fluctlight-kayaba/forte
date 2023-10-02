const std = @import("std");
const core = @import("mach-core");
const freetype = @import("mach-freetype");
const queue = @import("../utils/queue.zig");

const Size = core.Size;
const Font = @import("../config/font.zig").Font;
const GlyphCache = queue.AutoHashMap(u32, GlyphInfo, 100);

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
///   ├──────────────┐
///   │              │
///   │              │
///   │   (bitmap)   │
///   │              │
/// ──┼──────────────┼── (advanceWidth)
///   │    ↑         │
///   │ (brearingX)  │
///   │              │
///   └──────────────┘
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

    const InitOptions = struct {
        font: Font,
        size: u8 = 15,
    };

    size: u32,
    texture: [][]u8,
    font: Font,
    cache: GlyphCache,
    current_row: u32,
    row_baseline: u32,
    last_tallest_height: u32,
    row_remaining_width: u32,

    pub fn init(allocator: *std.mem.Allocator, options: InitOptions) !Self {
        var size = options.size;
        var texture = try allocator.alloc([]u8, size);
        errdefer allocator.free(texture);

        for (texture) |*row| {
            row.* = try allocator.alloc(u8, size);
            errdefer allocator.free(row.*);
        }

        return Self{
            .size = size,
            .texture = texture,
            .font = options.font,
            .cache = try GlyphCache.initCapacity(allocator, 2048),
            .current_row = 0,
            .row_baseline = 0,
            .last_tallest_height = 0,
            .row_remaining_width = size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.font.deinit();
    }

    fn getOrPutGlyph(self: *Self, char: u32) void {
        const cached = self.cache.getOrPut(char);
        const face = self.font.face;

        if (!cached.found_existing) {
            var glyph = GlyphInfo{
                .x = 0,
                .y = 0,
                .width = self.glyph_size.width,
                .height = self.glyph_size.height,
                .advanceWidth = 0,
                .bearingX = 0,
                .bearingY = self.glyph_size.height / 2,
            };

            if (self.row_remaining_width >= glyph.width) { // horizontally expandable
                glyph.x = self.row_remaining_width - glyph.width;
                glyph.y = self.row_baseline;
                self.row_remaining_width -= glyph.width;
            } else if (self.last_tallest_height + glyph.height <= self.size) { // vertically expandable
                glyph.x = 0;
                glyph.y = self.last_tallest_height;
                self.current_row += 1;
                self.row_remaining_width = self.size - glyph.width;
                self.row_baseline = self.last_tallest_height;
                self.last_tallest_height = glyph.height;
            } else if (self.cache.live.tail) |tail| { // atlas already full, un-expandable, replace tail "least-common" glyph
                glyph.x = tail.x;
                glyph.y = tail.y;
                self.cache.delete(tail);
            }

            try face.setPixelSizes(glyph.width, glyph.height);
            try face.loadGlyph(char, .{});
            try face.glyph().render(.normal);

            if (face.glyph().bitmap().buffer()) |buffer| {
                var x: u8 = 0;
                var y: u8 = 0;
                while (y <= self.glyph_size.height) : (y += 1) {
                    while (x <= self.glyph_size.width) : (x += 1) {
                        const pixel = buffer[y * self.glyph_size.width + x];
                        self.atlas.texture[glyph.y + y][glyph.x + x] = pixel;
                    }
                }
            }

            if (glyph.height > self.last_tallest_height) {
                self.last_tallest_height = glyph.height;
            }

            cached.node.value = glyph;
            self.cache.moveToFront(cached.node);
        }

        return cached.node.value;
    }

    pub fn getGlyph(self: *Self, char: u32) ?*GlyphInfo {
        return self.cache.get(char).?.value;
    }
};
