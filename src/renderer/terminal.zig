const std = @import("std");
const core = @import("mach-core");
const primitive = @import("primitive.zig");

const Cell = primitive.Cell;
const Size = core.Size;

pub const Grid = struct {
    const Self = @This();

    rows: usize,
    cols: usize,
    cells: [][]Cell,
    window_size: Size,
    cell_size: Size,
    cursor_x: usize,
    cursor_y: usize,

    pub fn init(allocator: *std.mem.Allocator, window_size: Size, cell_size: Size) !Self {
        const cols = @divFloor(window_size.width, cell_size.width);
        const rows = @divFloor(window_size.height, cell_size.height);
        var cells = try allocator.alloc([]Cell, rows);
        errdefer allocator.free(cells);

        for (cells) |*row| {
            row.* = try allocator.alloc(Cell, cols);
            errdefer allocator.free(row.*);
        }

        return Self{
            .rows = rows,
            .cols = cols,
            .cells = cells,
            .window_size = window_size,
            .cell_size = cell_size,
            .cursor_x = 0,
            .cursor_y = 0,
        };
    }

    pub fn render(self: *Self) void {
        _ = self;
    }

    pub fn input_char(self: *Self, char: u8) void {
        const cell = Cell{
            .char = char,
            .foreground = 0xFFFFFFFF,
            .background = 0x00000000,
        };

        self.cells[self.cursor_x][self.cursor_y] = cell;
        self.move_cursor(1, 0);
    }

    pub fn move_cursor(self: *Self, dx: isize, dy: isize) void {
        if (dx >= 0) {
            self.cursor_x = @min(self.cursor_x + @as(usize, @intCast(dx)), self.cols - 1);
        } else {
            self.cursor_x = @max(self.cursor_x - @as(usize, @intCast(-dx)), 0);
        }

        if (dy >= 0) {
            self.cursor_y = @min(self.cursor_y + @as(usize, @intCast(dy)), self.rows - 1);
        } else {
            self.cursor_y = @max(self.cursor_y - @as(usize, @intCast(-dy)), 0);
        }
    }
};
