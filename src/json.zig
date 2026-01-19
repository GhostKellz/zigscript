const std = @import("std");

/// JSON value types
pub const JsonValue = union(enum) {
    null_value,
    bool_value: bool,
    number: f64,
    string: []const u8,
    array: []JsonValue,
    object: std.StringHashMap(JsonValue),

    pub fn deinit(self: *JsonValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .array => |arr| {
                for (arr) |*item| {
                    item.deinit(allocator);
                }
                allocator.free(arr);
            },
            .object => |*obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            .string => |s| allocator.free(s),
            else => {},
        }
    }
};

/// Simple JSON parser
pub const JsonParser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    pos: usize,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) JsonParser {
        return .{
            .allocator = allocator,
            .source = source,
            .pos = 0,
        };
    }

    pub fn parse(self: *JsonParser) !JsonValue {
        self.skipWhitespace();
        return try self.parseValue();
    }

    fn parseValue(self: *JsonParser) !JsonValue {
        self.skipWhitespace();

        if (self.pos >= self.source.len) return error.UnexpectedEnd;

        const c = self.source[self.pos];
        return switch (c) {
            '{' => try self.parseObject(),
            '[' => try self.parseArray(),
            '"' => JsonValue{ .string = try self.parseString() },
            't', 'f' => JsonValue{ .bool_value = try self.parseBool() },
            'n' => try self.parseNull(),
            '-', '0'...'9' => JsonValue{ .number = try self.parseNumber() },
            else => error.InvalidCharacter,
        };
    }

    fn parseObject(self: *JsonParser) !JsonValue {
        var obj = std.StringHashMap(JsonValue).init(self.allocator);

        self.pos += 1; // skip '{'
        self.skipWhitespace();

        if (self.peek() == '}') {
            self.pos += 1;
            return JsonValue{ .object = obj };
        }

        while (true) {
            self.skipWhitespace();

            // Parse key
            if (self.peek() != '"') return error.ExpectedString;
            const key = try self.parseString();

            self.skipWhitespace();
            if (self.peek() != ':') return error.ExpectedColon;
            self.pos += 1;

            // Parse value
            const value = try self.parseValue();
            try obj.put(key, value);

            self.skipWhitespace();
            const next = self.peek();
            if (next == '}') {
                self.pos += 1;
                break;
            } else if (next == ',') {
                self.pos += 1;
            } else {
                return error.ExpectedCommaOrBrace;
            }
        }

        return JsonValue{ .object = obj };
    }

    fn parseArray(self: *JsonParser) !JsonValue {
        var items: std.ArrayList(JsonValue) = .empty;

        self.pos += 1; // skip '['
        self.skipWhitespace();

        if (self.peek() == ']') {
            self.pos += 1;
            return JsonValue{ .array = try items.toOwnedSlice(self.allocator) };
        }

        while (true) {
            const value = try self.parseValue();
            try items.append(self.allocator, value);

            self.skipWhitespace();
            const next = self.peek();
            if (next == ']') {
                self.pos += 1;
                break;
            } else if (next == ',') {
                self.pos += 1;
            } else {
                return error.ExpectedCommaOrBracket;
            }
        }

        return JsonValue{ .array = try items.toOwnedSlice(self.allocator) };
    }

    fn parseString(self: *JsonParser) ![]const u8 {
        self.pos += 1; // skip opening '"'
        const start = self.pos;

        while (self.pos < self.source.len and self.source[self.pos] != '"') {
            if (self.source[self.pos] == '\\') {
                self.pos += 2; // skip escape sequence
            } else {
                self.pos += 1;
            }
        }

        if (self.pos >= self.source.len) return error.UnterminatedString;

        const str = try self.allocator.dupe(u8, self.source[start..self.pos]);
        self.pos += 1; // skip closing '"'
        return str;
    }

    fn parseNumber(self: *JsonParser) !f64 {
        const start = self.pos;

        if (self.peek() == '-') self.pos += 1;

        while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
            self.pos += 1;
        }

        if (self.peek() == '.') {
            self.pos += 1;
            while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
                self.pos += 1;
            }
        }

        const num_str = self.source[start..self.pos];
        return std.fmt.parseFloat(f64, num_str) catch return error.InvalidNumber;
    }

    fn parseBool(self: *JsonParser) !bool {
        if (self.matchKeyword("true")) {
            return true;
        } else if (self.matchKeyword("false")) {
            return false;
        }
        return error.InvalidBoolean;
    }

    fn parseNull(self: *JsonParser) !JsonValue {
        if (self.matchKeyword("null")) {
            return JsonValue.null_value;
        }
        return error.InvalidNull;
    }

    fn matchKeyword(self: *JsonParser, keyword: []const u8) bool {
        if (self.pos + keyword.len > self.source.len) return false;

        if (std.mem.eql(u8, self.source[self.pos..self.pos + keyword.len], keyword)) {
            self.pos += keyword.len;
            return true;
        }
        return false;
    }

    fn skipWhitespace(self: *JsonParser) void {
        while (self.pos < self.source.len) {
            switch (self.source[self.pos]) {
                ' ', '\t', '\n', '\r' => self.pos += 1,
                else => break,
            }
        }
    }

    fn peek(self: *JsonParser) u8 {
        if (self.pos >= self.source.len) return 0;
        return self.source[self.pos];
    }
};

