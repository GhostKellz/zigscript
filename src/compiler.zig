const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const typechecker = @import("typechecker.zig");
const codegen_wasm = @import("codegen_wasm.zig");
const module_resolver = @import("module_resolver.zig");

pub const CompileError = error{
    LexerError,
    ParserError,
    TypeCheckError,
    CodegenError,
    FileReadError,
    FileWriteError,
    OutOfMemory,
};

pub const CompileOptions = struct {
    source_path: []const u8,
    output_path: ?[]const u8 = null,
    check_only: bool = false,
    emit_wat: bool = true, // emit WebAssembly text format
    emit_wasm: bool = false, // emit binary WASM (requires wat2wasm)
    verbose: bool = false,
};

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    options: CompileOptions,
    resolver: module_resolver.ModuleResolver,

    pub fn init(allocator: std.mem.Allocator, options: CompileOptions) Compiler {
        var resolver = module_resolver.ModuleResolver.init(allocator);

        // Add default search paths
        resolver.addSearchPath("stdlib") catch {};
        resolver.addSearchPath("examples") catch {};
        resolver.addSearchPath(".") catch {};

        return .{
            .allocator = allocator,
            .options = options,
            .resolver = resolver,
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.resolver.deinit();
    }

    pub fn compile(self: *Compiler) !void {
        if (self.options.verbose) {
            std.debug.print("Compiling: {s}\n", .{self.options.source_path});
        }

        // Read source file
        const source = try self.readFile(self.options.source_path);
        defer self.allocator.free(source);

        // Lexical analysis
        if (self.options.verbose) {
            std.debug.print("Lexing...\n", .{});
        }
        var lex = lexer.Lexer.init(self.allocator, source);

        // Parsing
        if (self.options.verbose) {
            std.debug.print("Parsing...\n", .{});
        }
        var parse = try parser.Parser.init(self.allocator, &lex);
        defer parse.deinit();

        var module = try parse.parseModule();
        defer module.deinit();

        if (parse.had_error) {
            std.debug.print("Parsing failed with errors\n", .{});
            return CompileError.ParserError;
        }

        // Load imported modules
        if (self.options.verbose) {
            std.debug.print("Loading modules...\n", .{});
        }
        try self.loadImports(&module, self.options.source_path);

        // Type checking
        if (self.options.verbose) {
            std.debug.print("Type checking...\n", .{});
        }
        var checker = typechecker.TypeChecker.init(self.allocator);
        defer checker.deinit();

        // Pass the resolver to the type checker
        try checker.checkModuleWithImports(&module, &self.resolver);

        if (self.options.check_only) {
            std.debug.print("Type checking completed successfully\n", .{});
            return;
        }

        // Code generation
        if (self.options.verbose) {
            std.debug.print("Generating WASM...\n", .{});
        }
        var codegen = codegen_wasm.WasmCodegen.init(self.allocator);
        defer codegen.deinit();

        const wasm_output = try codegen.generateWithResolver(&module, &self.resolver);

        // Write output
        const output_path = self.options.output_path orelse blk: {
            // Default output: replace .zs with .wat
            var buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
            const base = std.Io.Dir.path.basename(self.options.source_path);
            const name = if (std.mem.endsWith(u8, base, ".zs"))
                base[0 .. base.len - 3]
            else
                base;

            const path = try std.fmt.bufPrint(&buf, "{s}.wat", .{name});
            break :blk try self.allocator.dupe(u8, path);
        };
        defer if (self.options.output_path == null) self.allocator.free(output_path);

        try self.writeFile(output_path, wasm_output);

        if (self.options.verbose) {
            std.debug.print("Output written to: {s}\n", .{output_path});
        }

        std.debug.print("Compilation successful!\n", .{});
    }

    fn readFile(self: *Compiler, path: []const u8) ![]u8 {
        const io = std.Io.Threaded.global_single_threaded.io();
        return try std.Io.Dir.cwd().readFileAlloc(io, path, self.allocator, .unlimited);
    }

    fn writeFile(self: *Compiler, path: []const u8, content: []const u8) !void {
        _ = self;
        const io = std.Io.Threaded.global_single_threaded.io();
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, content);
    }

    fn loadImports(self: *Compiler, module: *@import("ast.zig").Module, source_path: []const u8) !void {
        for (module.stmts) |*stmt| {
            if (stmt.* == .import_stmt) {
                const import_stmt = stmt.import_stmt;

                if (self.options.verbose) {
                    std.debug.print("  Loading module: {s}\n", .{import_stmt.from});
                }

                // Load the imported module
                _ = try self.resolver.loadModule(import_stmt.from, source_path);
            }
        }
    }
};

pub fn compileFile(allocator: std.mem.Allocator, options: CompileOptions) !void {
    var compiler = Compiler.init(allocator, options);
    defer compiler.deinit();
    try compiler.compile();
}

test "compiler initialization" {
    const allocator = std.testing.allocator;
    const options = CompileOptions{
        .source_path = "test.zs",
    };
    var compiler = Compiler.init(allocator, options);
    defer compiler.deinit();
    try std.testing.expectEqualStrings("test.zs", compiler.options.source_path);
}
