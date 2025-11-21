const std = @import("std");
const zs = @import("zs");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout_file = std.posix.STDOUT_FILENO;
    const stdout_handle = std.fs.File{ .handle = stdout_file };
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = stdout_handle.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("ZigScript (zs) Compiler v{s}\n", .{zs.version});
    try stdout.print("{s}\n\n", .{zs.phase});
    try stdout.flush();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage(stdout);
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "build") or std.mem.eql(u8, command, "compile")) {
        if (args.len < 3) {
            try stdout.print("Error: No input file specified\n", .{});
            try printUsage(stdout);
            return;
        }

        const input_file = args[2];

        var options = zs.compiler.CompileOptions{
            .source_path = input_file,
            .verbose = false,
        };

        // Parse additional flags
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
                i += 1;
                if (i < args.len) {
                    options.output_path = args[i];
                }
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
                options.verbose = true;
            } else if (std.mem.eql(u8, arg, "--check")) {
                options.check_only = true;
            }
        }

        try zs.compile(allocator, options);
    } else if (std.mem.eql(u8, command, "check")) {
        if (args.len < 3) {
            try stdout.print("Error: No input file specified\n", .{});
            try printUsage(stdout);
            return;
        }

        const input_file = args[2];
        try zs.compile(allocator, .{
            .source_path = input_file,
            .check_only = true,
            .verbose = true,
        });
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version")) {
        try stdout.print("v{s}\n", .{zs.version});
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        try printUsage(stdout);
    } else {
        try stdout.print("Unknown command: {s}\n\n", .{command});
        try printUsage(stdout);
    }
}

fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zs <command> [options]
        \\
        \\Commands:
        \\  build <file>       Compile a ZigScript file to WASM
        \\  compile <file>     Alias for build
        \\  check <file>       Type-check a file without generating code
        \\  version            Print version information
        \\  help               Show this help message
        \\
        \\Options:
        \\  -o, --output <file>    Specify output file
        \\  -v, --verbose          Enable verbose output
        \\  --check                Type-check only, don't generate code
        \\
        \\Examples:
        \\  zs build hello.zs
        \\  zs build hello.zs -o output.wat
        \\  zs check my_program.zs
        \\
    );
}

test "zs compiler tests" {
    // Run all tests from imported modules
    std.testing.refAllDecls(@This());
}