/// JSON stringifier
pub const JsonStringifier = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) JsonStringifier {
        return .{
            .allocator = allocator,
            .output = std.ArrayList(u8).empty,
        };
    }

    pub fn deinit(self: *JsonStringifier) void {
        self.output.deinit(self.allocator);
    }

    pub fn stringify(self: *JsonStringifier, value: JsonValue) ![]const u8 {
        try self.writeValue(value);
        return self.output.toOwnedSlice(self.allocator);
    }

    fn writeValue(self: *JsonStringifier, value: JsonValue) !void {
        switch (value) {
            .null_value => try self.output.appendSlice(self.allocator, "null"),
            .bool_value => |b| try self.output.appendSlice(self.allocator, if (b) "true" else "false"),
            .number => |n| {
                var buf: [100]u8 = undefined;
                const str = try std.fmt.bufPrint(&buf, "{d}", .{n});
                try self.output.appendSlice(self.allocator, str);
            },
            .string => |s| {
                try self.output.append(self.allocator, '"');
                try self.output.appendSlice(self.allocator, s);
                try self.output.append(self.allocator, '"');
            },
            .array => |arr| {
                try self.output.append(self.allocator, '[');
                for (arr, 0..) |item, i| {
                    if (i > 0) try self.output.append(self.allocator, ',');
                    try self.writeValue(item);
                }
                try self.output.append(self.allocator, ']');
            },
            .object => |obj| {
                try self.output.append(self.allocator, '{');
                var it = obj.iterator();
                var first = true;
                while (it.next()) |entry| {
                    if (!first) try self.output.append(self.allocator, ',');
                    first = false;
                    try self.output.append(self.allocator, '"');
                    try self.output.appendSlice(self.allocator, entry.key_ptr.*);
                    try self.output.appendSlice(self.allocator, "\":");
                    try self.writeValue(entry.value_ptr.*);
                }
                try self.output.append(self.allocator, '}');
            },
        }
    }
};

test "parse JSON object" {
    const allocator = std.testing.allocator;

    const json_str = "{\"name\":\"Alice\",\"age\":30,\"active\":true}";
    var parser = JsonParser.init(allocator, json_str);
    var value = try parser.parse();
    defer value.deinit(allocator);

    try std.testing.expect(value == .object);
}

test "parse JSON array" {
    const allocator = std.testing.allocator;

    const json_str = "[1,2,3,4,5]";
    var parser = JsonParser.init(allocator, json_str);
    var value = try parser.parse();
    defer value.deinit(allocator);

    try std.testing.expect(value == .array);
    try std.testing.expect(value.array.len == 5);
}

test "stringify JSON" {
    const allocator = std.testing.allocator;

    var obj = std.StringHashMap(JsonValue).init(allocator);
    defer obj.deinit();

    try obj.put("test", JsonValue{ .number = 42 });

    const value = JsonValue{ .object = obj };
    var stringifier = JsonStringifier.init(allocator);
    defer stringifier.deinit();

    const result = try stringifier.stringify(value);
    defer allocator.free(result);

    try std.testing.expect(result.len > 0);
}
