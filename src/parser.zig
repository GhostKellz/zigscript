const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

const Token = lexer.Token;
const TokenType = lexer.TokenType;
const Lexer = lexer.Lexer;

pub const ParseError = error{
    UnexpectedToken,
    OutOfMemory,
    UnexpectedEof,
    InvalidSyntax,
    InvalidCharacter,
    Overflow,
};

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    previous_token: Token,
    ast_builder: ast.AstBuilder,
    had_error: bool,

    pub fn init(allocator: std.mem.Allocator, lex: *Lexer) !Parser {
        var parser = Parser{
            .lexer = lex,
            .current_token = undefined,
            .previous_token = undefined,
            .ast_builder = ast.AstBuilder.init(allocator),
            .had_error = false,
        };
        // Prime the parser with the first token
        parser.current_token = try lex.nextToken();
        return parser;
    }

    pub fn deinit(self: *Parser) void {
        self.ast_builder.deinit();
    }

    pub fn parseModule(self: *Parser) !ast.Module {
        var stmts = std.ArrayList(ast.Stmt).empty;

        while (self.current_token.type != .eof) {
            const stmt = self.parseStmt() catch |err| {
                self.had_error = true;
                self.synchronize();
                return err;
            };
            try stmts.append(self.ast_builder.arena.allocator(), stmt);
        }

        return self.ast_builder.createModule(try stmts.toOwnedSlice(self.ast_builder.arena.allocator()));
    }

    fn parseStmt(self: *Parser) !ast.Stmt {
        return switch (self.current_token.type) {
            .kw_export => self.parseExportDecl(),
            .kw_async => self.parseFnDecl(false), // async fn (not exported)
            .kw_fn => self.parseFnDecl(false),
            .kw_let, .kw_const => self.parseLetDecl(),
            .kw_struct => self.parseStructDecl(false),
            .kw_enum => self.parseEnumDecl(false),
            .kw_extern => self.parseExternFnDecl(),
            .kw_return => self.parseReturnStmt(),
            .kw_if => self.parseIfStmt(),
            .kw_while => self.parseWhileStmt(),
            .kw_for => self.parseForStmt(),
            .kw_break => self.parseBreakStmt(),
            .kw_continue => self.parseContinueStmt(),
            .kw_import => self.parseImportStmt(),
            .left_brace => self.parseBlock(),
            else => self.parseExprStmt(),
        };
    }

    fn parseFnDecl(self: *Parser, is_export: bool) !ast.Stmt {
        const loc = self.location();

        // Check for async keyword
        const is_async = if (self.current_token.type == .kw_async) blk: {
            try self.advance();
            break :blk true;
        } else false;

        try self.consume(.kw_fn, "Expected 'fn'");

        const name = try self.consumeIdentifier("Expected function name");
        try self.consume(.left_paren, "Expected '(' after function name");

        var params = std.ArrayList(ast.FnParam).empty;
        if (self.current_token.type != .right_paren) {
            while (true) {
                const param_name = try self.consumeIdentifierOrKeyword("Expected parameter name");
                try self.consume(.colon, "Expected ':' after parameter name");
                const param_type = try self.parseType();

                try params.append(self.ast_builder.arena.allocator(), .{
                    .name = param_name,
                    .type_annotation = param_type,
                });

                if (self.current_token.type != .comma) break;
                try self.advance();
            }
        }
        try self.consume(.right_paren, "Expected ')' after parameters");

        const return_type = if (self.current_token.type == .arrow) blk: {
            try self.advance();
            break :blk try self.parseType();
        } else null;

        try self.consume(.left_brace, "Expected '{' before function body");
        const body = try self.parseBlockContents();
        try self.consume(.right_brace, "Expected '}' after function body");


        return ast.Stmt{
            .fn_decl = .{
                .name = name,
                .params = try params.toOwnedSlice(self.ast_builder.arena.allocator()),
                .return_type = return_type,
                .body = body,
                .is_async = is_async,
                .is_export = is_export,
                .loc = loc,
            },
        };
    }

    fn parseLetDecl(self: *Parser) !ast.Stmt {
        const loc = self.location();
        const is_const = self.current_token.type == .kw_const;
        try self.advance();

        const name = try self.consumeIdentifier("Expected variable name");

        const type_annotation = if (self.current_token.type == .colon) blk: {
            try self.advance();
            break :blk try self.parseType();
        } else null;

        const initializer = if (self.current_token.type == .equal) blk: {
            try self.advance();
            break :blk try self.parseExpr();
        } else null;

        try self.consume(.semicolon, "Expected ';' after variable declaration");

        return ast.Stmt{
            .let_decl = .{
                .name = name,
                .type_annotation = type_annotation,
                .initializer = initializer,
                .is_const = is_const,
                .loc = loc,
            },
        };
    }

    fn parseStructDecl(self: *Parser, is_export: bool) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_struct, "Expected 'struct'");
        const name = try self.consumeIdentifier("Expected struct name");
        try self.consume(.left_brace, "Expected '{' after struct name");

        var fields = std.ArrayList(ast.StructDecl.StructField).empty;
        var methods = std.ArrayList(ast.FnDecl).empty;

        while (self.current_token.type != .right_brace and self.current_token.type != .eof) {
            // Check if this is a method (starts with 'fn')
            if (self.current_token.type == .kw_fn) {
                const method = try self.parseStructMethod();
                try methods.append(self.ast_builder.arena.allocator(), method);
            } else {
                // It's a field (allow keywords as field names)
                const field_name = try self.consumeIdentifierOrKeyword("Expected field name");
                try self.consume(.colon, "Expected ':' after field name");
                const field_type = try self.parseType();

                try fields.append(self.ast_builder.arena.allocator(), .{
                    .name = field_name,
                    .type_annotation = field_type,
                });

                if (self.current_token.type == .comma) {
                    try self.advance();
                }
            }
        }

        try self.consume(.right_brace, "Expected '}' after struct body");

        return ast.Stmt{
            .struct_decl = .{
                .name = name,
                .fields = try fields.toOwnedSlice(self.ast_builder.arena.allocator()),
                .methods = try methods.toOwnedSlice(self.ast_builder.arena.allocator()),
                .is_export = is_export,
                .loc = loc,
            },
        };
    }

    fn parseStructMethod(self: *Parser) !ast.FnDecl {
        const loc = self.location();
        try self.consume(.kw_fn, "Expected 'fn'");
        const name = try self.consumeIdentifier("Expected method name");
        try self.consume(.left_paren, "Expected '(' after method name");

        var params = std.ArrayList(ast.FnParam).empty;

        // Parse parameters (self is implicit, not in param list)
        while (self.current_token.type != .right_paren and self.current_token.type != .eof) {
            const param_name = try self.consumeIdentifierOrKeyword("Expected parameter name");
            try self.consume(.colon, "Expected ':' after parameter name");
            const param_type = try self.parseType();

            try params.append(self.ast_builder.arena.allocator(), .{
                .name = param_name,
                .type_annotation = param_type,
            });

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.consume(.right_paren, "Expected ')' after parameters");

        const return_type = if (self.current_token.type == .arrow) blk: {
            try self.advance();
            break :blk try self.parseType();
        } else ast.Type{ .primitive = .void };

        const body = try self.parseBlock();

        return ast.FnDecl{
            .name = name,
            .params = try params.toOwnedSlice(self.ast_builder.arena.allocator()),
            .return_type = return_type,
            .body = body.block.stmts,
            .is_async = false,
            .is_export = false,
            .loc = loc,
        };
    }

    fn parseEnumDecl(self: *Parser, is_export: bool) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_enum, "Expected 'enum'");
        const name = try self.consumeIdentifier("Expected enum name");
        try self.consume(.left_brace, "Expected '{' after enum name");

        var variants = std.ArrayList(ast.EnumDecl.EnumVariant).empty;

        while (self.current_token.type != .right_brace and self.current_token.type != .eof) {
            const variant_name = try self.consumeIdentifier("Expected variant name");

            const fields = if (self.current_token.type == .left_paren) blk: {
                try self.advance();
                var variant_fields = std.ArrayList(ast.StructDecl.StructField).empty;

                while (self.current_token.type != .right_paren and self.current_token.type != .eof) {
                    const field_name = try self.consumeIdentifierOrKeyword("Expected field name");
                    try self.consume(.colon, "Expected ':' after field name");
                    const field_type = try self.parseType();

                    try variant_fields.append(self.ast_builder.arena.allocator(), .{
                        .name = field_name,
                        .type_annotation = field_type,
                    });

                    if (self.current_token.type == .comma) {
                        try self.advance();
                    }
                }

                try self.consume(.right_paren, "Expected ')' after variant fields");
                break :blk try variant_fields.toOwnedSlice(self.ast_builder.arena.allocator());
            } else null;

            try variants.append(self.ast_builder.arena.allocator(), .{
                .name = variant_name,
                .fields = fields,
            });

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.consume(.right_brace, "Expected '}' after enum variants");

        return ast.Stmt{
            .enum_decl = .{
                .name = name,
                .variants = try variants.toOwnedSlice(self.ast_builder.arena.allocator()),
                .is_export = is_export,
                .loc = loc,
            },
        };
    }

    fn parseReturnStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_return, "Expected 'return'");

        const value = if (self.current_token.type != .semicolon)
            try self.parseExpr()
        else
            null;

        try self.consume(.semicolon, "Expected ';' after return statement");

        return ast.Stmt{
            .return_stmt = .{
                .value = value,
                .loc = loc,
            },
        };
    }

    fn parseIfStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_if, "Expected 'if'");

        const condition = try self.parseExpr();

        try self.consume(.left_brace, "Expected '{' after if condition");
        const then_block = try self.parseBlockContents();
        try self.consume(.right_brace, "Expected '}' after if block");

        const else_block = if (self.current_token.type == .kw_else) blk: {
            try self.advance();
            try self.consume(.left_brace, "Expected '{' after else");
            const block = try self.parseBlockContents();
            try self.consume(.right_brace, "Expected '}' after else block");
            break :blk block;
        } else null;

        return ast.Stmt{
            .if_stmt = .{
                .condition = condition,
                .then_block = then_block,
                .else_block = else_block,
                .loc = loc,
            },
        };
    }

    fn parseImportStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_import, "Expected 'import'");
        try self.consume(.left_brace, "Expected '{' after import");

        var imports = std.ArrayList(ast.ImportItem).empty;

        while (self.current_token.type != .right_brace and self.current_token.type != .eof) {
            const name = try self.consumeIdentifier("Expected import name");
            try imports.append(self.ast_builder.arena.allocator(), .{
                .name = name,
                .alias = null, // TODO: handle 'as' aliases
            });

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.consume(.right_brace, "Expected '}' after imports");
        try self.consume(.kw_from, "Expected 'from' after import list");

        const from = try self.consumeString("Expected module path");
        try self.consume(.semicolon, "Expected ';' after import statement");

        return ast.Stmt{
            .import_stmt = .{
                .imports = try imports.toOwnedSlice(self.ast_builder.arena.allocator()),
                .from = from,
                .loc = loc,
            },
        };
    }

    fn parseWhileStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_while, "Expected 'while'");

        const condition = try self.parseExpr();

        try self.consume(.left_brace, "Expected '{' after while condition");
        const body = try self.parseBlockContents();
        try self.consume(.right_brace, "Expected '}' after while body");

        return ast.Stmt{
            .while_stmt = .{
                .condition = condition,
                .body = body,
                .loc = loc,
            },
        };
    }

    fn parseForStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_for, "Expected 'for'");

        const iterator = try self.consumeIdentifier("Expected iterator name");
        try self.consume(.kw_in, "Expected 'in' after iterator");

        const iterable = try self.parseExpr();

        try self.consume(.left_brace, "Expected '{' after for iterable");
        const body = try self.parseBlockContents();
        try self.consume(.right_brace, "Expected '}' after for body");

        return ast.Stmt{
            .for_stmt = .{
                .iterator = iterator,
                .iterable = iterable,
                .body = body,
                .loc = loc,
            },
        };
    }

    fn parseBreakStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_break, "Expected 'break'");
        try self.consume(.semicolon, "Expected ';' after break");

        return ast.Stmt{
            .break_stmt = .{
                .loc = loc,
            },
        };
    }

    fn parseContinueStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_continue, "Expected 'continue'");
        try self.consume(.semicolon, "Expected ';' after continue");

        return ast.Stmt{
            .continue_stmt = .{
                .loc = loc,
            },
        };
    }

    fn parseBlock(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.left_brace, "Expected '{'");
        const stmts = try self.parseBlockContents();
        try self.consume(.right_brace, "Expected '}'");

        return ast.Stmt{
            .block = .{
                .stmts = stmts,
                .loc = loc,
            },
        };
    }

    fn parseBlockContents(self: *Parser) ParseError![]ast.Stmt {
        var stmts = std.ArrayList(ast.Stmt).empty;

        while (self.current_token.type != .right_brace and self.current_token.type != .eof) {
            try stmts.append(self.ast_builder.arena.allocator(), try self.parseStmt());
        }

        return stmts.toOwnedSlice(self.ast_builder.arena.allocator());
    }

    fn parseExprStmt(self: *Parser) !ast.Stmt {
        const loc = self.location();
        const expr = try self.parseExpr();
        try self.consume(.semicolon, "Expected ';' after expression");

        return ast.Stmt{
            .expr_stmt = .{
                .expr = expr,
                .loc = loc,
            },
        };
    }

    fn parseExpr(self: *Parser) ParseError!ast.Expr {
        return self.parseAssignment();
    }

    fn parseAssignment(self: *Parser) !ast.Expr {
        var expr = try self.parseNullCoalesce();

        if (self.current_token.type == .equal) {
            const loc = self.location();
            try self.advance();
            const value = try self.parseAssignment(); // Right-associative

            expr = ast.Expr{
                .assign_expr = .{
                    .target = try self.ast_builder.createExpr(expr),
                    .value = try self.ast_builder.createExpr(value),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseNullCoalesce(self: *Parser) !ast.Expr {
        var expr = try self.parseLogicalOr();

        while (self.current_token.type == .question_question) {
            const loc = self.location();
            try self.advance();
            const right = try self.parseLogicalOr();
            expr = ast.Expr{
                .binary = .{
                    .left = try self.ast_builder.createExpr(expr),
                    .operator = .null_coalesce,
                    .right = try self.ast_builder.createExpr(right),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseLogicalOr(self: *Parser) !ast.Expr {
        var expr = try self.parseLogicalAnd();

        while (self.current_token.type == .pipe_pipe) {
            const loc = self.location();
            try self.advance();
            const right = try self.parseLogicalAnd();
            expr = ast.Expr{
                .binary = .{
                    .left = try self.ast_builder.createExpr(expr),
                    .operator = .logical_or,
                    .right = try self.ast_builder.createExpr(right),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseLogicalAnd(self: *Parser) !ast.Expr {
        var expr = try self.parseEquality();

        while (self.current_token.type == .ampersand_ampersand) {
            const loc = self.location();
            try self.advance();
            const right = try self.parseEquality();
            expr = ast.Expr{
                .binary = .{
                    .left = try self.ast_builder.createExpr(expr),
                    .operator = .logical_and,
                    .right = try self.ast_builder.createExpr(right),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseEquality(self: *Parser) !ast.Expr {
        var expr = try self.parseComparison();

        while (true) {
            const op: ast.BinaryOp = switch (self.current_token.type) {
                .equal_equal => .equal,
                .bang_equal => .not_equal,
                else => break,
            };
            const loc = self.location();
            try self.advance();
            const right = try self.parseComparison();
            expr = ast.Expr{
                .binary = .{
                    .left = try self.ast_builder.createExpr(expr),
                    .operator = op,
                    .right = try self.ast_builder.createExpr(right),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseComparison(self: *Parser) !ast.Expr {
        var expr = try self.parseTerm();

        while (true) {
            const op: ast.BinaryOp = switch (self.current_token.type) {
                .less => .less_than,
                .less_equal => .less_equal,
                .greater => .greater_than,
                .greater_equal => .greater_equal,
                else => break,
            };
            const loc = self.location();
            try self.advance();
            const right = try self.parseTerm();
            expr = ast.Expr{
                .binary = .{
                    .left = try self.ast_builder.createExpr(expr),
                    .operator = op,
                    .right = try self.ast_builder.createExpr(right),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseTerm(self: *Parser) !ast.Expr {
        var expr = try self.parseFactor();

        while (true) {
            const op: ast.BinaryOp = switch (self.current_token.type) {
                .plus => .add,
                .minus => .subtract,
                else => break,
            };
            const loc = self.location();
            try self.advance();
            const right = try self.parseFactor();
            expr = ast.Expr{
                .binary = .{
                    .left = try self.ast_builder.createExpr(expr),
                    .operator = op,
                    .right = try self.ast_builder.createExpr(right),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseFactor(self: *Parser) !ast.Expr {
        var expr = try self.parseUnary();

        while (true) {
            const op: ast.BinaryOp = switch (self.current_token.type) {
                .star => .multiply,
                .slash => .divide,
                .percent => .modulo,
                else => break,
            };
            const loc = self.location();
            try self.advance();
            const right = try self.parseUnary();
            expr = ast.Expr{
                .binary = .{
                    .left = try self.ast_builder.createExpr(expr),
                    .operator = op,
                    .right = try self.ast_builder.createExpr(right),
                    .loc = loc,
                },
            };
        }

        return expr;
    }

    fn parseUnary(self: *Parser) !ast.Expr {
        const op: ?ast.UnaryOp = switch (self.current_token.type) {
            .minus => .negate,
            .bang => .not,
            .tilde => .bitwise_not,
            else => null,
        };

        if (op) |unary_op| {
            const loc = self.location();
            try self.advance();
            const operand = try self.parseUnary();
            return ast.Expr{
                .unary = .{
                    .operator = unary_op,
                    .operand = try self.ast_builder.createExpr(operand),
                    .loc = loc,
                },
            };
        }

        return self.parsePostfix();
    }

    fn parsePostfix(self: *Parser) !ast.Expr {
        var expr = try self.parsePrimary();

        while (true) {
            switch (self.current_token.type) {
                .left_paren => {
                    const loc = self.location();
                    try self.advance();
                    var args = std.ArrayList(ast.Expr).empty;

                    if (self.current_token.type != .right_paren) {
                        while (true) {
                            try args.append(self.ast_builder.arena.allocator(), try self.parseExpr());
                            if (self.current_token.type != .comma) break;
                            try self.advance();
                        }
                    }

                    try self.consume(.right_paren, "Expected ')' after arguments");

                    expr = ast.Expr{
                        .call = .{
                            .callee = try self.ast_builder.createExpr(expr),
                            .args = try args.toOwnedSlice(self.ast_builder.arena.allocator()),
                            .loc = loc,
                        },
                    };
                },
                .dot => {
                    const loc = self.location();
                    try self.advance();
                    const member = try self.consumeIdentifierOrKeyword("Expected property name after '.'");
                    expr = ast.Expr{
                        .member_access = .{
                            .object = try self.ast_builder.createExpr(expr),
                            .member = member,
                            .loc = loc,
                        },
                    };
                },
                .left_bracket => {
                    const loc = self.location();
                    try self.advance();
                    const index = try self.parseExpr();
                    try self.consume(.right_bracket, "Expected ']' after index");
                    expr = ast.Expr{
                        .index_access = .{
                            .object = try self.ast_builder.createExpr(expr),
                            .index = try self.ast_builder.createExpr(index),
                            .loc = loc,
                        },
                    };
                },
                .question => {
                    // The ? operator for Result<T,E> unwrapping
                    const loc = self.location();
                    try self.advance();
                    expr = ast.Expr{
                        .try_expr = .{
                            .expr = try self.ast_builder.createExpr(expr),
                            .loc = loc,
                        },
                    };
                },
                else => break,
            }
        }

        return expr;
    }

    fn parsePrimary(self: *Parser) ParseError!ast.Expr {
        const loc = self.location();
        switch (self.current_token.type) {
            .integer => {
                const value = try std.fmt.parseInt(i64, self.current_token.lexeme, 10);
                try self.advance();
                return ast.Expr{
                    .integer_literal = .{
                        .value = value,
                        .loc = loc,
                    },
                };
            },
            .float => {
                const value = try std.fmt.parseFloat(f64, self.current_token.lexeme);
                try self.advance();
                return ast.Expr{
                    .float_literal = .{
                        .value = value,
                        .loc = loc,
                    },
                };
            },
            .string => {
                const full_string = self.current_token.lexeme[1 .. self.current_token.lexeme.len - 1]; // strip quotes

                // Check if string contains interpolation
                if (std.mem.indexOf(u8, full_string, "{") != null) {
                    try self.advance();
                    return try self.parseStringInterpolation(full_string, loc);
                }

                try self.advance();
                return ast.Expr{
                    .string_literal = .{
                        .value = full_string,
                        .loc = loc,
                    },
                };
            },
            .kw_true => {
                try self.advance();
                return ast.Expr{
                    .bool_literal = .{
                        .value = true,
                        .loc = loc,
                    },
                };
            },
            .kw_false => {
                try self.advance();
                return ast.Expr{
                    .bool_literal = .{
                        .value = false,
                        .loc = loc,
                    },
                };
            },
            .kw_self, .identifier => {
                const name = self.current_token.lexeme;
                try self.advance();

                // Check for struct literal: TypeName { field: value }
                // Only treat as struct literal if name starts with uppercase (type name convention)
                const is_type_name = name.len > 0 and name[0] >= 'A' and name[0] <= 'Z';
                if (is_type_name and self.current_token.type == .left_brace) {
                    try self.advance();
                    var fields = std.ArrayList(ast.Expr.StructField).empty;

                    while (self.current_token.type != .right_brace and self.current_token.type != .eof) {
                        const field_name = try self.consumeIdentifierOrKeyword("Expected field name");
                        try self.consume(.colon, "Expected ':'");
                        const field_value = try self.parseExpr();

                        try fields.append(self.ast_builder.arena.allocator(), .{
                            .name = field_name,
                            .value = field_value,
                        });

                        if (self.current_token.type == .comma) {
                            try self.advance();
                        }
                    }

                    try self.consume(.right_brace, "Expected '}'");

                    return ast.Expr{
                        .struct_literal = .{
                            .type_name = name,
                            .fields = try fields.toOwnedSlice(self.ast_builder.arena.allocator()),
                            .loc = loc,
                        },
                    };
                }

                return ast.Expr{
                    .identifier = .{
                        .name = name,
                        .loc = loc,
                    },
                };
            },
            .kw_await => {
                try self.advance();
                const expr = try self.parseExpr();
                return ast.Expr{
                    .await_expr = .{
                        .expr = try self.ast_builder.createExpr(expr),
                        .loc = loc,
                    },
                };
            },
            .left_paren => {
                try self.advance();
                const expr = try self.parseExpr();
                try self.consume(.right_paren, "Expected ')' after expression");
                return expr;
            },
            .left_bracket => {
                try self.advance();
                var elements = std.ArrayList(ast.Expr).empty;

                if (self.current_token.type != .right_bracket) {
                    while (true) {
                        try elements.append(self.ast_builder.arena.allocator(), try self.parseExpr());
                        if (self.current_token.type != .comma) break;
                        try self.advance();
                    }
                }

                try self.consume(.right_bracket, "Expected ']' after array elements");
                return ast.Expr{
                    .array_literal = .{
                        .elements = try elements.toOwnedSlice(self.ast_builder.arena.allocator()),
                        .loc = loc,
                    },
                };
            },
            .kw_fn => {
                return try self.parseLambda();
            },
            else => {
                // Allow keywords as identifiers (for variable/parameter names like 'from', 'to', etc.)
                if (@intFromEnum(self.current_token.type) >= @intFromEnum(lexer.TokenType.kw_fn)) {
                    const name = self.current_token.lexeme;
                    try self.advance();
                    return ast.Expr{
                        .identifier = .{
                            .name = name,
                            .loc = loc,
                        },
                    };
                }
                std.debug.print("Unexpected token: {s}\n", .{@tagName(self.current_token.type)});
                return ParseError.UnexpectedToken;
            },
        }
    }

    fn parseLambda(self: *Parser) !ast.Expr {
        const loc = self.location();
        try self.consume(.kw_fn, "Expected 'fn'");
        try self.consume(.left_paren, "Expected '(' after fn");

        // Parse parameters
        var params = std.ArrayList(ast.FnParam).empty;
        while (self.current_token.type != .right_paren and self.current_token.type != .eof) {
            const param_name = try self.consumeIdentifierOrKeyword("Expected parameter name");

            // Optional type annotation
            var param_type: ast.Type = ast.Type{ .primitive = .i32 }; // default
            if (self.current_token.type == .colon) {
                try self.advance();
                param_type = try self.parseType();
            }

            try params.append(self.ast_builder.arena.allocator(), .{
                .name = param_name,
                .type_annotation = param_type,
            });

            if (self.current_token.type == .comma) {
                try self.advance();
            }
        }

        try self.consume(.right_paren, "Expected ')' after parameters");

        // Optional return type
        var return_type: ?ast.Type = null;
        if (self.current_token.type == .arrow) {
            try self.advance();
            return_type = try self.parseType();
        }

        // Parse body - either => expr or { block }
        const body: ast.Expr.LambdaBody = if (self.current_token.type == .fat_arrow) blk: {
            try self.advance();
            const expr = try self.parseExpr();
            const expr_ptr = try self.ast_builder.createExpr(expr);
            break :blk ast.Expr.LambdaBody{ .expression = expr_ptr };
        } else if (self.current_token.type == .left_brace) blk: {
            try self.advance();
            const stmts = try self.parseBlockContents();
            try self.consume(.right_brace, "Expected '}' after lambda body");
            break :blk ast.Expr.LambdaBody{ .block = stmts };
        } else {
            std.debug.print("Expected '=>' or '{{' after lambda parameters\n", .{});
            return ParseError.InvalidSyntax;
        };

        return ast.Expr{
            .lambda = .{
                .params = try params.toOwnedSlice(self.ast_builder.arena.allocator()),
                .return_type = return_type,
                .body = body,
                .loc = loc,
            },
        };
    }

    fn parseType(self: *Parser) !ast.Type {
        // Handle primitive types
        const prim_type: ?ast.PrimitiveType = switch (self.current_token.type) {
            .kw_void => .void,
            .kw_bool => .bool,
            .kw_i32 => .i32,
            .kw_i64 => .i64,
            .kw_u32 => .u32,
            .kw_u64 => .u64,
            .kw_f64 => .f64,
            .kw_string => .string,
            .kw_bytes => .bytes,
            else => null,
        };

        if (prim_type) |pt| {
            try self.advance();
            return ast.Type{ .primitive = pt };
        }

        // Handle array types [T]
        if (self.current_token.type == .left_bracket) {
            try self.advance();
            const elem_type = try self.parseType();
            try self.consume(.right_bracket, "Expected ']' after array element type");

            const elem_type_ptr = try self.ast_builder.arena.allocator().create(ast.Type);
            elem_type_ptr.* = elem_type;
            return ast.Type{ .array = elem_type_ptr };
        }

        // Handle user-defined types
        if (self.current_token.type == .identifier) {
            const name = self.current_token.lexeme;
            try self.advance();

            // TODO: Handle generic types like Result<T, E>
            return ast.Type{ .user_defined = name };
        }

        return ParseError.InvalidSyntax;
    }

    // Helper functions

    fn advance(self: *Parser) !void {
        self.previous_token = self.current_token;
        self.current_token = try self.lexer.nextToken();
    }

    fn consume(self: *Parser, token_type: TokenType, message: []const u8) !void {
        if (self.current_token.type == token_type) {
            try self.advance();
            return;
        }
        std.debug.print("{s} at line {}, got {s}\n", .{ message, self.current_token.line, @tagName(self.current_token.type) });
        return ParseError.UnexpectedToken;
    }

    fn consumeIdentifier(self: *Parser, message: []const u8) ![]const u8 {
        if (self.current_token.type == .identifier) {
            const name = self.current_token.lexeme;
            try self.advance();
            return name;
        }
        std.debug.print("{s}\n", .{message});
        return ParseError.UnexpectedToken;
    }

    fn consumeIdentifierOrKeyword(self: *Parser, message: []const u8) ![]const u8 {
        // Allow keywords as identifiers (for struct field names, etc.)
        if (self.current_token.type == .identifier or @intFromEnum(self.current_token.type) >= @intFromEnum(lexer.TokenType.kw_fn)) {
            const name = self.current_token.lexeme;
            try self.advance();
            return name;
        }
        std.debug.print("{s}\n", .{message});
        return ParseError.UnexpectedToken;
    }

    fn consumeString(self: *Parser, message: []const u8) ![]const u8 {
        if (self.current_token.type == .string) {
            const value = self.current_token.lexeme[1 .. self.current_token.lexeme.len - 1]; // strip quotes
            try self.advance();
            return value;
        }
        std.debug.print("{s}\n", .{message});
        return ParseError.UnexpectedToken;
    }

    fn location(self: *const Parser) ast.SourceLocation {
        return .{
            .line = self.current_token.line,
            .column = self.current_token.column,
        };
    }

    fn synchronize(self: *Parser) void {
        while (self.current_token.type != .eof) {
            if (self.previous_token.type == .semicolon) return;

            switch (self.current_token.type) {
                .kw_fn, .kw_let, .kw_const, .kw_struct, .kw_enum, .kw_return, .kw_if => return,
                else => {},
            }

            self.advance() catch return;
        }
    }

    fn parseStringInterpolation(self: *Parser, string: []const u8, loc: ast.SourceLocation) !ast.Expr {
        var parts: std.ArrayList(ast.Expr.StringPart) = .empty;
        errdefer parts.deinit(self.ast_builder.allocator);

        var i: usize = 0;
        var current_text_start: usize = 0;

        while (i < string.len) {
            if (string[i] == '{') {
                // Save any text before the interpolation
                if (i > current_text_start) {
                    try parts.append(self.ast_builder.allocator, .{
                        .text = string[current_text_start..i],
                    });
                }

                // Find the closing brace
                var brace_count: usize = 1;
                const expr_start = i + 1;
                i += 1;

                while (i < string.len and brace_count > 0) {
                    if (string[i] == '{') {
                        brace_count += 1;
                    } else if (string[i] == '}') {
                        brace_count -= 1;
                    }
                    if (brace_count > 0) {
                        i += 1;
                    }
                }

                if (brace_count != 0) {
                    return ParseError.InvalidSyntax;
                }

                // Parse the expression inside the braces
                const expr_str = string[expr_start..i];

                // Create a mini-lexer for the expression
                var expr_lexer = Lexer.init(self.ast_builder.allocator, expr_str);
                var expr_parser = try Parser.init(self.ast_builder.allocator, &expr_lexer);
                const expr = try expr_parser.parseExpr();

                try parts.append(self.ast_builder.allocator, .{
                    .expr = expr,
                });

                i += 1; // Skip closing brace
                current_text_start = i;
            } else {
                i += 1;
            }
        }

        // Save any remaining text
        if (current_text_start < string.len) {
            try parts.append(self.ast_builder.allocator, .{
                .text = string[current_text_start..],
            });
        }

        return ast.Expr{
            .string_interpolation = .{
                .parts = try parts.toOwnedSlice(self.ast_builder.allocator),
                .loc = loc,
            },
        };
    }

    fn parseExportDecl(self: *Parser) !ast.Stmt {
        try self.consume(.kw_export, "Expected 'export'");

        // After 'export', we expect fn, struct, or enum
        return switch (self.current_token.type) {
            .kw_async, .kw_fn => self.parseFnDecl(true),
            .kw_struct => self.parseStructDecl(true),
            .kw_enum => self.parseEnumDecl(true),
            else => {
                std.debug.print("Unexpected token after 'export': {}\n", .{self.current_token.type});
                return ParseError.UnexpectedToken;
            },
        };
    }

    fn parseExternFnDecl(self: *Parser) !ast.Stmt {
        const loc = self.location();
        try self.consume(.kw_extern, "Expected 'extern'");
        try self.consume(.kw_fn, "Expected 'fn' after extern");

        const name = try self.consumeIdentifier("Expected function name");
        try self.consume(.left_paren, "Expected '(' after function name");

        var params = std.ArrayList(ast.FnParam).empty;
        if (self.current_token.type != .right_paren) {
            while (true) {
                const param_name = try self.consumeIdentifierOrKeyword("Expected parameter name");
                try self.consume(.colon, "Expected ':' after parameter name");
                const param_type = try self.parseType();

                try params.append(self.ast_builder.arena.allocator(), .{
                    .name = param_name,
                    .type_annotation = param_type,
                });

                if (self.current_token.type != .comma) break;
                try self.advance();
            }
        }
        try self.consume(.right_paren, "Expected ')' after parameters");

        const return_type = if (self.current_token.type == .arrow) blk: {
            try self.advance();
            break :blk try self.parseType();
        } else null;

        try self.consume(.semicolon, "Expected ';' after extern function declaration");

        return ast.Stmt{
            .extern_fn_decl = .{
                .name = name,
                .params = try params.toOwnedSlice(self.ast_builder.arena.allocator()),
                .return_type = return_type,
                .module = "env",  // Default module
                .import_name = name,  // Use same name by default
                .loc = loc,
            },
        };
    }
};
