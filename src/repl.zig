const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const stdout_handle = std.Io.File.stdout();
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = stdout_handle.writer(io, &stdout_buffer);

    // Print welcome message
    try stdout_writer.interface.writeAll(
        \\
        \\\x1b[36m╔════════════════════════════════════════╗
        \\\x1b[36m║  ZigScript REPL v0.1.2                 ║
        \\\x1b[36m╚════════════════════════════════════════╝\x1b[0m
        \\
        \\Type ZigScript expressions or declarations
        \\Commands:
        \\  :help       Show help
        \\  :quit       Exit REPL
        \\
        \\
    );
    try stdout_writer.interface.flush();

    var line_num: usize = 1;
    var history: std.ArrayListUnmanaged([]const u8) = .{};
    defer {
        for (history.items) |line| {
            allocator.free(line);
        }
        history.deinit(allocator);
    }

    const stdin_handle = std.Io.File.stdin();
    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = stdin_handle.reader(io, &stdin_buffer);

    while (true) {
        // Print prompt
        try stdout_writer.interface.print("\x1b[32m[{d}]\x1b[0m >>> ", .{line_num});
        try stdout_writer.interface.flush();

        // Read line
        const line = (stdin_reader.interface.takeDelimiter('\n') catch |err| {
            try stdout_writer.interface.print("\nRead error: {s}\n", .{@errorName(err)});
            continue;
        }) orelse break;

        // Skip empty lines
        if (line.len == 0) continue;

        // Handle commands
        if (std.mem.startsWith(u8, line, ":")) {
            if (std.mem.eql(u8, line, ":quit") or std.mem.eql(u8, line, ":q")) {
                try stdout_writer.interface.print("\n\x1b[36mGoodbye!\x1b[0m\n", .{});
                try stdout_writer.interface.flush();
                break;
            } else if (std.mem.eql(u8, line, ":help") or std.mem.eql(u8, line, ":h")) {
                try stdout_writer.interface.writeAll(
                    \\\x1b[36m
                    \\ZigScript REPL Help
                    \\===================\x1b[0m
                    \\
                    \\Expressions:
                    \\  5 + 3              Arithmetic
                    \\  let x = 42         Variables
                    \\  fn add(a, b) { return a + b; }
                    \\
                    \\Commands:
                    \\  :help, :h          Show help
                    \\  :quit, :q          Exit REPL
                    \\
                    \\
                );
                try stdout_writer.interface.flush();
                continue;
            } else {
                try stdout_writer.interface.print("\x1b[33mUnknown command: {s}\x1b[0m\n", .{line});
                try stdout_writer.interface.flush();
                continue;
            }
        }

        // Add to history
        const line_copy = try allocator.dupe(u8, line);
        try history.append(allocator, line_copy);

        // Try to evaluate
        evaluateLine(allocator, line, &stdout_writer.interface) catch |err| {
            try stdout_writer.interface.print("\x1b[31mError: {s}\x1b[0m\n", .{@errorName(err)});
            try stdout_writer.interface.flush();
        };

        line_num += 1;
    }
}

fn evaluateLine(allocator: std.mem.Allocator, input: []const u8, writer: anytype) !void {
    // Try to parse the input
    var lexer = Lexer.init(allocator, input);
    var parser = Parser.init(allocator, &lexer) catch {
        try writer.writeAll("\x1b[31mParse error\x1b[0m\n");
        try writer.flush();
        return;
    };
    defer parser.deinit();

    var module = parser.parseModule() catch {
        try writer.writeAll("\x1b[31mParse error\x1b[0m\n");
        try writer.flush();
        return;
    };
    defer module.deinit();

    if (parser.had_error) {
        try writer.writeAll("\x1b[31mParse error\x1b[0m\n");
        try writer.flush();
        return;
    }

    // Success - show what was parsed
    if (module.stmts.len > 0) {
        const stmt = module.stmts[0];
        switch (stmt) {
            .let_decl => |let_decl| {
                try writer.print("\x1b[32m✓\x1b[0m Declared: \x1b[32m{s}\x1b[0m\n", .{let_decl.name});
            },
            .fn_decl => |fn_decl| {
                try writer.print("\x1b[32m✓\x1b[0m Function: \x1b[32m{s}\x1b[0m ({d} params)\n", .{ fn_decl.name, fn_decl.params.len });
            },
            .expr_stmt => {
                try writer.writeAll("\x1b[90m=> (expression evaluated)\x1b[0m\n");
            },
            else => {
                try writer.writeAll("\x1b[90m=> (statement executed)\x1b[0m\n");
            },
        }
    }
    try writer.flush();
}
