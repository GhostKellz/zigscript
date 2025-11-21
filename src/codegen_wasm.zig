const std = @import("std");
const ast = @import("ast.zig");
const wasm_memory = @import("wasm_memory.zig");

pub const CodegenError = error{
    UnsupportedFeature,
    OutOfMemory,
    InvalidCode,
    NoSpaceLeft,
};

// Simple WASM code generator
// For Phase 1, we'll generate a text format (.wat) that can be converted to binary .wasm
pub const WasmCodegen = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),
    indent_level: usize,
    local_count: usize,
    locals: std.StringHashMap(usize), // variable name -> local index
    memory_allocator: wasm_memory.WasmAllocator,

    pub fn init(allocator: std.mem.Allocator) WasmCodegen {
        return .{
            .allocator = allocator,
            .output = std.ArrayList(u8).empty,
            .indent_level = 0,
            .local_count = 0,
            .locals = std.StringHashMap(usize).init(allocator),
            .memory_allocator = wasm_memory.WasmAllocator.init(),
        };
    }

    pub fn deinit(self: *WasmCodegen) void {
        self.output.deinit(self.allocator);
        self.locals.deinit();
    }

    pub fn generate(self: *WasmCodegen, module: *ast.Module) ![]const u8 {
        try self.emit("(module\n");
        self.indent_level += 1;

        // Import memory from host
        try self.emitIndent();
        try self.emit("(memory (import \"env\" \"memory\") 1)\n");

        // Import console functions
        try self.emitIndent();
        try self.emit("(import \"env\" \"js_console_log\" (func $console_log (param i32 i32)))\n");

        // Import Nexus host functions for async operations
        try self.emitIndent();
        try self.emit("(import \"nexus\" \"http_get\" (func $nexus_http_get (param i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"nexus\" \"http_post\" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"nexus\" \"fs_read_file\" (func $nexus_fs_read_file (param i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"nexus\" \"fs_write_file\" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"nexus\" \"set_timeout\" (func $nexus_set_timeout (param i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"nexus\" \"promise_await\" (func $nexus_promise_await (param i32) (result i32)))\n");

        try self.emit("\n");

        // Generate code for each statement
        for (module.stmts) |*stmt| {
            try self.genStmt(stmt);
        }

        self.indent_level -= 1;
        try self.emit(")\n");

        return self.output.items;
    }

    fn genStmt(self: *WasmCodegen, stmt: *ast.Stmt) !void {
        switch (stmt.*) {
            .fn_decl => |*fn_decl| {
                try self.genFnDecl(fn_decl);
            },
            .let_decl => |*let_decl| {
                try self.genLetDecl(let_decl);
            },
            .return_stmt => |*ret| {
                try self.genReturnStmt(ret);
            },
            .if_stmt => |*if_stmt| {
                try self.genIfStmt(if_stmt);
            },
            .expr_stmt => |*expr_stmt| {
                try self.genExpr(&expr_stmt.expr);
                try self.emit("  drop\n"); // discard expression result
            },
            .block => |*block| {
                try self.emit("  (block\n");
                self.indent_level += 1;
                for (block.stmts) |*s| {
                    try self.genStmt(s);
                }
                self.indent_level -= 1;
                try self.emit("  )\n");
            },
            .for_stmt => |*for_stmt| {
                try self.genForStmt(for_stmt);
            },
            .while_stmt => |*while_stmt| {
                try self.genWhileStmt(while_stmt);
            },
            .break_stmt => {
                try self.emitIndent();
                try self.emit("br $break\n");
            },
            .continue_stmt => {
                try self.emitIndent();
                try self.emit("br $continue\n");
            },
            .struct_decl, .enum_decl, .import_stmt => {
                // These are handled at the type/module level
            },
        }
    }

    fn genFnDecl(self: *WasmCodegen, fn_decl: *ast.FnDecl) CodegenError!void {
        try self.emitIndent();
        try self.emit("(func $");
        try self.emit(fn_decl.name);

        // Handle export
        if (fn_decl.is_export or std.mem.eql(u8, fn_decl.name, "main")) {
            try self.emit(" (export \"");
            try self.emit(fn_decl.name);
            try self.emit("\")");
        }

        // Parameters
        for (fn_decl.params) |param| {
            try self.emit(" (param $");
            try self.emit(param.name);
            try self.emit(" ");
            try self.emit(try self.typeToWasm(param.type_annotation));
            try self.emit(")");

            // Track parameter as local
            try self.locals.put(param.name, self.local_count);
            self.local_count += 1;
        }

        // Return type
        if (fn_decl.return_type) |ret_type| {
            const wasm_type = try self.typeToWasm(ret_type);
            if (!std.mem.eql(u8, wasm_type, "void")) {
                try self.emit(" (result ");
                try self.emit(wasm_type);
                try self.emit(")");
            }
        }

        try self.emit("\n");
        self.indent_level += 1;

        // Function body
        for (fn_decl.body) |*stmt| {
            try self.genStmt(stmt);
        }

        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n\n");

        // Reset locals for next function
        self.locals.clearRetainingCapacity();
        self.local_count = 0;
    }

    fn genLetDecl(self: *WasmCodegen, let_decl: anytype) !void {
        // Allocate a local
        const local_index = self.local_count;
        self.local_count += 1;
        try self.locals.put(let_decl.name, local_index);

        // Declare the local
        try self.emitIndent();
        try self.emit("(local $");
        try self.emit(let_decl.name);
        try self.emit(" ");

        if (let_decl.type_annotation) |type_ann| {
            try self.emit(try self.typeToWasm(type_ann));
        } else {
            try self.emit("i32"); // default type
        }
        try self.emit(")\n");

        // Initialize if there's an initializer
        if (let_decl.initializer) |*initializer| {
            try self.genExpr(initializer);
            try self.emitIndent();
            try self.emit("local.set $");
            try self.emit(let_decl.name);
            try self.emit("\n");
        }
    }

    fn genReturnStmt(self: *WasmCodegen, ret: anytype) !void {
        if (ret.value) |*val| {
            try self.genExpr(val);
        }
        try self.emitIndent();
        try self.emit("return\n");
    }

    fn genIfStmt(self: *WasmCodegen, if_stmt: anytype) CodegenError!void {
        try self.emitIndent();
        try self.emit("(if\n");
        self.indent_level += 1;

        // Condition
        try self.emitIndent();
        try self.genExpr(&if_stmt.condition);
        try self.emit("\n");

        // Then block
        try self.emitIndent();
        try self.emit("(then\n");
        self.indent_level += 1;
        for (if_stmt.then_block) |*stmt| {
            try self.genStmt(stmt);
        }
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");

        // Else block
        if (if_stmt.else_block) |else_block| {
            try self.emitIndent();
            try self.emit("(else\n");
            self.indent_level += 1;
            for (else_block) |*stmt| {
                try self.genStmt(stmt);
            }
            self.indent_level -= 1;
            try self.emitIndent();
            try self.emit(")\n");
        }

        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");
    }

    fn genForStmt(self: *WasmCodegen, for_stmt: anytype) CodegenError!void {
        // For now, generate a simple comment
        // Full implementation would require:
        // 1. Evaluate iterable to get array pointer and length
        // 2. Create loop counter
        // 3. Generate WASM loop with block/loop/br
        // 4. Load array elements in loop body

        try self.emitIndent();
        try self.emit(";; for ");
        try self.emit(for_stmt.iterator);
        try self.emit(" in iterable\n");

        try self.emitIndent();
        try self.emit("(block $break\n");
        self.indent_level += 1;

        try self.emitIndent();
        try self.emit("(loop $continue\n");
        self.indent_level += 1;

        // Loop body
        for (for_stmt.body) |*stmt| {
            try self.genStmt(stmt);
        }

        try self.emitIndent();
        try self.emit("br $continue\n");

        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");

        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");
    }

    fn genWhileStmt(self: *WasmCodegen, while_stmt: anytype) CodegenError!void {
        try self.emitIndent();
        try self.emit(";; while loop\n");

        try self.emitIndent();
        try self.emit("(block $break\n");
        self.indent_level += 1;

        try self.emitIndent();
        try self.emit("(loop $continue\n");
        self.indent_level += 1;

        // Evaluate condition
        try self.genExpr(&while_stmt.condition);

        // If condition is false (0), break
        try self.emitIndent();
        try self.emit("i32.eqz\n");
        try self.emitIndent();
        try self.emit("br_if $break\n");

        // Loop body
        for (while_stmt.body) |*stmt| {
            try self.genStmt(stmt);
        }

        try self.emitIndent();
        try self.emit("br $continue\n");

        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");

        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");
    }

    fn genMatchExpr(self: *WasmCodegen, match_expr: anytype) CodegenError!void {
        // Evaluate the match value and store it in a local
        try self.emitIndent();
        try self.emit(";; match expression\n");
        try self.emitIndent();
        try self.emit("(local $match_val i32)\n");

        try self.genExpr(match_expr.value);
        try self.emitIndent();
        try self.emit("local.set $match_val\n");

        // Use nested if-else for pattern matching
        // For simple patterns (literals, identifiers), just use equality checks
        var first = true;
        for (match_expr.arms) |*arm| {
            if (!first) {
                // Not the first arm, this is an else branch
                self.indent_level += 1;
            }
            first = false;

            try self.emitIndent();
            switch (arm.pattern) {
                .wildcard => {
                    // Wildcard matches everything - no condition needed
                    try self.emit(";; wildcard pattern\n");
                    try self.genExpr(&arm.body);
                },
                .identifier => |id| {
                    // Bind the value to the identifier and execute body
                    try self.emit(";; pattern binding: ");
                    try self.emit(id);
                    try self.emit("\n");
                    try self.emitIndent();
                    try self.emit("(local $");
                    try self.emit(id);
                    try self.emit(" i32)\n");
                    try self.emitIndent();
                    try self.emit("local.get $match_val\n");
                    try self.emitIndent();
                    try self.emit("local.set $");
                    try self.emit(id);
                    try self.emit("\n");
                    try self.genExpr(&arm.body);
                },
                .literal => |*lit_expr| {
                    // Compare match value with literal
                    try self.emit("(if (result i32)\n");
                    self.indent_level += 1;
                    try self.emitIndent();
                    try self.emit("(i32.eq\n");
                    self.indent_level += 1;
                    try self.emitIndent();
                    try self.emit("local.get $match_val\n");
                    try self.genExpr(lit_expr);
                    self.indent_level -= 1;
                    try self.emitIndent();
                    try self.emit(")\n");
                    try self.emitIndent();
                    try self.emit("(then\n");
                    self.indent_level += 1;
                    try self.genExpr(&arm.body);
                    self.indent_level -= 1;
                    try self.emitIndent();
                    try self.emit(")\n");
                    try self.emitIndent();
                    try self.emit("(else\n");
                    // else branch continues with next arm
                },
                .enum_variant => |*variant| {
                    // TODO: Proper enum tag checking
                    _ = variant;
                    try self.emit(";; enum variant pattern (stub)\n");
                    try self.genExpr(&arm.body);
                },
            }
        }

        // Close all the else branches
        for (match_expr.arms, 0..) |*arm, i| {
            if (i > 0) {
                switch (arm.pattern) {
                    .literal => {
                        self.indent_level -= 1;
                        try self.emitIndent();
                        try self.emit(")\n");
                        self.indent_level -= 1;
                        try self.emitIndent();
                        try self.emit(")\n");
                    },
                    else => {},
                }
            }
        }
    }

    fn genExpr(self: *WasmCodegen, expr: *ast.Expr) CodegenError!void {
        switch (expr.*) {
            .integer_literal => |lit| {
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(lit.value);
                try self.emit("\n");
            },
            .float_literal => |lit| {
                try self.emitIndent();
                try self.emit("f64.const ");
                try self.emitFloat(lit.value);
                try self.emit("\n");
            },
            .bool_literal => |lit| {
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emit(if (lit.value) "1" else "0");
                try self.emit("\n");
            },
            .identifier => |id| {
                try self.emitIndent();
                try self.emit("local.get $");
                try self.emit(id.name);
                try self.emit("\n");
            },
            .binary => |*bin| {
                try self.genExpr(bin.left);
                try self.genExpr(bin.right);
                try self.emitIndent();

                const op = switch (bin.operator) {
                    .add => "i32.add",
                    .subtract => "i32.sub",
                    .multiply => "i32.mul",
                    .divide => "i32.div_s",
                    .modulo => "i32.rem_s",
                    .equal => "i32.eq",
                    .not_equal => "i32.ne",
                    .less_than => "i32.lt_s",
                    .less_equal => "i32.le_s",
                    .greater_than => "i32.gt_s",
                    .greater_equal => "i32.ge_s",
                    .logical_and => "i32.and",
                    .logical_or => "i32.or",
                    .bitwise_and => "i32.and",
                    .bitwise_or => "i32.or",
                    .bitwise_xor => "i32.xor",
                    .null_coalesce => return CodegenError.UnsupportedFeature,
                };

                try self.emit(op);
                try self.emit("\n");
            },
            .unary => |*un| {
                try self.genExpr(un.operand);
                try self.emitIndent();

                const op = switch (un.operator) {
                    .negate => "i32.const -1\n  i32.mul",
                    .not => "i32.eqz",
                    .bitwise_not => return CodegenError.UnsupportedFeature,
                };

                try self.emit(op);
                try self.emit("\n");
            },
            .call => |*call| {
                // Generate arguments
                for (call.args) |*arg| {
                    try self.genExpr(arg);
                }

                // Generate call
                try self.emitIndent();
                try self.emit("call $");

                // Extract function name from callee
                switch (call.callee.*) {
                    .identifier => |id| {
                        try self.emit(id.name);
                    },
                    .member_access => |*member| {
                        // Handle console.log(), etc.
                        switch (member.object.*) {
                            .identifier => |id| {
                                if (std.mem.eql(u8, id.name, "console") and std.mem.eql(u8, member.member, "log")) {
                                    try self.emit("console_log");
                                } else {
                                    return CodegenError.UnsupportedFeature;
                                }
                            },
                            else => return CodegenError.UnsupportedFeature,
                        }
                    },
                    else => return CodegenError.UnsupportedFeature,
                }

                try self.emit("\n");
            },
            .string_literal => {
                // String literals need to be stored in linear memory
                // For now, we'll skip this (Phase 1 limitation)
                try self.emitIndent();
                try self.emit("i32.const 0  ;; string literal placeholder\n");
            },
            .await_expr => |*await_expr| {
                // Generate the promise-returning expression (e.g., async function call)
                try self.emitIndent();
                try self.emit(";; await expression - evaluate promise\n");
                try self.genExpr(await_expr.expr);

                // The expression returns a promise ID (i32)
                // Call promise_await to get the resolved value
                try self.emitIndent();
                try self.emit("call $nexus_promise_await\n");
            },
            .try_expr => |*try_expr| {
                // For now, just generate the inner expression
                // Full Result<T,E> unwrapping will be implemented with ? operator
                try self.emitIndent();
                try self.emit(";; try expression (stub)\n");
                try self.genExpr(try_expr.expr);
            },
            .string_interpolation => |*interp| {
                // String interpolation: concatenate text and expr parts
                // For now, just return placeholder - full implementation needs memory allocator
                _ = interp;
                try self.emitIndent();
                try self.emit("i32.const 4096  ;; string interpolation result (needs allocator)\n");
            },
            .match_expr => |*match_expr| {
                try self.genMatchExpr(match_expr);
            },
            .array_literal => |*arr| {
                // Allocate memory for array
                const element_size: u32 = 4; // Assume i32 for now
                const array_size = @as(u32, @intCast(arr.elements.len)) * element_size;
                const ptr = self.memory_allocator.alloc(array_size);

                // Generate array elements and store them
                try self.emitIndent();
                try self.emit(";; array literal at ");
                try self.emitInt(@intCast(ptr));
                try self.emit("\n");

                // Store each element
                for (arr.elements, 0..) |*elem, i| {
                    // Calculate offset
                    const offset = ptr + (@as(u32, @intCast(i)) * element_size);

                    // Generate element value
                    try self.genExpr(elem);

                    // Store at offset
                    try self.emitIndent();
                    try self.emit("i32.const ");
                    try self.emitInt(@intCast(offset));
                    try self.emit("\n");
                    try self.emitIndent();
                    try self.emit("i32.store\n");
                }

                // Return array pointer
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(ptr));
                try self.emit("  ;; array pointer\n");
            },
            .struct_literal => |*str_lit| {
                // Allocate memory for struct (4 bytes per field for now)
                const field_size: u32 = 4;
                const struct_size = @as(u32, @intCast(str_lit.fields.len)) * field_size;
                const ptr = self.memory_allocator.alloc(struct_size);

                try self.emitIndent();
                try self.emit(";; struct literal at ");
                try self.emitInt(@intCast(ptr));
                try self.emit("\n");

                // Store each field
                for (str_lit.fields, 0..) |*field, i| {
                    const offset = ptr + (@as(u32, @intCast(i)) * field_size);

                    // Generate field value
                    try self.genExpr(&field.value);

                    // Store at offset
                    try self.emitIndent();
                    try self.emit("i32.const ");
                    try self.emitInt(@intCast(offset));
                    try self.emit("\n");
                    try self.emitIndent();
                    try self.emit("i32.store\n");
                }

                // Return struct pointer
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(ptr));
                try self.emit("  ;; struct pointer\n");
            },
            .assign_expr => |*assign| {
                // Generate the value expression
                try self.genExpr(assign.value);

                // Get the target variable name
                const target_name = switch (assign.target.*) {
                    .identifier => |id| id.name,
                    else => return CodegenError.UnsupportedFeature,
                };

                // Store to the local variable
                try self.emitIndent();
                try self.emit("local.set $");
                try self.emit(target_name);
                try self.emit("\n");

                // Assignment expression also returns the value, so load it again
                try self.emitIndent();
                try self.emit("local.get $");
                try self.emit(target_name);
                try self.emit("\n");
            },
            else => {
                return CodegenError.UnsupportedFeature;
            },
        }
    }

    fn typeToWasm(self: *WasmCodegen, type_def: ast.Type) ![]const u8 {
        _ = self;
        return switch (type_def) {
            .primitive => |p| switch (p) {
                .void => "void",
                .bool => "i32",
                .i32 => "i32",
                .i64 => "i64",
                .u32 => "i32",
                .u64 => "i64",
                .f64 => "f64",
                .string => "i32", // pointer to string in memory
                .bytes => "i32", // pointer to bytes in memory
            },
            else => "i32", // Default to i32 for complex types
        };
    }

    fn emit(self: *WasmCodegen, text: []const u8) !void {
        try self.output.appendSlice(self.allocator, text);
    }

    fn emitIndent(self: *WasmCodegen) !void {
        var i: usize = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.emit("  ");
        }
    }

    fn emitInt(self: *WasmCodegen, value: i64) !void {
        var buf: [32]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{d}", .{value});
        try self.emit(str);
    }

    fn emitFloat(self: *WasmCodegen, value: f64) !void {
        var buf: [32]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{d}", .{value});
        try self.emit(str);
    }
};

test "basic codegen" {
    const allocator = std.testing.allocator;
    var codegen = WasmCodegen.init(allocator);
    defer codegen.deinit();

    // Create a simple module with a function
    var module = ast.Module{
        .stmts = &[_]ast.Stmt{},
        .allocator = allocator,
    };

    const output = try codegen.generate(&module);
    try std.testing.expect(std.mem.indexOf(u8, output, "(module") != null);
}
