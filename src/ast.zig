const std = @import("std");

pub const SourceLocation = struct {
    line: usize,
    column: usize,
};

// Type representations
pub const Type = union(enum) {
    primitive: PrimitiveType,
    optional: *Type,
    result: struct {
        ok_type: *Type,
        err_type: *Type,
    },
    promise: *Type, // Promise<T> for async values
    array: *Type,
    map: struct {
        key_type: *Type,
        value_type: *Type,
    },
    function: struct {
        params: []Type,
        return_type: *Type,
        is_async: bool,
    },
    user_defined: []const u8, // struct or enum name
    generic: struct {
        name: []const u8,
        type_params: []Type,
    },
};

pub const PrimitiveType = enum {
    void,
    bool,
    i32,
    i64,
    u32,
    u64,
    f64,
    string,
    bytes,
};

// Expressions
pub const Expr = union(enum) {
    integer_literal: struct {
        value: i64,
        loc: SourceLocation,
    },
    float_literal: struct {
        value: f64,
        loc: SourceLocation,
    },
    string_literal: struct {
        value: []const u8,
        loc: SourceLocation,
    },
    bool_literal: struct {
        value: bool,
        loc: SourceLocation,
    },
    identifier: struct {
        name: []const u8,
        loc: SourceLocation,
    },
    binary: struct {
        left: *Expr,
        operator: BinaryOp,
        right: *Expr,
        loc: SourceLocation,
    },
    unary: struct {
        operator: UnaryOp,
        operand: *Expr,
        loc: SourceLocation,
    },
    call: struct {
        callee: *Expr,
        args: []Expr,
        loc: SourceLocation,
    },
    member_access: struct {
        object: *Expr,
        member: []const u8,
        loc: SourceLocation,
    },
    index_access: struct {
        object: *Expr,
        index: *Expr,
        loc: SourceLocation,
    },
    array_literal: struct {
        elements: []Expr,
        loc: SourceLocation,
    },
    struct_literal: struct {
        type_name: []const u8,
        fields: []StructField,
        loc: SourceLocation,
    },
    await_expr: struct {
        expr: *Expr,
        loc: SourceLocation,
    },
    try_expr: struct {
        expr: *Expr,
        loc: SourceLocation,
    },
    string_interpolation: StringInterpolation,
    match_expr: struct {
        value: *Expr,
        arms: []MatchArm,
        loc: SourceLocation,
    },
    assign_expr: struct {
        target: *Expr,  // identifier or member_access
        value: *Expr,
        loc: SourceLocation,
    },
    lambda: struct {
        params: []FnParam,
        return_type: ?Type,
        body: LambdaBody,
        loc: SourceLocation,
    },

    pub const LambdaBody = union(enum) {
        expression: *Expr,  // fn(x) => x * 2
        block: []Stmt,      // fn(x) { return x * 2; }
    };

    pub const StructField = struct {
        name: []const u8,
        value: Expr,
    };

    pub const StringPart = union(enum) {
        text: []const u8,
        expr: Expr,
    };

    pub const StringPartList = std.ArrayList(StringPart);

    pub const StringInterpolation = struct {
        parts: []StringPart,
        loc: SourceLocation,
    };

    pub const MatchArm = struct {
        pattern: Pattern,
        body: Expr,
    };
};

pub const Pattern = union(enum) {
    wildcard, // _
    identifier: []const u8,
    literal: Expr,
    enum_variant: struct {
        name: []const u8,
        payload: ?*Pattern,
    },
};

pub const BinaryOp = enum {
    add,
    subtract,
    multiply,
    divide,
    modulo,
    equal,
    not_equal,
    less_than,
    less_equal,
    greater_than,
    greater_equal,
    logical_and,
    logical_or,
    null_coalesce,
    bitwise_and,
    bitwise_or,
    bitwise_xor,
};

pub const UnaryOp = enum {
    negate,
    not,
    bitwise_not,
};

// Statements
pub const Stmt = union(enum) {
    expr_stmt: struct {
        expr: Expr,
        loc: SourceLocation,
    },
    let_decl: struct {
        name: []const u8,
        type_annotation: ?Type,
        initializer: ?Expr,
        is_const: bool,
        loc: SourceLocation,
    },
    fn_decl: FnDecl,
    extern_fn_decl: struct {
        name: []const u8,
        params: []FnParam,
        return_type: ?Type,
        module: []const u8,  // eg "env", "nexus"
        import_name: []const u8,  // eg "custom_fn"
        loc: SourceLocation,
    },
    struct_decl: StructDecl,
    enum_decl: EnumDecl,
    return_stmt: struct {
        value: ?Expr,
        loc: SourceLocation,
    },
    if_stmt: struct {
        condition: Expr,
        then_block: []Stmt,
        else_block: ?[]Stmt,
        loc: SourceLocation,
    },
    block: struct {
        stmts: []Stmt,
        loc: SourceLocation,
    },
    import_stmt: struct {
        imports: []ImportItem,
        from: []const u8,
        loc: SourceLocation,
    },
    for_stmt: struct {
        iterator: []const u8,
        iterable: Expr,
        body: []Stmt,
        loc: SourceLocation,
    },
    while_stmt: struct {
        condition: Expr,
        body: []Stmt,
        loc: SourceLocation,
    },
    break_stmt: struct {
        loc: SourceLocation,
    },
    continue_stmt: struct {
        loc: SourceLocation,
    },
};

