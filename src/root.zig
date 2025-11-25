//! ZigScript (zs) - A JavaScript replacement that compiles to WASM
//! This is the library root exposing the ZigScript compiler as a module

const std = @import("std");

// Re-export main compiler modules
pub const lexer = @import("lexer.zig");
pub const parser = @import("parser.zig");
pub const ast = @import("ast.zig");
pub const typechecker = @import("typechecker.zig");
pub const codegen_wasm = @import("codegen_wasm.zig");
pub const compiler = @import("compiler.zig");
pub const stdlib = @import("stdlib.zig");

// Main compilation function
pub fn compile(allocator: std.mem.Allocator, options: compiler.CompileOptions) !void {
    try compiler.compileFile(allocator, options);
}

// Version information
pub const version = "0.1.0";
pub const phase = "Phase 1 - Core Language MVP";

test "zs library imports" {
    const testing = std.testing;
    _ = testing;
    // Test that all modules compile
    _ = lexer;
    _ = parser;
    _ = ast;
    _ = typechecker;
    _ = codegen_wasm;
    _ = compiler;
    _ = stdlib;
}
