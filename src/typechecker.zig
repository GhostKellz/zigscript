const std = @import("std");
const ast = @import("ast.zig");
const module_resolver = @import("module_resolver.zig");

pub const TypeError = error{
    TypeMismatch,
    UndefinedVariable,
    UndefinedFunction,
    UndefinedType,
    WrongNumberOfArguments,
    InvalidOperation,
    OutOfMemory,
};

pub const TypeInfo = struct {
    type_def: ast.Type,
    is_mutable: bool,
};

pub const FunctionSignature = struct {
    params: []ast.FnParam,
    return_type: ?ast.Type,
    is_async: bool,
};

pub const TypeChecker = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    scopes: std.ArrayList(Scope),
    current_function: ?*ast.FnDecl,
    types: std.StringHashMap(ast.Type), // user-defined types
    functions: std.StringHashMap(FunctionSignature), // function signatures

    const Scope = std.StringHashMap(TypeInfo);

    pub fn init(allocator: std.mem.Allocator) TypeChecker {
        const checker = TypeChecker{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .scopes = std.ArrayList(Scope){},
            .current_function = null,
            .types = std.StringHashMap(ast.Type).init(allocator),
            .functions = std.StringHashMap(FunctionSignature).init(allocator),
        };
        return checker;
    }

    pub fn deinit(self: *TypeChecker) void {
        for (self.scopes.items) |*scope| {
            scope.deinit();
        }
        self.scopes.deinit(self.allocator);
        self.types.deinit();
        self.functions.deinit();
        self.arena.deinit();
    }

    pub fn checkModule(self: *TypeChecker, module: *ast.Module) !void {
        // First pass: collect all type and function definitions
        for (module.stmts) |stmt| {
            switch (stmt) {
                .struct_decl => |s| {
                    try self.types.put(s.name, ast.Type{ .user_defined = s.name });
                },
                .enum_decl => |e| {
                    try self.types.put(e.name, ast.Type{ .user_defined = e.name });
                },
                .fn_decl => |fn_decl| {
                    try self.functions.put(fn_decl.name, FunctionSignature{
                        .params = fn_decl.params,
                        .return_type = fn_decl.return_type,
                        .is_async = fn_decl.is_async,
                    });
                },
                else => {},
            }
        }

        // Second pass: check all statements
        try self.beginScope();
        defer self.endScope();

        for (module.stmts) |*stmt| {
            try self.checkStmt(stmt);
        }
    }

    pub fn checkModuleWithImports(self: *TypeChecker, module: *ast.Module, resolver: *module_resolver.ModuleResolver) !void {
        // First pass: Process import statements and add exported symbols to our tables
        for (module.stmts) |stmt| {
            if (stmt == .import_stmt) {
                const import_stmt = stmt.import_stmt;

                // Find the loaded module by searching for paths that end with the import name
                var module_iter = resolver.modules.iterator();
                var loaded_module: ?*module_resolver.Module = null;

                const search_patterns = [_][]const u8{
                    import_stmt.from,
                    try std.fmt.allocPrint(self.allocator, "{s}.zs", .{import_stmt.from}),
                    try std.fmt.allocPrint(self.allocator, "examples/{s}", .{import_stmt.from}),
                    try std.fmt.allocPrint(self.allocator, "examples/{s}.zs", .{import_stmt.from}),
                };

                while (module_iter.next()) |entry| {
                    // Check if the path ends with any of our search patterns
                    for (search_patterns) |pattern| {
                        if (std.mem.endsWith(u8, entry.key_ptr.*, pattern)) {
                            loaded_module = entry.value_ptr;
                            break;
                        }
                    }
                    if (loaded_module != null) break;
                }

                if (loaded_module) |mod| {
                    // Process each imported item
                    for (import_stmt.imports) |item| {
                        // Look up the symbol in the module's exports
                        if (mod.exports.get(item.name)) |export_item| {
                            switch (export_item) {
                                .function => |fn_decl| {
                                    // Add the function to our function table
                                    try self.functions.put(fn_decl.name, FunctionSignature{
                                        .params = fn_decl.params,
                                        .return_type = fn_decl.return_type,
                                        .is_async = fn_decl.is_async,
                                    });
                                },
                                .struct_type => |struct_decl| {
                                    // Add the struct type to our types table
                                    try self.types.put(struct_decl.name, ast.Type{ .user_defined = struct_decl.name });
                                },
                                .enum_type => |enum_decl| {
                                    // Add the enum type to our types table
                                    try self.types.put(enum_decl.name, ast.Type{ .user_defined = enum_decl.name });
                                },
                            }
                        } else {
                            std.debug.print("Warning: Symbol '{s}' not found in module '{s}'\n", .{ item.name, import_stmt.from });
                        }
                    }
                } else {
                    std.debug.print("Warning: Module '{s}' not loaded\n", .{import_stmt.from});
                }
            }
        }

        // Then do normal type checking
        try self.checkModule(module);
    }

    fn checkStmt(self: *TypeChecker, stmt: *ast.Stmt) TypeError!void {
        switch (stmt.*) {
            .fn_decl => |*fn_decl| {
                try self.checkFnDecl(fn_decl);
            },
            .let_decl => |*let_decl| {
                try self.checkLetDecl(let_decl);
            },
            .struct_decl => |*struct_decl| {
                try self.checkStructDecl(struct_decl);
            },
            .enum_decl => |*enum_decl| {
                try self.checkEnumDecl(enum_decl);
            },
            .return_stmt => |*ret| {
                try self.checkReturnStmt(ret);
            },
            .if_stmt => |*if_stmt| {
                try self.checkIfStmt(if_stmt);
            },
            .block => |*block| {
                try self.beginScope();
                defer self.endScope();
                for (block.stmts) |*s| {
                    try self.checkStmt(s);
                }
            },
            .expr_stmt => |*expr_stmt| {
                _ = try self.checkExpr(&expr_stmt.expr);
            },
            .import_stmt, .extern_fn_decl => {
                // TODO: Handle imports and extern functions
            },
            .for_stmt => |*for_stmt| {
                // Type check the iterable
                const iterable_type = try self.checkExpr(&for_stmt.iterable);
                _ = iterable_type; // TODO: Verify it's iterable

                // Add iterator variable to new scope
                try self.beginScope();
                defer self.endScope();

                // TODO: Extract element type from iterable
                try self.defineVariable(for_stmt.iterator, ast.Type{ .primitive = .i32 }, false);

                // Check body
                for (for_stmt.body) |*s| {
                    try self.checkStmt(s);
                }
            },
            .while_stmt => |*while_stmt| {
                const cond_type = try self.checkExpr(&while_stmt.condition);
                if (!try self.typesMatch(cond_type, ast.Type{ .primitive = .bool })) {
                    std.debug.print("While condition must be boolean\n", .{});
                    return TypeError.TypeMismatch;
                }

                try self.beginScope();
                defer self.endScope();
                for (while_stmt.body) |*s| {
                    try self.checkStmt(s);
                }
            },
            .break_stmt, .continue_stmt => {
                // TODO: Verify we're inside a loop
            },
        }
    }

    fn checkFnDecl(self: *TypeChecker, fn_decl: *ast.FnDecl) !void {
        try self.beginScope();
        defer self.endScope();

        const old_function = self.current_function;
        self.current_function = fn_decl;
        defer self.current_function = old_function;

        // Add parameters to scope
        for (fn_decl.params) |param| {
            try self.defineVariable(param.name, param.type_annotation, false);
        }

        // Check function body
        for (fn_decl.body) |*stmt| {
            try self.checkStmt(stmt);
        }

        // Verify return type matches
        // TODO: Track and verify all return statements match declared return type
    }

    fn checkLetDecl(self: *TypeChecker, let_decl: anytype) !void {
        var inferred_type: ?ast.Type = null;

        // If there's an initializer, check it
        if (let_decl.initializer) |*initializer| {
            inferred_type = try self.checkExpr(initializer);
        }

        // Determine the final type
        const final_type = if (let_decl.type_annotation) |annotation|
            blk: {
                // If both annotation and initializer exist, verify they match
                if (inferred_type) |inf| {
                    // Allow integer literal coercion: i32 literal can become i64
                    const is_int_coercion = (annotation == .primitive and annotation.primitive == .i64 and
                                              inf == .primitive and inf.primitive == .i32 and
                                              let_decl.initializer != null and let_decl.initializer.? == .integer_literal);

                    if (!is_int_coercion and !try self.typesMatch(annotation, inf)) {
                        std.debug.print("Type mismatch in variable '{s}'\n", .{let_decl.name});
                        return TypeError.TypeMismatch;
                    }
                }
                break :blk annotation;
            }
        else if (inferred_type) |inf|
            inf
        else {
            std.debug.print("Variable '{s}' must have either type annotation or initializer\n", .{let_decl.name});
            return TypeError.TypeMismatch;
        };

        try self.defineVariable(let_decl.name, final_type, !let_decl.is_const);
    }

    fn checkStructDecl(self: *TypeChecker, struct_decl: *ast.StructDecl) !void {
        // Validate field types exist
        for (struct_decl.fields) |field| {
            if (!try self.typeExists(field.type_annotation)) {
                std.debug.print("Unknown type in struct '{s}' field '{s}'\n", .{ struct_decl.name, field.name });
                return TypeError.UndefinedType;
            }
        }
    }

    fn checkEnumDecl(self: *TypeChecker, enum_decl: *ast.EnumDecl) !void {
        // Validate variant field types exist
        for (enum_decl.variants) |variant| {
            if (variant.fields) |fields| {
                for (fields) |field| {
                    if (!try self.typeExists(field.type_annotation)) {
                        std.debug.print("Unknown type in enum '{s}' variant '{s}' field '{s}'\n", .{ enum_decl.name, variant.name, field.name });
                        return TypeError.UndefinedType;
                    }
                }
            }
        }
    }

    fn checkReturnStmt(self: *TypeChecker, ret: anytype) !void {
        const return_type = if (ret.value) |*val|
            try self.checkExpr(val)
        else
            ast.Type{ .primitive = .void };

        // TODO: Verify return type matches function signature
        _ = return_type;
    }

    fn checkIfStmt(self: *TypeChecker, if_stmt: anytype) !void {
        const cond_type = try self.checkExpr(&if_stmt.condition);

        // Condition must be boolean
        if (!try self.typesMatch(cond_type, ast.Type{ .primitive = .bool })) {
            std.debug.print("If condition must be boolean\n", .{});
            return TypeError.TypeMismatch;
        }

        // Check then block
        try self.beginScope();
        for (if_stmt.then_block) |*stmt| {
            try self.checkStmt(stmt);
        }
        self.endScope();

        // Check else block
        if (if_stmt.else_block) |else_block| {
            try self.beginScope();
            for (else_block) |*stmt| {
                try self.checkStmt(stmt);
            }
            self.endScope();
        }
    }

    fn checkExpr(self: *TypeChecker, expr: *ast.Expr) TypeError!ast.Type {
        return switch (expr.*) {
            .integer_literal => ast.Type{ .primitive = .i32 },
            .float_literal => ast.Type{ .primitive = .f64 },
            .string_literal => ast.Type{ .primitive = .string },
            .bool_literal => ast.Type{ .primitive = .bool },

            .identifier => |id| blk: {
                const var_type = try self.lookupVariable(id.name);
                break :blk var_type.type_def;
            },

            .binary => |*bin| blk: {
                const left_type = try self.checkExpr(bin.left);
                const right_type = try self.checkExpr(bin.right);

                // Type checking for binary operations
                switch (bin.operator) {
                    .add, .subtract, .multiply, .divide, .modulo => {
                        if (!try self.isNumericType(left_type) or !try self.isNumericType(right_type)) {
                            return TypeError.TypeMismatch;
                        }
                        // For simplicity, return left type (should do proper numeric coercion)
                        break :blk left_type;
                    },
                    .equal, .not_equal, .less_than, .less_equal, .greater_than, .greater_equal => {
                        if (!try self.typesMatch(left_type, right_type)) {
                            return TypeError.TypeMismatch;
                        }
                        break :blk ast.Type{ .primitive = .bool };
                    },
                    .logical_and, .logical_or => {
                        if (!try self.typesMatch(left_type, ast.Type{ .primitive = .bool }) or
                            !try self.typesMatch(right_type, ast.Type{ .primitive = .bool }))
                        {
                            return TypeError.TypeMismatch;
                        }
                        break :blk ast.Type{ .primitive = .bool };
                    },
                    .null_coalesce => {
                        // TODO: Proper optional type handling
                        break :blk left_type;
                    },
                    .bitwise_and, .bitwise_or, .bitwise_xor => {
                        if (!try self.isIntegerType(left_type) or !try self.isIntegerType(right_type)) {
                            return TypeError.TypeMismatch;
                        }
                        break :blk left_type;
                    },
                }
            },

            .unary => |*un| blk: {
                const operand_type = try self.checkExpr(un.operand);

                switch (un.operator) {
                    .negate => {
                        if (!try self.isNumericType(operand_type)) {
                            return TypeError.TypeMismatch;
                        }
                        break :blk operand_type;
                    },
                    .not => {
                        if (!try self.typesMatch(operand_type, ast.Type{ .primitive = .bool })) {
                            return TypeError.TypeMismatch;
                        }
                        break :blk ast.Type{ .primitive = .bool };
                    },
                    .bitwise_not => {
                        if (!try self.isIntegerType(operand_type)) {
                            return TypeError.TypeMismatch;
                        }
                        break :blk operand_type;
                    },
                }
            },

            .call => |*call| blk: {
                // Check if callee is a variable with function type (lambda)
                if (call.callee.* == .identifier) {
                    const id = call.callee.identifier;
                    if (self.lookupVariable(id.name)) |var_info| {
                        if (var_info.type_def == .function) {
                            const fn_type = var_info.type_def.function;

                            // Check argument count
                            if (call.args.len != fn_type.params.len) {
                                return TypeError.WrongNumberOfArguments;
                            }

                            // Check argument types
                            for (call.args, 0..) |*arg, i| {
                                const arg_type = try self.checkExpr(arg);
                                if (!try self.typesMatch(arg_type, fn_type.params[i])) {
                                    return TypeError.TypeMismatch;
                                }
                            }

                            // Return function's return type
                            break :blk fn_type.return_type.*;
                        }
                    } else |_| {
                        // Not a variable, might be a declared function
                    }
                }

                // Get function name from callee (assume it's an identifier for now)
                const fn_name = switch (call.callee.*) {
                    .identifier => |id| id.name,
                    else => {
                        // For complex callees (member access, etc), just check the expression
                        _ = try self.checkExpr(call.callee);
                        // Check arguments
                        for (call.args) |*arg| {
                            _ = try self.checkExpr(arg);
                        }
                        break :blk ast.Type{ .primitive = .void };
                    },
                };

                // Look up function signature
                const fn_sig = self.functions.get(fn_name) orelse {
                    std.debug.print("Undefined function: {s}\n", .{fn_name});
                    return TypeError.UndefinedFunction;
                };

                // Check argument count
                if (call.args.len != fn_sig.params.len) {
                    std.debug.print("Function '{s}' expects {d} arguments, got {d}\n", .{ fn_name, fn_sig.params.len, call.args.len });
                    return TypeError.WrongNumberOfArguments;
                }

                // Check argument types
                for (call.args, 0..) |*arg, i| {
                    const arg_type = try self.checkExpr(arg);
                    const param_type = fn_sig.params[i].type_annotation;

                    // Allow integer literal coercion: i32 literal can become i64
                    const is_int_coercion = (param_type == .primitive and param_type.primitive == .i64 and
                                              arg_type == .primitive and arg_type.primitive == .i32 and
                                              arg.* == .integer_literal);

                    if (!is_int_coercion and !try self.typesMatch(arg_type, param_type)) {
                        std.debug.print("Argument {d} type mismatch in call to '{s}'\n", .{ i, fn_name });
                        return TypeError.TypeMismatch;
                    }
                }

                // Return function's return type
                const return_type = fn_sig.return_type orelse ast.Type{ .primitive = .void };

                // If async function, wrap return type in Promise<T>
                if (fn_sig.is_async) {
                    const promise_inner = try self.arena.allocator().create(ast.Type);
                    promise_inner.* = return_type;
                    break :blk ast.Type{ .promise = promise_inner };
                } else {
                    break :blk return_type;
                }
            },

            .member_access => |*member| blk: {
                const object_type = try self.checkExpr(member.object);
                // TODO: Lookup member type in struct/object
                _ = object_type;
                _ = member.member;
                break :blk ast.Type{ .primitive = .void }; // placeholder
            },

            .index_access => |*index| blk: {
                const object_type = try self.checkExpr(index.object);
                const index_type = try self.checkExpr(index.index);

                // Index must be integer
                if (!try self.isIntegerType(index_type)) {
                    return TypeError.TypeMismatch;
                }

                // TODO: Extract element type from array/map
                _ = object_type;
                break :blk ast.Type{ .primitive = .void }; // placeholder
            },

            .array_literal => |*array| blk: {
                if (array.elements.len == 0) {
                    break :blk ast.Type{ .primitive = .void }; // empty array, type unknown
                }

                // Check all elements have the same type
                const first_type = try self.checkExpr(&array.elements[0]);
                for (array.elements[1..]) |*elem| {
                    const elem_type = try self.checkExpr(elem);
                    if (!try self.typesMatch(first_type, elem_type)) {
                        return TypeError.TypeMismatch;
                    }
                }

                // Return array type
                const elem_type_ptr = try self.arena.allocator().create(ast.Type);
                elem_type_ptr.* = first_type;
                break :blk ast.Type{ .array = elem_type_ptr };
            },

            .struct_literal => |s| blk: {
                // TODO: Verify struct type exists and fields match
                break :blk ast.Type{ .user_defined = s.type_name };
            },

            .await_expr => |*await_expr| blk: {
                const expr_type = try self.checkExpr(await_expr.expr);

                // Verify expression is a Promise<T> and extract T
                switch (expr_type) {
                    .promise => |inner_type| {
                        break :blk inner_type.*;
                    },
                    else => {
                        std.debug.print("await expression expects Promise<T>, got non-promise type\n", .{});
                        return TypeError.TypeMismatch;
                    },
                }
            },

            .try_expr => |*try_expr| blk: {
                const expr_type = try self.checkExpr(try_expr.expr);

                // Verify expression is a Result<T, E> and extract T (the Ok type)
                switch (expr_type) {
                    .result => |result_info| {
                        // Return the Ok type (unwrap the Result)
                        break :blk result_info.ok_type.*;
                    },
                    else => {
                        std.debug.print("? operator expects Result<T,E>, got non-result type\n", .{});
                        return TypeError.TypeMismatch;
                    },
                }
            },

            .string_interpolation => |*interp| blk: {
                for (interp.parts) |*part| {
                    switch (part.*) {
                        .expr => |*e| {
                            _ = try self.checkExpr(e);
                        },
                        .text => {},
                    }
                }
                break :blk ast.Type{ .primitive = .string };
            },

            .match_expr => |*match_expr| blk: {
                const value_type = try self.checkExpr(match_expr.value);

                // Check all arms and ensure they return the same type
                if (match_expr.arms.len == 0) {
                    std.debug.print("Match expression must have at least one arm\n", .{});
                    return TypeError.InvalidOperation;
                }

                // Get the return type from the first arm
                const return_type = try self.checkExpr(&match_expr.arms[0].body);

                // Verify all other arms return the same type
                for (match_expr.arms[1..]) |*arm| {
                    const arm_type = try self.checkExpr(&arm.body);
                    if (!try self.typesMatch(return_type, arm_type)) {
                        std.debug.print("Match arms must all return the same type\n", .{});
                        return TypeError.TypeMismatch;
                    }
                }

                _ = value_type; // TODO: Verify patterns match value type
                break :blk return_type;
            },

            .assign_expr => |*assign| blk: {
                // Type check based on target type
                const target_type = switch (assign.target.*) {
                    .identifier => |id| blk2: {
                        // Look up existing variable
                        const var_info = try self.lookupVariable(id.name);

                        // Check if variable is mutable
                        if (!var_info.is_mutable) {
                            std.debug.print("Cannot assign to const variable: {s}\n", .{id.name});
                            return TypeError.InvalidOperation;
                        }
                        break :blk2 var_info.type_def;
                    },
                    .index_access => |*idx| blk2: {
                        // arr[i] = value
                        const arr_type = try self.checkExpr(idx.object);
                        const index_type = try self.checkExpr(idx.index);

                        // Verify index is i32
                        if (!try self.typesMatch(index_type, ast.Type{ .primitive = .i32 })) {
                            std.debug.print("Array index must be i32\n", .{});
                            return TypeError.TypeMismatch;
                        }

                        // Extract element type from array
                        const elem_type = switch (arr_type) {
                            .array => |*elem_ptr| elem_ptr.*,
                            else => {
                                std.debug.print("Index access requires array type\n", .{});
                                return TypeError.TypeMismatch;
                            },
                        };
                        break :blk2 elem_type.*;
                    },
                    else => {
                        std.debug.print("Invalid assignment target\n", .{});
                        return TypeError.InvalidOperation;
                    },
                };

                // Type check the value
                const value_type = try self.checkExpr(assign.value);

                // Ensure types match
                if (!try self.typesMatch(target_type, value_type)) {
                    std.debug.print("Assignment type mismatch\n", .{});
                    return TypeError.TypeMismatch;
                }

                // Assignment expression returns the assigned value's type
                break :blk value_type;
            },

            .lambda => |*lambda| blk: {
                // Create function type for lambda
                var param_types = try self.arena.allocator().alloc(ast.Type, lambda.params.len);
                for (lambda.params, 0..) |param, i| {
                    param_types[i] = param.type_annotation;
                }

                // Create new scope for lambda parameters
                try self.beginScope();
                defer self.endScope();

                // Register lambda parameters in scope
                for (lambda.params) |param| {
                    try self.defineVariable(param.name, param.type_annotation, false);
                }

                // Determine return type from body
                const return_type = if (lambda.return_type) |ret_type| blk2: {
                    const ret_ptr = try self.arena.allocator().create(ast.Type);
                    ret_ptr.* = ret_type;
                    break :blk2 ret_ptr;
                } else blk2: {
                    // Infer return type from body
                    const inferred = switch (lambda.body) {
                        .expression => |expr_ptr| try self.checkExpr(expr_ptr),
                        .block => |stmts| blk3: {
                            // Check for return statements in block
                            for (stmts) |*stmt| {
                                try self.checkStmt(stmt);
                            }
                            break :blk3 ast.Type{ .primitive = .void };
                        },
                    };
                    const ret_ptr = try self.arena.allocator().create(ast.Type);
                    ret_ptr.* = inferred;
                    break :blk2 ret_ptr;
                };

                break :blk ast.Type{
                    .function = .{
                        .params = param_types,
                        .return_type = return_type,
                        .is_async = false,
                    },
                };
            },
        };
    }

    // Helper functions

    fn beginScope(self: *TypeChecker) !void {
        try self.scopes.append(self.allocator, Scope.init(self.allocator));
    }

    fn endScope(self: *TypeChecker) void {
        if (self.scopes.pop()) |scope| {
            var mutable_scope = scope;
            mutable_scope.deinit();
        }
    }

    fn defineVariable(self: *TypeChecker, name: []const u8, type_def: ast.Type, is_mutable: bool) !void {
        if (self.scopes.items.len == 0) return;

        const current_scope = &self.scopes.items[self.scopes.items.len - 1];
        try current_scope.put(name, TypeInfo{
            .type_def = type_def,
            .is_mutable = is_mutable,
        });
    }

    fn lookupVariable(self: *TypeChecker, name: []const u8) !TypeInfo {
        var i: usize = self.scopes.items.len;
        while (i > 0) {
            i -= 1;
            const scope = &self.scopes.items[i];
            if (scope.get(name)) |type_info| {
                return type_info;
            }
        }

        std.debug.print("Undefined variable: {s}\n", .{name});
        return TypeError.UndefinedVariable;
    }

    fn typesMatch(self: *TypeChecker, a: ast.Type, b: ast.Type) TypeError!bool {
        // Simple type matching for now
        return switch (a) {
            .primitive => |pa| switch (b) {
                .primitive => |pb| pa == pb,
                else => false,
            },
            .user_defined => |na| switch (b) {
                .user_defined => |nb| std.mem.eql(u8, na, nb),
                else => false,
            },
            .array => |ea| switch (b) {
                .array => |eb| try self.typesMatch(ea.*, eb.*),
                else => false,
            },
            .promise => |pa| switch (b) {
                .promise => |pb| try self.typesMatch(pa.*, pb.*),
                else => false,
            },
            .optional => |oa| switch (b) {
                .optional => |ob| try self.typesMatch(oa.*, ob.*),
                else => false,
            },
            else => false, // TODO: Handle result, map, function, generic types
        };
    }

    fn typeExists(self: *TypeChecker, type_def: ast.Type) !bool {
        return switch (type_def) {
            .primitive => true,
            .user_defined => |name| self.types.contains(name),
            .array => |elem_type| try self.typeExists(elem_type.*),
            .promise => |inner_type| try self.typeExists(inner_type.*),
            .optional => |inner_type| try self.typeExists(inner_type.*),
            else => true, // TODO: Complete validation for result, map, function, generic
        };
    }

    fn isNumericType(self: *TypeChecker, type_def: ast.Type) !bool {
        _ = self;
        return switch (type_def) {
            .primitive => |p| switch (p) {
                .i32, .i64, .u32, .u64, .f64 => true,
                else => false,
            },
            else => false,
        };
    }

    fn isIntegerType(self: *TypeChecker, type_def: ast.Type) !bool {
        _ = self;
        return switch (type_def) {
            .primitive => |p| switch (p) {
                .i32, .i64, .u32, .u64 => true,
                else => false,
            },
            else => false,
        };
    }
};
