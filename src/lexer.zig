const std = @import("std");

pub const TokenType = enum {
    // Literals
    identifier,
    integer,
    float,
    string,

    // Keywords
    kw_fn,
    kw_let,
    kw_const,
    kw_if,
    kw_else,
    kw_return,
    kw_async,
    kw_extern,
    kw_await,
    kw_struct,
    kw_enum,
    kw_import,
    kw_from,
    kw_export,
    kw_extern,
    kw_match,
    kw_for,
    kw_in,
    kw_while,
    kw_break,
    kw_continue,
    kw_true,
    kw_false,
    kw_void,
    kw_bool,
    kw_i32,
    kw_i64,
    kw_u32,
    kw_u64,
    kw_f64,
    kw_string,
    kw_bytes,

    // Operators
    plus,
    minus,
    star,
    slash,
    percent,
    ampersand,
    pipe,
    caret,
    tilde,
    bang,
    equal,
    equal_equal,
    bang_equal,
    less,
    less_equal,
    greater,
    greater_equal,
    ampersand_ampersand,
    pipe_pipe,
    question,
    question_question, // ?? null coalescing

    // Delimiters
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    left_bracket,
    right_bracket,
    comma,
    dot,
    colon,
    semicolon,
    arrow, // ->
    fat_arrow, // =>

    // Special
    eof,
    invalid,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
    column: usize,
};

pub const Lexer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: usize,
    column: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return .{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
            .column = 1,
            .allocator = allocator,
        };
    }

    pub fn nextToken(self: *Lexer) !Token {
        self.skipWhitespaceAndComments();

        if (self.isAtEnd()) {
            return self.makeToken(.eof);
        }

        self.start = self.current;
        const c = self.advance();

        // Identifiers and keywords
        if (isAlpha(c)) {
            return self.identifier();
        }

        // Numbers
        if (isDigit(c)) {
            return self.number();
        }

        return switch (c) {
            '(' => self.makeToken(.left_paren),
            ')' => self.makeToken(.right_paren),
            '{' => self.makeToken(.left_brace),
            '}' => self.makeToken(.right_brace),
            '[' => self.makeToken(.left_bracket),
            ']' => self.makeToken(.right_bracket),
            ',' => self.makeToken(.comma),
            '.' => self.makeToken(.dot),
            ';' => self.makeToken(.semicolon),
            ':' => self.makeToken(.colon),
            '~' => self.makeToken(.tilde),
            '^' => self.makeToken(.caret),
            '%' => self.makeToken(.percent),
            '+' => self.makeToken(.plus),
            '*' => self.makeToken(.star),
            '/' => self.makeToken(.slash),
            '-' => if (self.match('>')) self.makeToken(.arrow) else self.makeToken(.minus),
            '=' => if (self.match('=')) self.makeToken(.equal_equal) else if (self.match('>')) self.makeToken(.fat_arrow) else self.makeToken(.equal),
            '!' => if (self.match('=')) self.makeToken(.bang_equal) else self.makeToken(.bang),
            '<' => if (self.match('=')) self.makeToken(.less_equal) else self.makeToken(.less),
            '>' => if (self.match('=')) self.makeToken(.greater_equal) else self.makeToken(.greater),
            '&' => if (self.match('&')) self.makeToken(.ampersand_ampersand) else self.makeToken(.ampersand),
            '|' => if (self.match('|')) self.makeToken(.pipe_pipe) else self.makeToken(.pipe),
            '?' => if (self.match('?')) self.makeToken(.question_question) else self.makeToken(.question),
            '"' => self.string(),
            else => self.makeToken(.invalid),
        };
    }

    fn isAtEnd(self: *const Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        self.column += 1;
        return c;
    }

    fn peek(self: *const Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }

    fn peekNext(self: *const Lexer) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        self.column += 1;
        return true;
    }

    fn skipWhitespaceAndComments(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            switch (c) {
                ' ', '\r', '\t' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    self.column = 0;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        // Single-line comment
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            _ = self.advance();
                        }
                    } else if (self.peekNext() == '*') {
                        // Multi-line comment
                        _ = self.advance(); // consume '/'
                        _ = self.advance(); // consume '*'
                        while (!self.isAtEnd()) {
                            if (self.peek() == '*' and self.peekNext() == '/') {
                                _ = self.advance(); // consume '*'
                                _ = self.advance(); // consume '/'
                                break;
                            }
                            if (self.peek() == '\n') {
                                self.line += 1;
                                self.column = 0;
                            }
                            _ = self.advance();
                        }
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn identifier(self: *Lexer) Token {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        return self.makeToken(self.identifierType());
    }

    fn identifierType(self: *const Lexer) TokenType {
        const lexeme = self.source[self.start..self.current];
        const keywords = std.StaticStringMap(TokenType).initComptime(.{
            .{ "fn", .kw_fn },
            .{ "let", .kw_let },
            .{ "const", .kw_const },
            .{ "if", .kw_if },
            .{ "else", .kw_else },
            .{ "return", .kw_return },
            .{ "async", .kw_async },
            .{ "extern", .kw_extern },
            .{ "await", .kw_await },
            .{ "struct", .kw_struct },
            .{ "enum", .kw_enum },
            .{ "import", .kw_import },
            .{ "from", .kw_from },
            .{ "export", .kw_export },
            .{ "extern", .kw_extern },
            .{ "match", .kw_match },
            .{ "for", .kw_for },
            .{ "in", .kw_in },
            .{ "while", .kw_while },
            .{ "break", .kw_break },
            .{ "continue", .kw_continue },
            .{ "true", .kw_true },
            .{ "false", .kw_false },
            .{ "void", .kw_void },
            .{ "bool", .kw_bool },
            .{ "i32", .kw_i32 },
            .{ "i64", .kw_i64 },
            .{ "u32", .kw_u32 },
            .{ "u64", .kw_u64 },
            .{ "f64", .kw_f64 },
            .{ "string", .kw_string },
            .{ "bytes", .kw_bytes },
        });
        return keywords.get(lexeme) orelse .identifier;
    }

    fn number(self: *Lexer) Token {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // Look for decimal part
        if (self.peek() == '.' and isDigit(self.peekNext())) {
            _ = self.advance(); // consume '.'
            while (isDigit(self.peek())) {
                _ = self.advance();
            }
            return self.makeToken(.float);
        }

        return self.makeToken(.integer);
    }

    fn string(self: *Lexer) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 0;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            return self.makeToken(.invalid);
        }

        _ = self.advance(); // closing "
        return self.makeToken(.string);
    }

    fn makeToken(self: *const Lexer, token_type: TokenType) Token {
        const len = self.current - self.start;
        return .{
            .type = token_type,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
            .column = if (self.column >= len) self.column - len else 1,
        };
    }
};

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

test "lexer basic tokens" {
    const allocator = std.testing.allocator;
    const source = "fn main() { let x = 42; }";
    var lexer = Lexer.init(allocator, source);

    const token1 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.kw_fn, token1.type);

    const token2 = try lexer.nextToken();
    try std.testing.expectEqual(TokenType.identifier, token2.type);
    try std.testing.expectEqualStrings("main", token2.lexeme);
}
