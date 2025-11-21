const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const typechecker = @import("typechecker.zig");
const codegen_wasm = @import("codegen_wasm.zig");

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

    pub fn init(allocator: std.mem.Allocator, options: CompileOptions) Compiler {
        return .{
            .allocator = allocator,
            .options = options,
        };
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

        // Type checking
        if (self.options.verbose) {
            std.debug.print("Type checking...\n", .{});
        }
        var checker = typechecker.TypeChecker.init(self.allocator);
        defer checker.deinit();

        try checker.checkModule(&module);

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

        const wasm_output = try codegen.generate(&module);

        // Write output
        const output_path = self.options.output_path orelse blk: {
            // Default output: replace .zs with .wat
            var buf: [std.fs.max_path_bytes]u8 = undefined;
            const base = std.fs.path.basename(self.options.source_path);
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
        return try std.fs.cwd().readFileAlloc(path, self.allocator, .unlimited);
    }

    fn writeFile(self: *Compiler, path: []const u8, content: []const u8) !void {
        _ = self;
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(content);
    }
};

pub fn compileFile(allocator: std.mem.Allocator, options: CompileOptions) !void {
    var compiler = Compiler.init(allocator, options);
    try compiler.compile();
}

test "compiler initialization" {
    const allocator = std.testing.allocator;
    const options = CompileOptions{
        .source_path = "test.zs",
    };
    const compiler = Compiler.init(allocator, options);
    try std.testing.expectEqualStrings("test.zs", compiler.options.source_path);
}
