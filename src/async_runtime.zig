const std = @import("std");

/// Promise ID type for tracking async operations
pub const PromiseId = u32;

/// Promise state
pub const PromiseState = enum {
    pending,
    resolved,
    rejected,
};

/// Promise data structure
pub const Promise = struct {
    id: PromiseId,
    state: PromiseState,
    result_ptr: ?u32, // Pointer to result in WASM memory
    error_ptr: ?u32, // Pointer to error in WASM memory
};

/// Promise registry for tracking all pending async operations
pub const PromiseRegistry = struct {
    allocator: std.mem.Allocator,
    promises: std.AutoHashMap(PromiseId, Promise),
    next_id: PromiseId,

    pub fn init(allocator: std.mem.Allocator) PromiseRegistry {
        return .{
            .allocator = allocator,
            .promises = std.AutoHashMap(PromiseId, Promise).init(allocator),
            .next_id = 1,
        };
    }

    pub fn deinit(self: *PromiseRegistry) void {
        self.promises.deinit();
    }

    /// Create a new promise and return its ID
    pub fn create(self: *PromiseRegistry) !PromiseId {
        const id = self.next_id;
        self.next_id += 1;

        try self.promises.put(id, .{
            .id = id,
            .state = .pending,
            .result_ptr = null,
            .error_ptr = null,
        });

        return id;
    }

    /// Resolve a promise with a result
    pub fn resolve(self: *PromiseRegistry, id: PromiseId, result_ptr: u32) !void {
        if (self.promises.getPtr(id)) |promise| {
            promise.state = .resolved;
            promise.result_ptr = result_ptr;
        } else {
            return error.InvalidPromiseId;
        }
    }

    /// Reject a promise with an error
    pub fn reject(self: *PromiseRegistry, id: PromiseId, error_ptr: u32) !void {
        if (self.promises.getPtr(id)) |promise| {
            promise.state = .rejected;
            promise.error_ptr = error_ptr;
        } else {
            return error.InvalidPromiseId;
        }
    }

    /// Get a promise by ID
    pub fn get(self: *PromiseRegistry, id: PromiseId) ?Promise {
        return self.promises.get(id);
    }

    /// Remove a promise from the registry
    pub fn remove(self: *PromiseRegistry, id: PromiseId) bool {
        return self.promises.remove(id);
    }

    /// Check if a promise is pending
    pub fn isPending(self: *PromiseRegistry, id: PromiseId) bool {
        if (self.promises.get(id)) |promise| {
            return promise.state == .pending;
        }
        return false;
    }
};

/// WASM memory interface
pub const WasmMemory = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, initial_pages: u32) !WasmMemory {
        const page_size = 65536; // 64KB per WASM page
        const size = initial_pages * page_size;
        const data = try allocator.alloc(u8, size);

        return .{
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WasmMemory) void {
        self.allocator.free(self.data);
    }

    /// Write bytes to WASM memory and return the pointer
    pub fn write(self: *WasmMemory, offset: usize, bytes: []const u8) !u32 {
        if (offset + bytes.len > self.data.len) {
            return error.OutOfMemory;
        }

        @memcpy(self.data[offset .. offset + bytes.len], bytes);
        return @intCast(offset);
    }

    /// Read bytes from WASM memory
    pub fn read(self: *WasmMemory, offset: usize, len: usize) ![]const u8 {
        if (offset + len > self.data.len) {
            return error.OutOfBounds;
        }

        return self.data[offset .. offset + len];
    }

    /// Allocate space in WASM memory (simple bump allocator)
    pub fn alloc(self: *WasmMemory, size: usize) !u32 {
        // TODO: Implement proper memory management
        // For now, this is a placeholder
        _ = self;
        _ = size;
        return 0;
    }
};

/// Async task for event loop integration
pub const AsyncTask = struct {
    promise_id: PromiseId,
    callback: *const fn (promise_id: PromiseId) void,
};

test "PromiseRegistry basic operations" {
    const allocator = std.testing.allocator;
    var registry = PromiseRegistry.init(allocator);
    defer registry.deinit();

    // Create a promise
    const id = try registry.create();
    try std.testing.expect(id == 1);
    try std.testing.expect(registry.isPending(id));

    // Resolve it
    try registry.resolve(id, 42);
    const promise = registry.get(id).?;
    try std.testing.expect(promise.state == .resolved);
    try std.testing.expect(promise.result_ptr.? == 42);

    // Create and reject another
    const id2 = try registry.create();
    try registry.reject(id2, 100);
    const promise2 = registry.get(id2).?;
    try std.testing.expect(promise2.state == .rejected);
    try std.testing.expect(promise2.error_ptr.? == 100);
}

test "WasmMemory write and read" {
    const allocator = std.testing.allocator;
    var memory = try WasmMemory.init(allocator, 1);
    defer memory.deinit();

    const data = "Hello, WASM!";
    const ptr = try memory.write(0, data);
    try std.testing.expect(ptr == 0);

    const read_data = try memory.read(0, data.len);
    try std.testing.expectEqualStrings(data, read_data);
}
