const std = @import("std");
const json = @import("json.zig");

/// Built-in modules that can be imported in ZigScript code
pub const BuiltinModule = struct {
    name: []const u8,
    exports: []const Export,

    pub const Export = struct {
        name: []const u8,
        kind: ExportKind,
    };

    pub const ExportKind = enum {
        function,
        type,
        constant,
    };
};

/// List of all built-in modules
pub const builtin_modules = [_]BuiltinModule{
    .{
        .name = "std/json",
        .exports = &[_]BuiltinModule.Export{
            .{ .name = "decode", .kind = .function },
            .{ .name = "encode", .kind = .function },
            .{ .name = "JsonValue", .kind = .type },
        },
    },
    .{
        .name = "std/http",
        .exports = &[_]BuiltinModule.Export{
            .{ .name = "get", .kind = .function },
            .{ .name = "post", .kind = .function },
            .{ .name = "put", .kind = .function },
            .{ .name = "delete", .kind = .function },
            .{ .name = "Response", .kind = .type },
        },
    },
    .{
        .name = "std/fs",
        .exports = &[_]BuiltinModule.Export{
            .{ .name = "readFile", .kind = .function },
            .{ .name = "writeFile", .kind = .function },
            .{ .name = "appendFile", .kind = .function },
            .{ .name = "deleteFile", .kind = .function },
            .{ .name = "exists", .kind = .function },
        },
    },
    .{
        .name = "std/time",
        .exports = &[_]BuiltinModule.Export{
            .{ .name = "setTimeout", .kind = .function },
            .{ .name = "setInterval", .kind = .function },
            .{ .name = "clearTimeout", .kind = .function },
            .{ .name = "now", .kind = .function },
        },
    },
    .{
        .name = "std/console",
        .exports = &[_]BuiltinModule.Export{
            .{ .name = "log", .kind = .function },
            .{ .name = "error", .kind = .function },
            .{ .name = "warn", .kind = .function },
            .{ .name = "info", .kind = .function },
            .{ .name = "debug", .kind = .function },
        },
    },
};

/// Check if a module name is a built-in module
pub fn isBuiltinModule(name: []const u8) bool {
    for (builtin_modules) |module| {
        if (std.mem.eql(u8, module.name, name)) {
            return true;
        }
    }
    return false;
}

/// Get a built-in module by name
pub fn getBuiltinModule(name: []const u8) ?BuiltinModule {
    for (builtin_modules) |module| {
        if (std.mem.eql(u8, module.name, name)) {
            return module;
        }
    }
    return null;
}

/// Check if an export exists in a built-in module
pub fn hasExport(module_name: []const u8, export_name: []const u8) bool {
    const module = getBuiltinModule(module_name) orelse return false;
    for (module.exports) |exp| {
        if (std.mem.eql(u8, exp.name, export_name)) {
            return true;
        }
    }
    return false;
}
