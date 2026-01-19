const std = @import("std");
const zs = @import("zs");
const package_manager = @import("package_manager.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();

    const stdout_handle = std.Io.File.stdout();
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = stdout_handle.writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    const args = try init.minimal.args.toSlice(arena);

    if (args.len < 2) {
        try printUsage(stdout);
        try stdout_writer.flush();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "build") or std.mem.eql(u8, command, "compile")) {
        if (args.len < 3) {
            try stdout.print("Error: No input file specified\n", .{});
            try printUsage(stdout);
            try stdout_writer.flush();
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

        zs.compile(allocator, options) catch {
            // Error messages already printed by compiler, just exit
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "check")) {
        if (args.len < 3) {
            try stdout.print("Error: No input file specified\n", .{});
            try printUsage(stdout);
            try stdout_writer.flush();
            return;
        }

        const input_file = args[2];
        zs.compile(allocator, .{
            .source_path = input_file,
            .check_only = true,
            .verbose = true,
        }) catch {
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "init")) {
        const pkg_name = if (args.len >= 3) args[2] else "my-package";
        try package_manager.initCmd(allocator, init.environ_map, pkg_name);
    } else if (std.mem.eql(u8, command, "add")) {
        if (args.len < 3) {
            try stdout.print("Error: No package specified\n", .{});
            try stdout.print("Usage: zs add <package>[@version]\n", .{});
            try stdout_writer.flush();
            return;
        }

        const pkg_spec = args[2];

        // Parse package@version
        var pkg_name: []const u8 = pkg_spec;
        var version: ?[]const u8 = null;

        if (std.mem.indexOf(u8, pkg_spec, "@")) |idx| {
            pkg_name = pkg_spec[0..idx];
            version = pkg_spec[idx + 1 ..];
        }

        try package_manager.addCmd(allocator, init.environ_map, pkg_name, version);
    } else if (std.mem.eql(u8, command, "install")) {
        try package_manager.installCmd(allocator, init.environ_map);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version")) {
        try stdout.print("ZigScript (zs) v{s}\n", .{zs.version});
        try stdout_writer.flush();
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        try printUsage(stdout);
        try stdout_writer.flush();
    } else {
        try stdout.print("Unknown command: {s}\n\n", .{command});
        try printUsage(stdout);
        try stdout_writer.flush();
    }
}

fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zs <command> [options]
        \\
        \\Build Commands:
        \\  build <file>        Compile a ZigScript file to WASM
        \\  compile <file>      Alias for build
        \\  check <file>        Type-check without generating code
        \\
        \\Package Management:
        \\  init [name]         Initialize a new ZigScript package
        \\  add <pkg>[@ver]     Add a dependency to package.zson
        \\  install             Install all dependencies from package.zson
        \\
        \\Utility:
        \\  version             Print version information
        \\  help                Show this help message
        \\
        \\Build Options:
        \\  -o, --output <file> Specify output file
        \\  -v, --verbose       Enable verbose output
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
