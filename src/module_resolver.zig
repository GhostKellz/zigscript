const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("parser.zig").Parser;
const Lexer = @import("lexer.zig").Lexer;

pub const ModuleError = error{
    ModuleNotFound,
    CircularDependency,
    OutOfMemory,
    ParseError,
};

/// Represents a loaded module with its exports
pub const Module = struct {
    path: []const u8,
    source: []const u8,  // Keep source alive for string references in AST
    ast: *ast.Module,
    exports: std.StringHashMap(Export),

    pub const Export = union(enum) {
        function: *ast.FnDecl,
        struct_type: *ast.StructDecl,
        enum_type: *ast.EnumDecl,
    };

    pub fn deinit(self: *Module, allocator: std.mem.Allocator) void {
        self.exports.deinit();
        self.ast.deinit();
        allocator.destroy(self.ast);
        allocator.free(self.source);
        allocator.free(self.path);
    }
};

/// Module resolver - finds and loads modules
pub const ModuleResolver = struct {
    allocator: std.mem.Allocator,
    modules: std.StringHashMap(Module),
    loading_stack: std.ArrayList([]const u8), // For circular dependency detection
    search_paths: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) ModuleResolver {
        return .{
            .allocator = allocator,
            .modules = std.StringHashMap(Module).init(allocator),
            .loading_stack = std.ArrayList([]const u8){},
            .search_paths = std.ArrayList([]const u8){},
        };
    }

    pub fn deinit(self: *ModuleResolver) void {
        var it = self.modules.valueIterator();
        while (it.next()) |module| {
            module.deinit(self.allocator);
        }
        self.modules.deinit();
        self.loading_stack.deinit(self.allocator);

        for (self.search_paths.items) |path| {
            self.allocator.free(path);
        }
        self.search_paths.deinit(self.allocator);
    }

    /// Add a search path for modules
    pub fn addSearchPath(self: *ModuleResolver, path: []const u8) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        try self.search_paths.append(self.allocator, owned_path);
    }

    /// Resolve a module path to an absolute file path
    fn resolveModulePath(self: *ModuleResolver, module_path: []const u8, relative_to: ?[]const u8) ![]const u8 {
        // Try different extensions
        const extensions = [_][]const u8{ ".zs", "" };

        // If it's a relative import and we have a base path, try that first
        if (relative_to) |base| {
            const dir = std.fs.path.dirname(base) orelse ".";

            for (extensions) |ext| {
                const full_path = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}/{s}{s}",
                    .{ dir, module_path, ext }
                );
                errdefer self.allocator.free(full_path);

                // Check if file exists
                const file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
                    self.allocator.free(full_path);
                    if (err == error.FileNotFound) continue;
                    return err;
                };
                file.close();

                return full_path;
            }
        }

        // Try search paths
        for (self.search_paths.items) |search_path| {
            for (extensions) |ext| {
                const full_path = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}/{s}{s}",
                    .{ search_path, module_path, ext }
                );
                errdefer self.allocator.free(full_path);

                const file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
                    self.allocator.free(full_path);
                    if (err == error.FileNotFound) continue;
                    return err;
                };
                file.close();

                return full_path;
            }
        }

        // Try current directory
        for (extensions) |ext| {
            const full_path = try std.fmt.allocPrint(
                self.allocator,
                "{s}{s}",
                .{ module_path, ext }
            );
            errdefer self.allocator.free(full_path);

            const file = std.fs.cwd().openFile(full_path, .{}) catch |err| {
                self.allocator.free(full_path);
                if (err == error.FileNotFound) continue;
                return err;
            };
            file.close();

            return full_path;
        }

        std.debug.print("Module not found: {s}\n", .{module_path});
        return ModuleError.ModuleNotFound;
    }

    /// Load a module and its dependencies
    pub fn loadModule(self: *ModuleResolver, module_path: []const u8, relative_to: ?[]const u8) !*Module {
        // Resolve the full path
        const full_path = try self.resolveModulePath(module_path, relative_to);
        defer if (!std.mem.eql(u8, full_path, module_path)) self.allocator.free(full_path);

        // Check if already loaded
        if (self.modules.getPtr(full_path)) |existing| {
            return existing;
        }

        // Check for circular dependency
        for (self.loading_stack.items) |loading_path| {
            if (std.mem.eql(u8, loading_path, full_path)) {
                std.debug.print("Circular dependency detected: {s}\n", .{full_path});
                return ModuleError.CircularDependency;
            }
        }

        // Add to loading stack
        try self.loading_stack.append(self.allocator, full_path);
        defer _ = self.loading_stack.pop();

        // Read the file (don't free - it needs to stay alive for AST string references)
        const source = try std.fs.cwd().readFileAlloc(full_path, self.allocator, .unlimited);
        errdefer self.allocator.free(source);

        // Parse the module
        var lexer = Lexer.init(self.allocator, source);
        var parser = try Parser.init(self.allocator, &lexer);
        const module_ast = try parser.parseModule();

        // Extract exports
        var exports = std.StringHashMap(Module.Export).init(self.allocator);
        errdefer exports.deinit();

        for (module_ast.stmts) |*stmt| {
            switch (stmt.*) {
                .fn_decl => |*fn_decl| {
                    if (fn_decl.is_export) {
                        try exports.put(fn_decl.name, .{ .function = fn_decl });
                    }
                },
                .struct_decl => |*struct_decl| {
                    if (struct_decl.is_export) {
                        try exports.put(struct_decl.name, .{ .struct_type = struct_decl });
                    }
                },
                .enum_decl => |*enum_decl| {
                    if (enum_decl.is_export) {
                        try exports.put(enum_decl.name, .{ .enum_type = enum_decl });
                    }
                },
                else => {},
            }
        }

        // Store the module
        const owned_path = try self.allocator.dupe(u8, full_path);

        // Allocate the module AST on the heap
        const module_ast_ptr = try self.allocator.create(ast.Module);
        module_ast_ptr.* = module_ast;

        const module = Module{
            .path = owned_path,
            .source = source,  // Keep source alive
            .ast = module_ast_ptr,
            .exports = exports,
        };

        try self.modules.put(owned_path, module);

        return self.modules.getPtr(owned_path).?;
    }

    /// Get a loaded module
    pub fn getModule(self: *ModuleResolver, path: []const u8) ?*Module {
        return self.modules.getPtr(path);
    }

    /// Check if a symbol is exported from a module
    pub fn getExport(self: *ModuleResolver, module_path: []const u8, symbol_name: []const u8) ?Module.Export {
        const module = self.modules.get(module_path) orelse return null;
        return module.exports.get(symbol_name);
    }
};
