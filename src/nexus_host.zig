const std = @import("std");
const async_runtime = @import("async_runtime.zig");

/// Host function context containing runtime state
pub const HostContext = struct {
    allocator: std.mem.Allocator,
    promise_registry: *async_runtime.PromiseRegistry,
    wasm_memory: *async_runtime.WasmMemory,

    pub fn init(
        allocator: std.mem.Allocator,
        promise_registry: *async_runtime.PromiseRegistry,
        wasm_memory: *async_runtime.WasmMemory,
    ) HostContext {
        return .{
            .allocator = allocator,
            .promise_registry = promise_registry,
            .wasm_memory = wasm_memory,
        };
    }
};

/// HTTP Response structure
pub const HttpResponse = struct {
    status: i32,
    body: []const u8,
    headers: std.StringHashMap([]const u8),

    pub fn deinit(self: *HttpResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        self.headers.deinit();
    }
};

/// Host function: HTTP GET
/// Returns a promise ID
pub fn httpGet(ctx: *HostContext, url_ptr: u32, url_len: u32) !u32 {
    // Read URL from WASM memory
    const url = try ctx.wasm_memory.read(url_ptr, url_len);

    // Create a promise for this async operation
    const promise_id = try ctx.promise_registry.create();

    // In a real implementation, this would:
    // 1. Create an async HTTP request using Nexus runtime
    // 2. Register callback to resolve/reject promise when complete
    // 3. Return immediately with promise ID

    // For now, simulate an immediate successful response
    std.debug.print("[HOST] HTTP GET: {s}\n", .{url});

    // Simulate a response
    const response_body = "{{\"status\":\"ok\"}}";
    const response_ptr = try ctx.wasm_memory.write(1024, response_body);

    // Resolve the promise immediately (in real impl, this happens async)
    try ctx.promise_registry.resolve(promise_id, response_ptr);

    return promise_id;
}

/// Host function: HTTP POST
pub fn httpPost(ctx: *HostContext, url_ptr: u32, url_len: u32, body_ptr: u32, body_len: u32) !u32 {
    const url = try ctx.wasm_memory.read(url_ptr, url_len);
    const body = try ctx.wasm_memory.read(body_ptr, body_len);

    const promise_id = try ctx.promise_registry.create();

    std.debug.print("[HOST] HTTP POST: {s}, body: {s}\n", .{ url, body });

    // Simulate success
    const response_ptr = try ctx.wasm_memory.write(2048, "{{\"created\":true}}");
    try ctx.promise_registry.resolve(promise_id, response_ptr);

    return promise_id;
}

/// Host function: Read file
pub fn fsReadFile(ctx: *HostContext, path_ptr: u32, path_len: u32) !u32 {
    const path = try ctx.wasm_memory.read(path_ptr, path_len);

    const promise_id = try ctx.promise_registry.create();

    std.debug.print("[HOST] FS Read: {s}\n", .{path});

    // In real implementation, read file asynchronously
    // For now, simulate with dummy content
    const file_content = "file contents here";
    const content_ptr = try ctx.wasm_memory.write(3072, file_content);

    try ctx.promise_registry.resolve(promise_id, content_ptr);

    return promise_id;
}

/// Host function: Write file
pub fn fsWriteFile(ctx: *HostContext, path_ptr: u32, path_len: u32, content_ptr: u32, content_len: u32) !u32 {
    const path = try ctx.wasm_memory.read(path_ptr, path_len);
    const content = try ctx.wasm_memory.read(content_ptr, content_len);

    const promise_id = try ctx.promise_registry.create();

    std.debug.print("[HOST] FS Write: {s}, size: {d}\n", .{ path, content.len });

    // Simulate success
    try ctx.promise_registry.resolve(promise_id, 0);

    return promise_id;
}

/// Host function: Set timeout
pub fn setTimeout(ctx: *HostContext, delay_ms: u32) !u32 {
    const promise_id = try ctx.promise_registry.create();

    std.debug.print("[HOST] Timer: delay {d}ms\n", .{delay_ms});

    // In real implementation, schedule callback after delay
    // For now, resolve immediately
    try ctx.promise_registry.resolve(promise_id, 0);

    return promise_id;
}

/// Host function: Console.log
pub fn consoleLog(ctx: *HostContext, msg_ptr: u32, msg_len: u32) !void {
    const msg = try ctx.wasm_memory.read(msg_ptr, msg_len);
    std.debug.print("[CONSOLE] {s}\n", .{msg});
}

/// Host function: Promise.await - poll a promise until resolved
pub fn promiseAwait(ctx: *HostContext, promise_id: u32) !u32 {
    const promise = ctx.promise_registry.get(promise_id) orelse return error.InvalidPromiseId;

    return switch (promise.state) {
        .resolved => promise.result_ptr orelse 0,
        .rejected => error.PromiseRejected,
        .pending => {
            // In a real async implementation, this would suspend and resume when ready
            // For now, just return 0 (placeholder)
            std.debug.print("[HOST] Promise {d} still pending\n", .{promise_id});
            return 0;
        },
    };
}

/// Registry of all host functions
pub const HostFunctions = struct {
    /// Get the WASM import string for all host functions
    pub fn getImports(allocator: std.mem.Allocator) ![]const u8 {
        _ = allocator;
        return
            \\  ;; Nexus host function imports
            \\  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
            \\  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
            \\  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
            \\  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
            \\  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
            \\  (import "nexus" "console_log" (func $nexus_console_log (param i32 i32)))
            \\  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))
        ;
    }
};

test "httpGet creates promise" {
    const allocator = std.testing.allocator;
    var registry = async_runtime.PromiseRegistry.init(allocator);
    defer registry.deinit();

    var memory = try async_runtime.WasmMemory.init(allocator, 1);
    defer memory.deinit();

    var ctx = HostContext.init(allocator, &registry, &memory);

    // Write URL to memory
    const url = "https://api.example.com/users";
    const url_ptr = try memory.write(0, url);

    // Call httpGet
    const promise_id = try httpGet(&ctx, url_ptr, @intCast(url.len));

    // Verify promise was created and resolved
    const promise = registry.get(promise_id).?;
    try std.testing.expect(promise.state == .resolved);
}
