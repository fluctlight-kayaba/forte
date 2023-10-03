const std = @import("std");

const LinkedList = std.SinglyLinkedList;

pub fn LRUCache(
    comptime K: type,
    comptime V: type,
) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            key: K = undefined,
            value: V = undefined,
        };

        pub const GetOrPutResult = struct {
            node: ?Node = undefined,
            found: bool,
        };

        list: LinkedList(Node),
        map: std.AutoHashMap(K, *LinkedList(Node).Node),
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator) !LRUCache(K, V) {
            return LRUCache(K, V){
                .allocator = allocator,
                .list = LinkedList(Node){},
                .map = std.AutoHashMap(K, *LinkedList(Node).Node).init(allocator.*),
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn getOrPut(self: *Self, key: K) GetOrPutResult {
            var result = GetOrPutResult{ .found = false };

            if (self.map.get(key)) |linked| {
                result.found = true;
                result.node = linked.data;
            } else {
                var node = LinkedList(Node).Node{ .data = .{ .key = key, .value = undefined } };
                self.list.prepend(&node);
                try self.map.put(key, &node);
            }

            return result;
        }
    };
}

test "LRUCache: essential cases" {
    var allocator = std.testing.allocator;
    const Cache = LRUCache(usize, usize);
    var map = try Cache.init(&allocator);
    defer map.deinit();

    var result = map.getOrPut(10);
    try std.testing.expectEqual(false, result.found);

    var result_after = map.getOrPut(10);
    try std.testing.expectEqual(true, result_after.found);
}
