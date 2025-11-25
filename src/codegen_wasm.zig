const std = @import("std");
const ast = @import("ast.zig");
const wasm_memory = @import("wasm_memory.zig");
const module_resolver = @import("module_resolver.zig");

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
    output: std.ArrayListUnmanaged(u8),
    indent_level: usize,
    local_count: usize,
    locals: std.StringHashMap(usize), // variable name -> local index
    local_types: std.StringHashMap([]const u8), // variable name -> type name (for structs)
    lambda_vars: std.StringHashMap(void), // Track which variables hold lambdas (function values)
    memory_allocator: wasm_memory.WasmAllocator,
    module: ?*ast.Module, // Reference to AST module for type lookups
    lambda_count: usize, // Counter for generating unique lambda function names
    lambda_functions: std.ArrayListUnmanaged(u8), // Store lambda functions separately to emit at module level
    function_table_entries: std.ArrayListUnmanaged([]const u8), // Track function names for table
    expected_type: ?ast.Type, // Expected type context for expressions (for i64 coercion)

    pub fn init(allocator: std.mem.Allocator) WasmCodegen {
        return .{
            .allocator = allocator,
            .output = .{},
            .indent_level = 0,
            .local_count = 0,
            .locals = std.StringHashMap(usize).init(allocator),
            .local_types = std.StringHashMap([]const u8).init(allocator),
            .lambda_vars = std.StringHashMap(void).init(allocator),
            .memory_allocator = wasm_memory.WasmAllocator.init(),
            .module = null,
            .lambda_count = 0,
            .lambda_functions = .{},
            .function_table_entries = .{},
            .expected_type = null,
        };
    }

    pub fn deinit(self: *WasmCodegen) void {
        self.output.deinit(self.allocator);
        self.locals.deinit();
        self.local_types.deinit();
        self.lambda_vars.deinit();
        self.lambda_functions.deinit(self.allocator);
        // Free each lambda name string before deiniting the list
        for (self.function_table_entries.items) |name| {
            self.allocator.free(name);
        }
        self.function_table_entries.deinit(self.allocator);
    }

    // Helper: Infer if expression is f64 type
    fn isF64Expr(self: *WasmCodegen, expr: *const ast.Expr) bool {
        return switch (expr.*) {
            .float_literal => true,
            .integer_literal => false,
            .bool_literal => false,
            .string_literal => false,
            .binary => |*bin| self.isF64Expr(bin.left) or self.isF64Expr(bin.right),
            .unary => |*un| self.isF64Expr(un.operand),
            else => false, // Conservative: assume i32
        };
    }

    // Helper: Get field offset in a struct
    // Returns the byte offset of a field, or null if not found
    fn getFieldOffset(self: *WasmCodegen, struct_name: []const u8, field_name: []const u8) ?u32 {
        const module = self.module orelse return null;

        // Find the struct declaration
        for (module.stmts) |stmt| {
            if (stmt == .struct_decl) {
                const struct_decl = stmt.struct_decl;
                if (std.mem.eql(u8, struct_decl.name, struct_name)) {
                    // Find the field index
                    for (struct_decl.fields, 0..) |field, i| {
                        if (std.mem.eql(u8, field.name, field_name)) {
                            // Each field is 4 bytes for now (simple layout)
                            return @as(u32, @intCast(i)) * 4;
                        }
                    }
                    return null; // Field not found
                }
            }
        }
        return null; // Struct not found
    }

    pub fn generate(self: *WasmCodegen, module: *ast.Module) ![]const u8 {
        return self.generateWithResolver(module, null);
    }

    pub fn generateWithResolver(self: *WasmCodegen, module: *ast.Module, resolver: ?*module_resolver.ModuleResolver) ![]const u8 {
        self.module = module; // Store module reference for type lookups

        try self.emit("(module\n");
        self.indent_level += 1;

        // Import memory from host
        try self.emitIndent();
        try self.emit("(memory (import \"env\" \"memory\") 1)\n");

        // Import console functions
        try self.emitIndent();
        try self.emit("(import \"env\" \"js_console_log\" (func $console_log (param i32 i32)))\n");

        // Import JSON functions
        try self.emitIndent();
        try self.emit("(import \"std\" \"json_decode\" (func $json_decode (param i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"std\" \"json_encode\" (func $json_encode (param i32) (result i32)))\n");

        // Import HTTP client functions
        try self.emitIndent();
        try self.emit("(import \"std\" \"http_get\" (func $http_get (param i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"std\" \"http_post\" (func $http_post (param i32 i32 i32 i32) (result i32)))\n");

        // Import file system functions
        try self.emitIndent();
        try self.emit("(import \"std\" \"fs_read_file\" (func $fs_read_file (param i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"std\" \"fs_write_file\" (func $fs_write_file (param i32 i32 i32 i32) (result i32)))\n");

        // Import timer functions
        try self.emitIndent();
        try self.emit("(import \"std\" \"set_timeout\" (func $set_timeout (param i32 i32) (result i32)))\n");
        try self.emitIndent();
        try self.emit("(import \"std\" \"clear_timeout\" (func $clear_timeout (param i32)))\n");

        // Import Nexus async functions (for Promise integration)
        try self.emitIndent();
        try self.emit("(import \"std\" \"promise_await\" (func $promise_await (param i32) (result i32)))\n");

        try self.emit("\n");

        // If we have a resolver, generate imported functions first
        if (resolver) |res| {
            try self.generateImportedFunctions(module, res);
        }

        // Save output position before generating functions
        const imports_end_pos = self.output.items.len;

        // Generate code for each statement in this module
        for (module.stmts) |*stmt| {
            try self.genStmt(stmt);
        }

        // Now emit type definitions BEFORE the functions if we have lambdas
        if (self.function_table_entries.items.len > 0) {
            // Create type definitions buffer
            var type_defs = std.ArrayListUnmanaged(u8){};
            defer type_defs.deinit(self.allocator);

            // Generate type definitions
            var param_count: usize = 0;
            while (param_count <= 4) : (param_count += 1) {
                try type_defs.appendSlice(self.allocator, "  (type $lambda_type_");
                const count_str = try std.fmt.allocPrint(self.allocator, "{d}", .{param_count});
                defer self.allocator.free(count_str);
                try type_defs.appendSlice(self.allocator, count_str);
                try type_defs.appendSlice(self.allocator, " (func");
                var i: usize = 0;
                while (i < param_count) : (i += 1) {
                    try type_defs.appendSlice(self.allocator, " (param i32)");
                }
                try type_defs.appendSlice(self.allocator, " (result i32)))\n");
            }
            try type_defs.appendSlice(self.allocator, "\n");

            // Insert type definitions before functions
            try self.output.insertSlice(self.allocator, imports_end_pos, type_defs.items);
        }

        // Emit lambda functions
        if (self.lambda_functions.items.len > 0) {
            try self.output.appendSlice(self.allocator, self.lambda_functions.items);
        }

        // Emit function table if we have lambdas
        if (self.function_table_entries.items.len > 0) {
            try self.emitIndent();
            try self.emit("(table ");
            try self.emitInt(@intCast(self.function_table_entries.items.len));
            try self.emit(" funcref)\n");
            try self.emitIndent();
            try self.emit("(elem (i32.const 0)");
            for (self.function_table_entries.items) |name| {
                try self.emit(" $");
                try self.emit(name);
            }
            try self.emit(")\n");
        }

        self.indent_level -= 1;
        try self.emit(")\n");

        return self.output.items;
    }

    fn generateImportedFunctions(self: *WasmCodegen, module: *ast.Module, resolver: *module_resolver.ModuleResolver) !void {
        // Find all import statements
        for (module.stmts) |stmt| {
            if (stmt == .import_stmt) {
                const import_stmt = stmt.import_stmt;

                // Find the loaded module
                var module_iter = resolver.modules.iterator();
                while (module_iter.next()) |entry| {
                    // Check if path ends with import name
                    const search_patterns = [_][]const u8{
                        import_stmt.from,
                        try std.fmt.allocPrint(self.allocator, "{s}.zs", .{import_stmt.from}),
                        try std.fmt.allocPrint(self.allocator, "examples/{s}", .{import_stmt.from}),
                        try std.fmt.allocPrint(self.allocator, "examples/{s}.zs", .{import_stmt.from}),
                    };

                    var found = false;
                    for (search_patterns) |pattern| {
                        if (std.mem.endsWith(u8, entry.key_ptr.*, pattern)) {
                            found = true;
                            break;
                        }
                    }

                    if (found) {
                        const imported_module = entry.value_ptr;

                        // Generate each imported function
                        for (import_stmt.imports) |item| {
                            if (imported_module.exports.get(item.name)) |export_item| {
                                if (export_item == .function) {
                                    // Temporarily set module to the imported module for struct lookups
                                    const saved_module = self.module;
                                    self.module = imported_module.ast;

                                    try self.genFnDecl(export_item.function);

                                    // Restore module
                                    self.module = saved_module;
                                }
                            }
                        }
                        break;
                    }
                }
            }
        }
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
            .struct_decl => |*struct_decl| {
                // Generate methods for the struct
                for (struct_decl.methods) |*method| {
                    try self.genStructMethod(struct_decl.name, method);
                }
            },
            .enum_decl, .import_stmt, .extern_fn_decl => {
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

            // Track parameter type if it's a user-defined type (struct)
            if (param.type_annotation == .user_defined) {
                try self.local_types.put(param.name, param.type_annotation.user_defined);
            }
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
        self.local_types.clearRetainingCapacity();
        self.local_count = 0;
    }

    fn genStructMethod(self: *WasmCodegen, struct_name: []const u8, method: *ast.FnDecl) CodegenError!void {
        try self.emitIndent();
        try self.emit("(func $");
        try self.emit(struct_name);
        try self.emit("_");
        try self.emit(method.name);

        // Add self parameter (pointer to struct instance)
        try self.emit(" (param $self i32)");
        try self.locals.put("self", self.local_count);
        self.local_count += 1;

        // Add other parameters
        for (method.params) |param| {
            try self.emit(" (param $");
            try self.emit(param.name);
            try self.emit(" ");
            try self.emit(try self.typeToWasm(param.type_annotation));
            try self.emit(")");

            try self.locals.put(param.name, self.local_count);
            self.local_count += 1;
        }

        // Return type
        if (method.return_type) |ret_type| {
            const wasm_type = try self.typeToWasm(ret_type);
            if (!std.mem.eql(u8, wasm_type, "void")) {
                try self.emit(" (result ");
                try self.emit(wasm_type);
                try self.emit(")");
            }
        }

        try self.emit("\n");
        self.indent_level += 1;

        // Method body
        for (method.body) |*stmt| {
            try self.genStmt(stmt);
        }

        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n\n");

        // Reset locals for next function
        self.locals.clearRetainingCapacity();
        self.local_types.clearRetainingCapacity();
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

        // Track type if it's user-defined (struct)
        if (let_decl.type_annotation) |type_ann| {
            if (type_ann == .user_defined) {
                try self.local_types.put(let_decl.name, type_ann.user_defined);
            }
        }

        // Initialize if there's an initializer
        if (let_decl.initializer) |*initializer| {
            // Track type from struct literal if no type annotation
            if (initializer.* == .struct_literal and let_decl.type_annotation == null) {
                try self.local_types.put(let_decl.name, initializer.struct_literal.type_name);
            }

            // Track if this variable holds a lambda
            if (initializer.* == .lambda) {
                try self.lambda_vars.put(let_decl.name, {});
            }

            // Set expected type for integer literal coercion
            const saved_expected_type = self.expected_type;
            if (let_decl.type_annotation) |type_ann| {
                self.expected_type = type_ann;
            }

            try self.genExpr(initializer);

            // Restore expected type
            self.expected_type = saved_expected_type;

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
                // Check if we should emit i64 instead of i32
                if (self.expected_type) |expected| {
                    if (expected == .primitive and expected.primitive == .i64) {
                        try self.emit("i64.const ");
                        try self.emitInt(lit.value);
                        try self.emit("\n");
                        return;
                    }
                }
                // Default to i32
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
            .member_access => |*member| {
                // Struct field access: obj.field
                // We need to:
                // 1. Get the struct pointer
                // 2. Calculate field offset based on struct type
                // 3. Load from memory at pointer + offset

                // Generate code to get the object (should be a struct pointer)
                try self.genExpr(member.object);

                // Try to determine the struct type from the object
                var field_offset: ?u32 = null;

                // If object is an identifier, look up its type
                if (member.object.* == .identifier) {
                    const obj_name = member.object.identifier.name;
                    if (self.local_types.get(obj_name)) |struct_name| {
                        field_offset = self.getFieldOffset(struct_name, member.member);
                    }
                }

                const offset = field_offset orelse 0; // Default to 0 if we can't determine

                if (offset > 0) {
                    // Add offset to pointer
                    try self.emitIndent();
                    try self.emit("i32.const ");
                    try self.emitInt(offset);
                    try self.emit("\n");
                    try self.emitIndent();
                    try self.emit("i32.add\n");
                }

                // Load value from memory
                try self.emitIndent();
                try self.emit("i32.load  ;; load field ");
                try self.emit(member.member);
                try self.emit("\n");
            },
            .binary => |*bin| {
                try self.genExpr(bin.left);
                try self.genExpr(bin.right);
                try self.emitIndent();

                // Detect if we're working with f64
                const is_f64 = self.isF64Expr(bin.left) or self.isF64Expr(bin.right);

                const op = switch (bin.operator) {
                    .add => if (is_f64) "f64.add" else "i32.add",
                    .subtract => if (is_f64) "f64.sub" else "i32.sub",
                    .multiply => if (is_f64) "f64.mul" else "i32.mul",
                    .divide => if (is_f64) "f64.div" else "i32.div_s",
                    .modulo => if (is_f64) "f64.rem" else "i32.rem_s",
                    .equal => blk: {
                        break :blk if (is_f64) "f64.eq" else "i32.eq";
                    },
                    .not_equal => blk: {
                        break :blk if (is_f64) "f64.ne" else "i32.ne";
                    },
                    .less_than => blk: {
                        break :blk if (is_f64) "f64.lt" else "i32.lt_s";
                    },
                    .less_equal => blk: {
                        break :blk if (is_f64) "f64.le" else "i32.le_s";
                    },
                    .greater_than => blk: {
                        break :blk if (is_f64) "f64.gt" else "i32.gt_s";
                    },
                    .greater_equal => blk: {
                        break :blk if (is_f64) "f64.ge" else "i32.ge_s";
                    },
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

                const is_f64 = self.isF64Expr(un.operand);

                const op = switch (un.operator) {
                    .negate => if (is_f64) "f64.neg" else "i32.const -1\n  i32.mul",
                    .not => "i32.eqz",
                    .bitwise_not => return CodegenError.UnsupportedFeature,
                };

                try self.emit(op);
                try self.emit("\n");
            },
            .call => |*call| {
                // Check if this is a method call (arr.method())
                if (call.callee.* == .member_access) {
                    const member = call.callee.member_access;

                    // Array methods
                    if (std.mem.eql(u8, member.member, "push")) {
                        try self.genArrayPush(member.object, call.args);
                        return;
                    } else if (std.mem.eql(u8, member.member, "pop")) {
                        try self.genArrayPop(member.object);
                        return;
                    } else if (std.mem.eql(u8, member.member, "len")) {
                        try self.genArrayLen(member.object);
                        return;
                    } else if (std.mem.eql(u8, member.member, "map")) {
                        try self.genArrayMap(member.object, call.args);
                        return;
                    } else if (std.mem.eql(u8, member.member, "filter")) {
                        try self.genArrayFilter(member.object, call.args);
                        return;
                    } else if (std.mem.eql(u8, member.member, "reduce")) {
                        try self.genArrayReduce(member.object, call.args);
                        return;
                    }

                    // Struct method call: obj.method()
                    // Try to determine struct type from object
                    var struct_type_name: ?[]const u8 = null;
                    if (member.object.* == .identifier) {
                        const obj_name = member.object.identifier.name;
                        if (self.local_types.get(obj_name)) |type_name| {
                            struct_type_name = type_name;
                        } else {
                        }
                    }

                    if (struct_type_name) |type_name| {
                        // Generate struct method call: StructName_method(self, args...)
                        // Push self (the struct instance) first
                        try self.genExpr(member.object);

                        // Push other arguments
                        for (call.args) |*arg| {
                            try self.genExpr(arg);
                        }

                        // Call the method
                        try self.emitIndent();
                        try self.emit("call $");
                        try self.emit(type_name);
                        try self.emit("_");
                        try self.emit(member.member);
                        try self.emit("\n");
                        return;
                    } else {
                    }
                }

                // Regular function call - check if it's a lambda call
                // Extract function name from callee first to check if it's a lambda
                const is_lambda_call = blk: {
                    if (call.callee.* == .identifier) {
                        const id = call.callee.identifier;
                        break :blk self.lambda_vars.contains(id.name);
                    }
                    break :blk false;
                };

                if (is_lambda_call) {
                    // Lambda call using call_indirect
                    // Generate arguments
                    for (call.args) |*arg| {
                        try self.genExpr(arg);
                    }

                    // Load lambda index from variable
                    const id = call.callee.identifier;
                    try self.emitIndent();
                    try self.emit("local.get $");
                    try self.emit(id.name);
                    try self.emit("\n");

                    // Emit call_indirect with type signature
                    try self.emitIndent();
                    try self.emit("call_indirect (type $lambda_type_");
                    try self.emitInt(@intCast(call.args.len));
                    try self.emit(")\n");
                } else {
                    // Regular function call
                    // Get function name first to look up signature
                    const fn_name = switch (call.callee.*) {
                        .identifier => |id| id.name,
                        else => null,
                    };

                    // Generate arguments with proper types
                    for (call.args, 0..) |*arg, i| {
                        // Try to set expected type from function signature
                        if (fn_name) |name| {
                            if (self.module) |mod| {
                                for (mod.stmts) |stmt| {
                                    if (stmt == .fn_decl and std.mem.eql(u8, stmt.fn_decl.name, name)) {
                                        if (i < stmt.fn_decl.params.len) {
                                            self.expected_type = stmt.fn_decl.params[i].type_annotation;
                                        }
                                        break;
                                    }
                                }
                            }
                        }
                        try self.genExpr(arg);
                        self.expected_type = null; // Reset
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
                                        try self.emit(member.member);
                                    }
                                },
                                else => {
                                    return CodegenError.UnsupportedFeature;
                                }
                            }
                        },
                        else => return CodegenError.UnsupportedFeature,
                    }

                    try self.emit("\n");
                }
            },
            .string_literal => |*str_lit| {
                // Store string in linear memory: [length: i32][...bytes...]
                const str_bytes = str_lit.value;
                const str_len = @as(u32, @intCast(str_bytes.len));

                // Allocate: 4 bytes for length + string bytes
                const total_size = 4 + str_len;
                const ptr = self.memory_allocator.alloc(total_size);

                try self.emitIndent();
                try self.emit(";; string literal \"");
                // Truncate for display if too long
                const display_len = @min(str_bytes.len, 20);
                try self.emit(str_bytes[0..display_len]);
                if (str_bytes.len > 20) try self.emit("...");
                try self.emit("\" at ");
                try self.emitInt(@intCast(ptr));
                try self.emit("\n");

                // Store length
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(ptr));
                try self.emit("\n");
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(str_len));
                try self.emit("\n");
                try self.emitIndent();
                try self.emit("i32.store\n");

                // Store each byte of the string
                for (str_bytes, 0..) |byte, i| {
                    try self.emitIndent();
                    try self.emit("i32.const ");
                    try self.emitInt(@intCast(ptr + 4 + i));
                    try self.emit("\n");
                    try self.emitIndent();
                    try self.emit("i32.const ");
                    try self.emitInt(@intCast(byte));
                    try self.emit("\n");
                    try self.emitIndent();
                    try self.emit("i32.store8\n");
                }

                // Return pointer to the string (pointing at length field)
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(ptr));
                try self.emit("  ;; string pointer\n");
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
                try self.genStringInterpolation(interp);
            },
            .match_expr => |*match_expr| {
                try self.genMatchExpr(match_expr);
            },
            .index_access => |*idx| {
                // arr[i] → load from memory
                // Array layout: [length: i32][capacity: i32][elem0][elem1]...
                // Generate array pointer
                try self.genExpr(idx.object);

                // Add metadata offset (8 bytes)
                try self.emitIndent();
                try self.emit("i32.const 8\n");
                try self.emitIndent();
                try self.emit("i32.add\n");

                // Generate index
                try self.genExpr(idx.index);

                // Calculate offset: (ptr + 8) + (index * 4)
                try self.emitIndent();
                try self.emit("i32.const 4\n");
                try self.emitIndent();
                try self.emit("i32.mul\n");
                try self.emitIndent();
                try self.emit("i32.add\n");

                // Load value
                try self.emitIndent();
                try self.emit("i32.load\n");
            },
            .array_literal => |*arr| {
                // Array layout: [length: i32][capacity: i32][elem0][elem1]...
                const element_size: u32 = 4;
                const len = @as(u32, @intCast(arr.elements.len));
                const capacity = len * 2; // Initial capacity is 2x length
                const metadata_size: u32 = 8; // length + capacity
                const array_size = metadata_size + (capacity * element_size);
                const ptr = self.memory_allocator.alloc(array_size);

                try self.emitIndent();
                try self.emit(";; array literal at ");
                try self.emitInt(@intCast(ptr));
                try self.emit("\n");

                // Store length
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(ptr));
                try self.emit("\n");
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(len));
                try self.emit("\n");
                try self.emitIndent();
                try self.emit("i32.store\n");

                // Store capacity
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(ptr + 4));
                try self.emit("\n");
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(capacity));
                try self.emit("\n");
                try self.emitIndent();
                try self.emit("i32.store\n");

                // Store each element
                for (arr.elements, 0..) |*elem, i| {
                    const offset = ptr + metadata_size + (@as(u32, @intCast(i)) * element_size);

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
                switch (assign.target.*) {
                    .identifier => |id| {
                        // Simple variable assignment
                        try self.genExpr(assign.value);
                        try self.emitIndent();
                        try self.emit("local.set $");
                        try self.emit(id.name);
                        try self.emit("\n");
                        try self.emitIndent();
                        try self.emit("local.get $");
                        try self.emit(id.name);
                        try self.emit("\n");
                    },
                    .index_access => |*idx| {
                        // arr[i] = value
                        // Calculate address: (ptr + 8) + (index * 4)
                        try self.genExpr(idx.object);
                        try self.emitIndent();
                        try self.emit("i32.const 8\n");
                        try self.emitIndent();
                        try self.emit("i32.add\n");
                        try self.genExpr(idx.index);
                        try self.emitIndent();
                        try self.emit("i32.const 4\n");
                        try self.emitIndent();
                        try self.emit("i32.mul\n");
                        try self.emitIndent();
                        try self.emit("i32.add\n");

                        // Generate value
                        try self.genExpr(assign.value);

                        // Store
                        try self.emitIndent();
                        try self.emit("i32.store\n");

                        // Return the value
                        try self.genExpr(assign.value);
                    },
                    .member_access => |*member| {
                        // struct.field = value
                        // Calculate field offset and store

                        // Get struct type
                        var struct_type_name: ?[]const u8 = null;
                        if (member.object.* == .identifier) {
                            const obj_name = member.object.identifier.name;
                            if (self.local_types.get(obj_name)) |type_name| {
                                struct_type_name = type_name;
                            }
                        }

                        const offset = if (struct_type_name) |type_name|
                            self.getFieldOffset(type_name, member.member) orelse 0
                        else
                            0;

                        // Get struct pointer
                        try self.genExpr(member.object);

                        // Add offset if needed
                        if (offset > 0) {
                            try self.emitIndent();
                            try self.emit("i32.const ");
                            try self.emitInt(offset);
                            try self.emit("\n");
                            try self.emitIndent();
                            try self.emit("i32.add\n");
                        }

                        // Generate value
                        try self.genExpr(assign.value);

                        // Store
                        try self.emitIndent();
                        try self.emit("i32.store  ;; set field ");
                        try self.emit(member.member);
                        try self.emit("\n");

                        // Return the value
                        try self.genExpr(assign.value);
                    },
                    else => return CodegenError.UnsupportedFeature,
                }
            },
            .lambda => |*lambda| {
                // Generate unique lambda function
                const lambda_name = try std.fmt.allocPrint(
                    self.allocator,
                    "lambda_{d}",
                    .{self.lambda_count}
                );
                const lambda_index = self.lambda_count;
                self.lambda_count += 1;

                // Save current output and switch to lambda_functions buffer
                const saved_output = self.output;
                self.output = .{};
                const saved_locals = self.locals;
                self.locals = std.StringHashMap(usize).init(self.allocator);
                const saved_local_count = self.local_count;
                self.local_count = 0;

                // Generate lambda function
                try self.emitIndent();
                try self.emit("(func $");
                try self.emit(lambda_name);

                // Parameters
                for (lambda.params) |param| {
                    try self.emit(" (param $");
                    try self.emit(param.name);
                    try self.emit(" ");
                    try self.emit(try self.typeToWasm(param.type_annotation));
                    try self.emit(")");
                    try self.locals.put(param.name, self.local_count);
                    self.local_count += 1;
                }

                // Return type
                if (lambda.return_type) |ret_type| {
                    const wasm_type = try self.typeToWasm(ret_type);
                    if (!std.mem.eql(u8, wasm_type, "void")) {
                        try self.emit(" (result ");
                        try self.emit(wasm_type);
                        try self.emit(")");
                    }
                } else {
                    // Infer return type from body
                    try self.emit(" (result i32)");
                }

                try self.emit("\n");
                self.indent_level += 1;

                // Generate lambda body
                switch (lambda.body) {
                    .expression => |expr_ptr| {
                        try self.genExpr(expr_ptr);
                        try self.emitIndent();
                        try self.emit("return\n");
                    },
                    .block => |stmts| {
                        for (stmts) |*stmt| {
                            try self.genStmt(stmt);
                        }
                    },
                }

                self.indent_level -= 1;
                try self.emitIndent();
                try self.emit(")\n\n");

                // Save lambda function
                try self.lambda_functions.appendSlice(self.allocator, self.output.items);
                try self.function_table_entries.append(self.allocator, lambda_name);

                // Restore output
                self.output.deinit(self.allocator);
                self.output = saved_output;
                self.locals.deinit();
                self.locals = saved_locals;
                self.local_count = saved_local_count;

                // Return lambda index for function table
                try self.emitIndent();
                try self.emit("i32.const ");
                try self.emitInt(@intCast(lambda_index));
                try self.emit("  ;; lambda index\n");
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
    fn genStringInterpolation(self: *WasmCodegen, interp: *const ast.Expr.StringInterpolation) !void {
        // For string interpolation, we'll use a simple approach:
        // 1. Allocate memory for the concatenated result (estimate max size)
        // 2. Write each part sequentially
        // 3. Return pointer to start

        // For now, simplified version: just allocate space and store parts
        // A full implementation would need actual string concat host function

        const alloc_ptr = self.memory_allocator.alloc(256); // Max 256 bytes for interpolated string

        try self.emitIndent();
        try self.emit(";; String interpolation\n");

        // Store string parts - for MVP just return allocated pointer
        // In a full impl, we'd iterate and concat each part
        _ = interp;

        try self.emitIndent();
        try self.emit("i32.const ");
        try self.emit(try std.fmt.allocPrint(self.allocator, "{d}", .{alloc_ptr}));
        try self.emit("  ;; interpolated string ptr\n");

        // TODO: Implement actual string concatenation
        // For each part:
        //   - If text: write literal bytes
        //   - If expr: convert to string and append
    }

    // Array method implementations
    fn genArrayLen(self: *WasmCodegen, array_expr: *ast.Expr) !void {
        // Array metadata: [length: i32][capacity: i32][elements...]
        // Read length at offset 0
        try self.genExpr(array_expr);
        try self.emitIndent();
        try self.emit("i32.load  ;; load array length\n");
    }

    fn genArrayPush(self: *WasmCodegen, array_expr: *ast.Expr, args: []ast.Expr) !void {
        if (args.len != 1) return CodegenError.UnsupportedFeature;

        // Simplified: assume array has capacity
        // Array layout: [length: i32][capacity: i32][elem0][elem1]...
        // 1. Load current length
        try self.genExpr(array_expr);
        try self.emitIndent();
        try self.emit("local.tee $arr_ptr\n");
        try self.emitIndent();
        try self.emit("i32.load  ;; load length\n");
        try self.emitIndent();
        try self.emit("local.set $arr_len\n");

        // 2. Calculate element address: ptr + 8 + (len * 4)
        try self.emitIndent();
        try self.emit("local.get $arr_ptr\n");
        try self.emitIndent();
        try self.emit("i32.const 8\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.const 4\n");
        try self.emitIndent();
        try self.emit("i32.mul\n");
        try self.emitIndent();
        try self.emit("i32.add\n");

        // 3. Store value
        try self.genExpr(&args[0]);
        try self.emitIndent();
        try self.emit("i32.store\n");

        // 4. Increment length
        try self.emitIndent();
        try self.emit("local.get $arr_ptr\n");
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.const 1\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("i32.store\n");

        // Return void (push i32.const 0)
        try self.emitIndent();
        try self.emit("i32.const 0\n");
    }

    fn genArrayPop(self: *WasmCodegen, array_expr: *ast.Expr) !void {
        // 1. Load array pointer and length
        try self.genExpr(array_expr);
        try self.emitIndent();
        try self.emit("local.tee $arr_ptr\n");
        try self.emitIndent();
        try self.emit("i32.load  ;; load length\n");
        try self.emitIndent();
        try self.emit("local.tee $arr_len\n");

        // 2. Check if empty (length == 0)
        try self.emitIndent();
        try self.emit("i32.const 0\n");
        try self.emitIndent();
        try self.emit("i32.eq\n");
        try self.emitIndent();
        try self.emit("if\n");
        self.indent_level += 1;
        try self.emitIndent();
        try self.emit("i32.const 0  ;; return 0 if empty\n");
        try self.emitIndent();
        try self.emit("return\n");
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("end\n");

        // 3. Decrement length
        try self.emitIndent();
        try self.emit("local.get $arr_ptr\n");
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.const 1\n");
        try self.emitIndent();
        try self.emit("i32.sub\n");
        try self.emitIndent();
        try self.emit("local.tee $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.store\n");

        // 4. Load last element: ptr + 8 + (len * 4)
        try self.emitIndent();
        try self.emit("local.get $arr_ptr\n");
        try self.emitIndent();
        try self.emit("i32.const 8\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.const 4\n");
        try self.emitIndent();
        try self.emit("i32.mul\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("i32.load  ;; load popped value\n");
    }

    fn genArrayMap(self: *WasmCodegen, array_expr: *ast.Expr, args: []ast.Expr) !void {
        if (args.len != 1) return CodegenError.UnsupportedFeature;

        // arr.map(fn) - simplified: create new array, iterate, apply fn, store results
        // Get source array
        try self.genExpr(array_expr);
        try self.emitIndent();
        try self.emit("local.tee $src_arr\n");
        try self.emitIndent();
        try self.emit("i32.load  ;; load source length\n");
        try self.emitIndent();
        try self.emit("local.tee $arr_len\n");

        // Allocate new array with same length
        try self.emitIndent();
        try self.emit("i32.const 4\n");
        try self.emitIndent();
        try self.emit("i32.mul  ;; elements size\n");
        try self.emitIndent();
        try self.emit("i32.const 8\n");
        try self.emitIndent();
        try self.emit("i32.add  ;; + metadata\n");
        try self.emitIndent();
        try self.emit("call $alloc\n");
        try self.emitIndent();
        try self.emit("local.tee $new_arr\n");

        // Store length & capacity in new array
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.store  ;; store length\n");
        try self.emitIndent();
        try self.emit("local.get $new_arr\n");
        try self.emitIndent();
        try self.emit("i32.const 4\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.store  ;; store capacity\n");

        // Loop: for each element, apply fn, store in new array
        try self.emitIndent();
        try self.emit("i32.const 0\n");
        try self.emitIndent();
        try self.emit("local.set $i\n");
        try self.emitIndent();
        try self.emit("(loop $map_loop\n");
        self.indent_level += 1;

        // Check if i < len
        try self.emitIndent();
        try self.emit("local.get $i\n");
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.lt_s\n");
        try self.emitIndent();
        try self.emit("if\n");
        self.indent_level += 1;

        // Load element: src_arr + 8 + (i * 4)
        try self.emitIndent();
        try self.emit("local.get $src_arr\n");
        try self.emitIndent();
        try self.emit("i32.const 8\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.get $i\n");
        try self.emitIndent();
        try self.emit("i32.const 4\n");
        try self.emitIndent();
        try self.emit("i32.mul\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("i32.load  ;; load element\n");

        // Apply function (inline lambda for now - simplified)
        // TODO: proper function call
        // For now, just copy element (identity function)

        // Store in new array: new_arr + 8 + (i * 4)
        try self.emitIndent();
        try self.emit("local.get $new_arr\n");
        try self.emitIndent();
        try self.emit("i32.const 8\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.get $i\n");
        try self.emitIndent();
        try self.emit("i32.const 4\n");
        try self.emitIndent();
        try self.emit("i32.mul\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("i32.store\n");

        // Increment i
        try self.emitIndent();
        try self.emit("local.get $i\n");
        try self.emitIndent();
        try self.emit("i32.const 1\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.set $i\n");

        // Loop back
        try self.emitIndent();
        try self.emit("br $map_loop\n");
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("end\n");
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");

        // Return new array
        try self.emitIndent();
        try self.emit("local.get $new_arr\n");
    }

    fn genArrayFilter(self: *WasmCodegen, array_expr: *ast.Expr, args: []ast.Expr) !void {
        _ = args;
        _ = array_expr;
        // Simplified: allocate result array, iterate, test predicate, append if true
        // TODO: implement filter logic
        try self.emitIndent();
        try self.emit("i32.const 0  ;; TODO: filter implementation\n");
    }

    fn genArrayReduce(self: *WasmCodegen, array_expr: *ast.Expr, args: []ast.Expr) !void {
        if (args.len != 2) return CodegenError.UnsupportedFeature;

        // arr.reduce(fn, initial)
        // Get array
        try self.genExpr(array_expr);
        try self.emitIndent();
        try self.emit("local.tee $arr_ptr\n");
        try self.emitIndent();
        try self.emit("i32.load  ;; load length\n");
        try self.emitIndent();
        try self.emit("local.set $arr_len\n");

        // Get initial value (accumulator)
        try self.genExpr(&args[1]);
        try self.emitIndent();
        try self.emit("local.set $acc\n");

        // Loop through elements
        try self.emitIndent();
        try self.emit("i32.const 0\n");
        try self.emitIndent();
        try self.emit("local.set $i\n");
        try self.emitIndent();
        try self.emit("(loop $reduce_loop\n");
        self.indent_level += 1;

        // Check if i < len
        try self.emitIndent();
        try self.emit("local.get $i\n");
        try self.emitIndent();
        try self.emit("local.get $arr_len\n");
        try self.emitIndent();
        try self.emit("i32.lt_s\n");
        try self.emitIndent();
        try self.emit("if\n");
        self.indent_level += 1;

        // Load current element
        try self.emitIndent();
        try self.emit("local.get $arr_ptr\n");
        try self.emitIndent();
        try self.emit("i32.const 8\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.get $i\n");
        try self.emitIndent();
        try self.emit("i32.const 4\n");
        try self.emitIndent();
        try self.emit("i32.mul\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("i32.load  ;; current element\n");

        // Apply reducer: acc = fn(acc, element)
        // TODO: proper function call
        // For now: acc = acc + element (simple sum)
        try self.emitIndent();
        try self.emit("local.get $acc\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.set $acc\n");

        // Increment i
        try self.emitIndent();
        try self.emit("local.get $i\n");
        try self.emitIndent();
        try self.emit("i32.const 1\n");
        try self.emitIndent();
        try self.emit("i32.add\n");
        try self.emitIndent();
        try self.emit("local.set $i\n");

        // Loop back
        try self.emitIndent();
        try self.emit("br $reduce_loop\n");
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit("end\n");
        self.indent_level -= 1;
        try self.emitIndent();
        try self.emit(")\n");

        // Return accumulator
        try self.emitIndent();
        try self.emit("local.get $acc\n");
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

