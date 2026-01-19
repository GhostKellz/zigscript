const std = @import("std");

/// ZigScript package manifest (package.zson)
pub const Manifest = struct {
    allocator: std.mem.Allocator,

    // Required fields
    name: []const u8,
    version: []const u8,

    // Optional metadata
    description: ?[]const u8 = null,
    author: ?[]const u8 = null,
    license: ?[]const u8 = null,

    // Compatibility
    zigscript: ?[]const u8 = null,
    zig: ?[]const u8 = null,

    // Entry points
    main: ?[]const u8 = null,
    exports: std.StringHashMap([]const u8),

    // Dependencies
    dependencies: std.StringHashMap([]const u8),
    dev_dependencies: std.StringHashMap([]const u8),
    zig_dependencies: std.StringHashMap(ZigDependency),

    // Scripts
    scripts: std.StringHashMap([]const u8),

    // Repository
    repository: ?Repository = null,

    pub const ZigDependency = struct {
        url: []const u8,
        hash: []const u8,

        pub fn deinit(self: *ZigDependency, allocator: std.mem.Allocator) void {
            allocator.free(self.url);
            allocator.free(self.hash);
        }
    };

    pub const Repository = struct {
        type: []const u8,
        url: []const u8,

        pub fn deinit(self: *Repository, allocator: std.mem.Allocator) void {
            allocator.free(self.type);
            allocator.free(self.url);
        }
    };

    pub fn init(allocator: std.mem.Allocator) Manifest {
        return .{
            .allocator = allocator,
            .name = "",
            .version = "",
            .exports = std.StringHashMap([]const u8).init(allocator),
            .dependencies = std.StringHashMap([]const u8).init(allocator),
            .dev_dependencies = std.StringHashMap([]const u8).init(allocator),
            .zig_dependencies = std.StringHashMap(ZigDependency).init(allocator),
            .scripts = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Manifest) void {
        self.allocator.free(self.name);
        self.allocator.free(self.version);

        if (self.description) |d| self.allocator.free(d);
        if (self.author) |a| self.allocator.free(a);
        if (self.license) |l| self.allocator.free(l);
        if (self.zigscript) |z| self.allocator.free(z);
        if (self.zig) |z| self.allocator.free(z);
        if (self.main) |m| self.allocator.free(m);

        // Free exports
        var exports_it = self.exports.iterator();
        while (exports_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.exports.deinit();

        // Free dependencies
        var deps_it = self.dependencies.iterator();
        while (deps_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.dependencies.deinit();

        // Free dev dependencies
        var dev_deps_it = self.dev_dependencies.iterator();
        while (dev_deps_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.dev_dependencies.deinit();

        // Free zig dependencies
        var zig_deps_it = self.zig_dependencies.iterator();
        while (zig_deps_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var dep = entry.value_ptr.*;
            dep.deinit(self.allocator);
        }
        self.zig_dependencies.deinit();

        // Free scripts
        var scripts_it = self.scripts.iterator();
        while (scripts_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.scripts.deinit();

        // Free repository
        if (self.repository) |*repo| {
            var repo_mut = repo.*;
            repo_mut.deinit(self.allocator);
        }
    }

    /// Load manifest from package.zson file
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Manifest {
        // Initialize I/O first so we can use it for file operations
        const io = std.Io.Threaded.global_single_threaded.io();

        // Read file
        const file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;
        var file_reader = file.reader(io, &buffer);
        const content = try file_reader.interface.readAlloc(allocator, 10 * 1024 * 1024); // 10MB max
        defer allocator.free(content);

        return try parseZson(allocator, content);
    }

    /// Parse ZSON content into Manifest
    fn parseZson(allocator: std.mem.Allocator, content: []const u8) !Manifest {
        // Parse using std.json (ZSON is JSON-compatible after comment removal)
        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            content,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidManifest;

        var manifest = Manifest.init(allocator);
        errdefer manifest.deinit();

        const obj = root.object;

        // Required fields
        if (obj.get("name")) |name_val| {
            if (name_val != .string) return error.InvalidName;
            manifest.name = try allocator.dupe(u8, name_val.string);
        } else {
            return error.MissingName;
        }

        if (obj.get("version")) |version_val| {
            if (version_val != .string) return error.InvalidVersion;
            manifest.version = try allocator.dupe(u8, version_val.string);
        } else {
            return error.MissingVersion;
        }

        // Optional metadata
        if (obj.get("description")) |val| {
            if (val == .string) {
                manifest.description = try allocator.dupe(u8, val.string);
            }
        }

        if (obj.get("author")) |val| {
            if (val == .string) {
                manifest.author = try allocator.dupe(u8, val.string);
            }
        }

        if (obj.get("license")) |val| {
            if (val == .string) {
                manifest.license = try allocator.dupe(u8, val.string);
            }
        }

        if (obj.get("zigscript")) |val| {
            if (val == .string) {
                manifest.zigscript = try allocator.dupe(u8, val.string);
            }
        }

        if (obj.get("zig")) |val| {
            if (val == .string) {
                manifest.zig = try allocator.dupe(u8, val.string);
            }
        }

        if (obj.get("main")) |val| {
            if (val == .string) {
                manifest.main = try allocator.dupe(u8, val.string);
            }
        }

        // Parse exports
        if (obj.get("exports")) |exports_val| {
            if (exports_val == .object) {
                var it = exports_val.object.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* == .string) {
                        const key = try allocator.dupe(u8, entry.key_ptr.*);
                        const value = try allocator.dupe(u8, entry.value_ptr.*.string);
                        try manifest.exports.put(key, value);
                    }
                }
            }
        }

        // Parse dependencies
        if (obj.get("dependencies")) |deps_val| {
            if (deps_val == .object) {
                var it = deps_val.object.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* == .string) {
                        const key = try allocator.dupe(u8, entry.key_ptr.*);
                        const value = try allocator.dupe(u8, entry.value_ptr.*.string);
                        try manifest.dependencies.put(key, value);
                    }
                }
            }
        }

        // Parse devDependencies
        if (obj.get("devDependencies")) |dev_deps_val| {
            if (dev_deps_val == .object) {
                var it = dev_deps_val.object.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* == .string) {
                        const key = try allocator.dupe(u8, entry.key_ptr.*);
                        const value = try allocator.dupe(u8, entry.value_ptr.*.string);
                        try manifest.dev_dependencies.put(key, value);
                    }
                }
            }
        }

        // Parse zig_dependencies
        if (obj.get("zig_dependencies")) |zig_deps_val| {
            if (zig_deps_val == .object) {
                var it = zig_deps_val.object.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* == .object) {
                        const dep_obj = entry.value_ptr.*.object;

                        var url: ?[]const u8 = null;
                        var hash: ?[]const u8 = null;

                        if (dep_obj.get("url")) |url_val| {
                            if (url_val == .string) {
                                url = url_val.string;
                            }
                        }

                        if (dep_obj.get("hash")) |hash_val| {
                            if (hash_val == .string) {
                                hash = hash_val.string;
                            }
                        }

                        if (url != null and hash != null) {
                            const key = try allocator.dupe(u8, entry.key_ptr.*);
                            const zig_dep = ZigDependency{
                                .url = try allocator.dupe(u8, url.?),
                                .hash = try allocator.dupe(u8, hash.?),
                            };
                            try manifest.zig_dependencies.put(key, zig_dep);
                        }
                    }
                }
            }
        }

        // Parse scripts
        if (obj.get("scripts")) |scripts_val| {
            if (scripts_val == .object) {
                var it = scripts_val.object.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* == .string) {
                        const key = try allocator.dupe(u8, entry.key_ptr.*);
                        const value = try allocator.dupe(u8, entry.value_ptr.*.string);
                        try manifest.scripts.put(key, value);
                    }
                }
            }
        }

        // Parse repository
        if (obj.get("repository")) |repo_val| {
            if (repo_val == .object) {
                const repo_obj = repo_val.object;

                var repo_type: ?[]const u8 = null;
                var repo_url: ?[]const u8 = null;

                if (repo_obj.get("type")) |type_val| {
                    if (type_val == .string) {
                        repo_type = type_val.string;
                    }
                }

                if (repo_obj.get("url")) |url_val| {
                    if (url_val == .string) {
                        repo_url = url_val.string;
                    }
                }

                if (repo_type != null and repo_url != null) {
                    manifest.repository = Repository{
                        .type = try allocator.dupe(u8, repo_type.?),
                        .url = try allocator.dupe(u8, repo_url.?),
                    };
                }
            }
        }

        return manifest;
    }

    /// Save manifest to package.zson file (using ZSON format)
    pub fn save(self: *Manifest, path: []const u8) !void {
        const io = std.Io.Threaded.global_single_threaded.io();
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);

        var buf_storage: [4096]u8 = undefined;
        var file_writer = file.writer(io, &buf_storage);
        const writer = &file_writer.interface;

        try writer.writeAll("{\n");

        // Metadata
        try writer.print("  name: \"{s}\",\n", .{self.name});
        try writer.print("  version: \"{s}\",\n", .{self.version});

        if (self.description) |desc| {
            try writer.print("  description: \"{s}\",\n", .{desc});
        }

        if (self.author) |author| {
            try writer.print("  author: \"{s}\",\n", .{author});
        }

        if (self.license) |license| {
            try writer.print("  license: \"{s}\",\n", .{license});
        }

        // Compatibility
        if (self.zigscript) |zs| {
            try writer.print("  zigscript: \"{s}\",\n", .{zs});
        }

        if (self.zig) |z| {
            try writer.print("  zig: \"{s}\",\n", .{z});
        }

        // Main
        if (self.main) |main| {
            try writer.print("  main: \"{s}\",\n", .{main});
        }

        // Dependencies
        if (self.dependencies.count() > 0) {
            try writer.writeAll("  dependencies: {\n");
            var it = self.dependencies.iterator();
            while (it.next()) |entry| {
                try writer.print("    \"{s}\": \"{s}\",\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            try writer.writeAll("  },\n");
        }

        // Scripts
        if (self.scripts.count() > 0) {
            try writer.writeAll("  scripts: {\n");
            var it = self.scripts.iterator();
            while (it.next()) |entry| {
                try writer.print("    {s}: \"{s}\",\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            try writer.writeAll("  },\n");
        }

        try writer.writeAll("}\n");

        try file_writer.interface.flush();
    }

    /// Generate build.zig.zon from zig_dependencies for ZIM
    pub fn generateBuildZon(self: *Manifest, path: []const u8) !void {
        if (self.zig_dependencies.count() == 0) return;

        const io = std.Io.Threaded.global_single_threaded.io();
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        defer file.close(io);

        var buf_storage: [4096]u8 = undefined;
        var file_writer = file.writer(io, &buf_storage);
        const writer = &file_writer.interface;

        try writer.writeAll(".{\n");
        try writer.print("    .name = \"{s}\",\n", .{self.name});
        try writer.print("    .version = \"{s}\",\n", .{self.version});
        try writer.writeAll("    .dependencies = .{\n");

        var it = self.zig_dependencies.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const dep = entry.value_ptr.*;

            try writer.print("        .{s} = .{{\n", .{name});
            try writer.print("            .url = \"{s}\",\n", .{dep.url});
            try writer.print("            .hash = \"{s}\",\n", .{dep.hash});
            try writer.writeAll("        },\n");
        }

        try writer.writeAll("    },\n");
        try writer.writeAll("}\n");

        try file_writer.interface.flush();
    }
};

test "manifest parsing" {
    const allocator = std.testing.allocator;

    const zson_content =
        \\{
        \\  "name": "test-package",
        \\  "version": "1.0.0",
        \\  "description": "A test package",
        \\  "main": "src/main.zs",
        \\  "dependencies": {
        \\    "http-server": "^2.1.0"
        \\  }
        \\}
    ;

    var manifest = try Manifest.parseZson(allocator, zson_content);
    defer manifest.deinit();

    try std.testing.expectEqualStrings("test-package", manifest.name);
    try std.testing.expectEqualStrings("1.0.0", manifest.version);
    try std.testing.expect(manifest.description != null);
    try std.testing.expectEqualStrings("A test package", manifest.description.?);
}
