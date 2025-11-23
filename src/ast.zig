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
        // TODO: Deep cleanup of all allocated nodes
        self.allocator.free(self.stmts);
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