pub const FnDecl = struct {
    name: []const u8,
    params: []FnParam,
    return_type: ?Type,
    body: []Stmt,
    is_async: bool,
    is_export: bool,
    loc: SourceLocation,
};

pub const FnParam = struct {
    name: []const u8,
    type_annotation: Type,
};

pub const StructDecl = struct {
    name: []const u8,
    fields: []StructField,
    methods: []FnDecl,
    is_export: bool,
    loc: SourceLocation,

    pub const StructField = struct {
        name: []const u8,
        type_annotation: Type,
    };
};

pub const EnumDecl = struct {
    name: []const u8,
    variants: []EnumVariant,
    is_export: bool,
    loc: SourceLocation,

    pub const EnumVariant = struct {
        name: []const u8,
        fields: ?[]StructDecl.StructField,
    };
};

pub const ImportItem = struct {
    name: []const u8,
    alias: ?[]const u8,
};

// Root AST node
pub const Module = struct {
    stmts: []Stmt,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Module) void {
        // Deep cleanup of all allocated nodes
        for (self.stmts) |*stmt| {
            self.freeStmt(stmt);
        }
        self.allocator.free(self.stmts);
    }

    fn freeStmt(self: *Module, stmt: *Stmt) void {
        switch (stmt.*) {
            .expr_stmt => |*es| self.freeExpr(&es.expr),
            .let_decl => |*ld| {
                if (ld.initializer) |*init| self.freeExpr(init);
            },
            .fn_decl => |*fd| {
                for (fd.body) |*s| self.freeStmt(s);
            },
            .struct_decl => |*sd| {
                for (sd.methods) |*m| {
                    for (m.body) |*s| self.freeStmt(s);
                }
            },
            .return_stmt => |*rs| {
                if (rs.value) |*v| self.freeExpr(v);
            },
            .if_stmt => |*is| {
                self.freeExpr(&is.condition);
                for (is.then_block) |*s| self.freeStmt(s);
                if (is.else_block) |eb| {
                    for (eb) |*s| self.freeStmt(s);
                }
            },
            .block => |*b| {
                for (b.stmts) |*s| self.freeStmt(s);
            },
            .for_stmt => |*fs| {
                self.freeExpr(&fs.iterable);
                for (fs.body) |*s| self.freeStmt(s);
            },
            .while_stmt => |*ws| {
                self.freeExpr(&ws.condition);
                for (ws.body) |*s| self.freeStmt(s);
            },
            .enum_decl, .import_stmt, .extern_fn_decl, .break_stmt, .continue_stmt => {},
        }
    }

    fn freeExpr(self: *Module, expr: *Expr) void {
        switch (expr.*) {
            .binary => |*b| {
                self.freeExpr(b.left);
                self.freeExpr(b.right);
                self.allocator.destroy(b.left);
                self.allocator.destroy(b.right);
            },
            .unary => |*u| {
                self.freeExpr(u.operand);
                self.allocator.destroy(u.operand);
            },
            .call => |*c| {
                self.freeExpr(c.callee);
                self.allocator.destroy(c.callee);
                for (c.args) |*a| self.freeExpr(a);
            },
            .member_access => |*ma| {
                self.freeExpr(ma.object);
                self.allocator.destroy(ma.object);
            },
            .index_access => |*ia| {
                self.freeExpr(ia.object);
                self.freeExpr(ia.index);
                self.allocator.destroy(ia.object);
                self.allocator.destroy(ia.index);
            },
            .array_literal => |*al| {
                for (al.elements) |*e| self.freeExpr(e);
            },
            .struct_literal => |*sl| {
                for (sl.fields) |*f| self.freeExpr(&f.value);
            },
            .await_expr => |*ae| {
                self.freeExpr(ae.expr);
                self.allocator.destroy(ae.expr);
            },
            .try_expr => |*te| {
                self.freeExpr(te.expr);
                self.allocator.destroy(te.expr);
            },
            .string_interpolation => |*si| {
                for (si.parts) |*p| {
                    if (p.* == .expr) self.freeExpr(&p.expr);
                }
            },
            .match_expr => |*me| {
                self.freeExpr(me.value);
                self.allocator.destroy(me.value);
                for (me.arms) |*a| self.freeExpr(&a.body);
            },
            .assign_expr => |*ae| {
                self.freeExpr(ae.target);
                self.freeExpr(ae.value);
                self.allocator.destroy(ae.target);
                self.allocator.destroy(ae.value);
            },
            .lambda => |*l| {
                switch (l.body) {
                    .expression => |e| {
                        self.freeExpr(e);
                        self.allocator.destroy(e);
                    },
                    .block => |stmts| {
                        for (stmts) |*s| self.freeStmt(s);
                    },
                }
            },
            // Leaf nodes - no nested allocations
            .integer_literal, .float_literal, .string_literal, .bool_literal, .identifier => {},
        }
    }
};

// AST Builder for easier construction
pub const AstBuilder = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) AstBuilder {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *AstBuilder) void {
        self.arena.deinit();
    }

    pub fn createExpr(self: *AstBuilder, expr: Expr) !*Expr {
        const ptr = try self.arena.allocator().create(Expr);
        ptr.* = expr;
        return ptr;
    }

    pub fn createType(self: *AstBuilder, type_info: Type) !*Type {
        const ptr = try self.arena.allocator().create(Type);
        ptr.* = type_info;
        return ptr;
    }

    pub fn createModule(self: *AstBuilder, stmts: []Stmt) !Module {
        return Module{
            .stmts = stmts,
            .allocator = self.arena.allocator(),
        };
    }
};
