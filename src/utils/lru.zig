const std = @import("std");

const LinkedList = std.SinglyLinkedList;
const mem = std.mem;
const testing = std.testing;

pub fn LRUCache(
    comptime K: type,
    comptime V: type,
) type {
    return struct {
        const Self = @This();

        pub const Entry = struct {
            key: K = undefined,
            value: V = undefined,
        };

        pub const GetOrPutResult = struct {
            node: ?LinkedList(Entry).Node = undefined,
            found: bool,
        };

        list: LinkedList(Entry),
        map: std.AutoHashMap(K, *LinkedList(Entry).Node),
        allocator: *std.mem.Allocator,

        pub fn init(allocator: *std.mem.Allocator) !LRUCache(K, V) {
            return LRUCache(K, V){
                .allocator = allocator,
                .list = LinkedList(Entry){},
                .map = std.AutoHashMap(K, *LinkedList(Entry).Node).init(allocator.*),
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn getOrPut(self: *Self, key: K) !GetOrPutResult {
            var result = GetOrPutResult{ .found = false };

            if (self.map.get(key)) |linked| {
                result.found = true;
                result.node = linked.*;
            } else {
                var node = LinkedList(Entry).Node{ .data = undefined };
                self.list.prepend(&node);
                try self.map.put(key, &node);
            }

            return result;
        }
    };
}

test "LRUCache: essential cases" {
    var allocator = testing.allocator;
    var lru = try LRUCache(u32, u32).init(&allocator);
    defer lru.deinit();

    var result = try lru.getOrPut(10);
    try std.testing.expectEqual(false, result.found);

    var result_after = try lru.getOrPut(10);
    try std.testing.expectEqual(true, result_after.found);
}
