const std = @import("std");

// Standard library host functions that will be provided by the runtime (Nexus/browser)
// These are imported from the host environment when running as WASM

pub const Console = struct {
    pub fn log(message: []const u8) void {
        std.debug.print("{s}\n", .{message});
    }

    pub fn error_(message: []const u8) void {
        std.debug.print("ERROR: {s}\n", .{message});
    }

    pub fn warn(message: []const u8) void {
        std.debug.print("WARN: {s}\n", .{message});
    }

    pub fn info(message: []const u8) void {
        std.debug.print("INFO: {s}\n", .{message});
    }
};

pub const Env = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Env {
        return .{ .allocator = allocator };
    }

    pub fn get(self: *Env, key: []const u8) !?[]const u8 {
        // Note: In WASM environment, env vars are typically provided by the host.
        // This placeholder returns null. Real implementation would query host.
        _ = self;
        _ = key;
        return null;
    }

    pub fn set(self: *Env, key: []const u8, value: []const u8) !void {
        _ = self;
        _ = key;
        _ = value;
        // Note: WASM environment typically doesn't allow setting env vars
        // This would need to be implemented by the host
        return error.Unsupported;
    }
};

// Result type for error handling
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        pub fn isOk(self: @This()) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }

        pub fn isErr(self: @This()) bool {
            return !self.isOk();
        }

        pub fn unwrap(self: @This()) T {
            return switch (self) {
                .ok => |value| value,
                .err => @panic("Called unwrap on an error Result"),
            };
        }

        pub fn unwrapErr(self: @This()) E {
            return switch (self) {
                .err => |e| e,
                .ok => @panic("Called unwrapErr on an ok Result"),
            };
        }

        pub fn unwrapOr(self: @This(), default: T) T {
            return switch (self) {
                .ok => |value| value,
                .err => default,
            };
        }
    };
}

// Optional/Maybe type
pub fn Optional(comptime T: type) type {
    return ?T;
}

// Array/List collection
pub fn List(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = std.ArrayList(T).empty,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        pub fn append(self: *Self, item: T) !void {
            try self.items.append(self.allocator, item);
        }

        pub fn get(self: *Self, index: usize) ?T {
            if (index >= self.items.items.len) return null;
            return self.items.items[index];
        }

        pub fn len(self: *Self) usize {
            return self.items.items.len;
        }

        pub fn pop(self: *Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.pop();
        }

        pub fn clear(self: *Self) void {
            self.items.clearRetainingCapacity();
        }
    };
}

// Map/HashMap collection
pub fn Map(comptime K: type, comptime V: type) type {
    return struct {
        inner: std.StringHashMap(V),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .inner = std.StringHashMap(V).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            try self.inner.put(key, value);
        }

        pub fn get(self: *Self, key: K) ?V {
            return self.inner.get(key);
        }

        pub fn contains(self: *Self, key: K) bool {
            return self.inner.contains(key);
        }

        pub fn remove(self: *Self, key: K) bool {
            return self.inner.remove(key);
        }

        pub fn count(self: *Self) usize {
            return self.inner.count();
        }

        pub fn clear(self: *Self) void {
            self.inner.clearRetainingCapacity();
        }
    };
}

// String utilities
pub const String = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) String {
        return .{
            .buffer = std.ArrayList(u8).empty,
            .allocator = allocator,
        };
    }

    pub fn fromSlice(allocator: std.mem.Allocator, bytes: []const u8) !String {
        var s = String.init(allocator);
        try s.buffer.appendSlice(allocator, bytes);
        return s;
    }

    pub fn deinit(self: *String) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn append(self: *String, other: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, other);
    }

    pub fn len(self: *const String) usize {
        return self.buffer.items.len;
    }

    pub fn slice(self: *const String) []const u8 {
        return self.buffer.items;
    }

    pub fn clone(self: *const String) !String {
        return String.fromSlice(self.allocator, self.buffer.items);
    }

    pub fn clear(self: *String) void {
        self.buffer.clearRetainingCapacity();
    }

    pub fn eql(self: *const String, other: []const u8) bool {
        return std.mem.eql(u8, self.buffer.items, other);
    }
};

// WASM host interface definitions
// These will be imported from the host environment

pub const WasmImports = struct {
    // Console functions (imported from host)
    extern "env" fn js_console_log(ptr: [*]const u8, len: usize) void;
    extern "env" fn js_console_error(ptr: [*]const u8, len: usize) void;
    extern "env" fn js_console_warn(ptr: [*]const u8, len: usize) void;
    extern "env" fn js_console_info(ptr: [*]const u8, len: usize) void;

    // Environment functions (imported from host)
    extern "env" fn js_env_get(key_ptr: [*]const u8, key_len: usize, value_ptr: [*]u8, value_len: usize) i32;
};

// Test the stdlib
test "Result type" {
    const IntResult = Result(i32, []const u8);

    const ok_result = IntResult{ .ok = 42 };
    try std.testing.expect(ok_result.isOk());
    try std.testing.expectEqual(@as(i32, 42), ok_result.unwrap());

    const err_result = IntResult{ .err = "error message" };
    try std.testing.expect(err_result.isErr());
    try std.testing.expectEqualStrings("error message", err_result.unwrapErr());
}

test "List collection" {
    const allocator = std.testing.allocator;
    var list = List(i32).init(allocator);
    defer list.deinit();

    try list.append(10);
    try list.append(20);
    try list.append(30);

    try std.testing.expectEqual(@as(usize, 3), list.len());
    try std.testing.expectEqual(@as(i32, 10), list.get(0).?);
    try std.testing.expectEqual(@as(i32, 30), list.pop().?);
}

test "String utilities" {
    const allocator = std.testing.allocator;
    var str = String.init(allocator);
    defer str.deinit();

    try str.append("Hello");
    try str.append(" ");
    try str.append("World");

    try std.testing.expectEqual(@as(usize, 11), str.len());
    try std.testing.expect(str.eql("Hello World"));
}
