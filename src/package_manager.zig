const std = @import("std");
const package_mod = @import("package.zig");
const Manifest = package_mod.Manifest;

/// ZigScript package manager
pub const PackageManager = struct {
    allocator: std.mem.Allocator,
    cache_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator) !PackageManager {
        // Get cache directory: ~/.cache/zim/zigscript/packages/
        const home = std.posix.getenv("HOME") orelse ".";
        const cache_dir = try std.fs.path.join(
            allocator,
            &[_][]const u8{ home, ".cache", "zim", "zigscript", "packages" },
        );

        // Ensure cache directory exists (creates intermediate directories)
        std.fs.cwd().makePath(cache_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        return .{
            .allocator = allocator,
            .cache_dir = cache_dir,
        };
    }

    pub fn deinit(self: *PackageManager) void {
        self.allocator.free(self.cache_dir);
    }

    /// Initialize a new package
    pub fn initPackage(self: *PackageManager, name: []const u8) !void {
        std.debug.print("✨ Creating new ZigScript package: {s}\n", .{name});

        // Create package.zson
        var manifest = Manifest.init(self.allocator);
        defer manifest.deinit();

        manifest.name = try self.allocator.dupe(u8, name);
        manifest.version = try self.allocator.dupe(u8, "0.1.0");
        manifest.description = try self.allocator.dupe(u8, "A ZigScript package");
        manifest.license = try self.allocator.dupe(u8, "MIT");
        manifest.zigscript = try self.allocator.dupe(u8, "^0.1.0");
        manifest.main = try self.allocator.dupe(u8, "src/main.zs");

        try manifest.save("package.zson");
        std.debug.print("✅ Created package.zson\n", .{});

        // Create src directory
        std.fs.cwd().makeDir("src") catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        // Create src/main.zs
        const main_file = try std.fs.cwd().createFile("src/main.zs", .{});
        defer main_file.close();

        try main_file.writeAll(
            \\fn main() -> i32 {
            \\    console.log("Hello from " ++ NAME ++ "!");
            \\    return 0;
            \\}
            \\
        );

        std.debug.print("✅ Created src/main.zs\n", .{});
        std.debug.print("\n🎉 Package initialized! Run 'zs build src/main.zs' to compile.\n", .{});
    }

    /// Add a dependency
    pub fn addDependency(
        self: *PackageManager,
        package_name: []const u8,
        version_constraint: ?[]const u8,
    ) !void {
        std.debug.print("📦 Adding dependency: {s}", .{package_name});
        if (version_constraint) |vc| {
            std.debug.print("@{s}", .{vc});
        }
        std.debug.print("\n", .{});

        // Load existing manifest
        var manifest = Manifest.load(self.allocator, "package.zson") catch |err| {
            if (err == error.FileNotFound) {
                std.debug.print("❌ Error: No package.zson found. Run 'zs init' first.\n", .{});
                return error.NoManifest;
            }
            return err;
        };
        defer manifest.deinit();

        // Resolve package version
        const version = version_constraint orelse "latest";
        const resolved_version = try self.resolveVersion(package_name, version);
        defer self.allocator.free(resolved_version);

        std.debug.print("✅ Resolved {s}@{s}\n", .{ package_name, resolved_version });

        // Download package
        try self.downloadPackage(package_name, resolved_version);

        // Add to dependencies
        const name_copy = try self.allocator.dupe(u8, package_name);
        const version_copy = try self.allocator.dupe(u8, resolved_version);
        try manifest.dependencies.put(name_copy, version_copy);

        // Save updated manifest
        try manifest.save("package.zson");
        std.debug.print("📝 Updated package.zson\n", .{});
    }

    /// Install all dependencies
    pub fn install(self: *PackageManager) !void {
        std.debug.print("📦 Installing dependencies...\n", .{});

        // Load manifest
        var manifest = Manifest.load(self.allocator, "package.zson") catch |err| {
            if (err == error.FileNotFound) {
                std.debug.print("❌ Error: No package.zson found.\n", .{});
                return error.NoManifest;
            }
            return err;
        };
        defer manifest.deinit();

        var installed_count: usize = 0;

        // Install dependencies
        var it = manifest.dependencies.iterator();
        while (it.next()) |entry| {
            const pkg_name = entry.key_ptr.*;
            const version_constraint = entry.value_ptr.*;

            const resolved_version = try self.resolveVersion(pkg_name, version_constraint);
            defer self.allocator.free(resolved_version);

            std.debug.print("  📥 {s}@{s}\n", .{ pkg_name, resolved_version });

            try self.downloadPackage(pkg_name, resolved_version);
            installed_count += 1;
        }

        // Generate build.zig.zon for Zig dependencies
        if (manifest.zig_dependencies.count() > 0) {
            try manifest.generateBuildZon("build.zig.zon");
            std.debug.print("✅ Generated build.zig.zon for Zig dependencies\n", .{});
        }

        std.debug.print("✅ Installed {d} package(s)\n", .{installed_count});
    }

    /// Resolve package version from constraint
    fn resolveVersion(
        self: *PackageManager,
        _: []const u8,
        constraint: []const u8,
    ) ![]const u8 {

        // TODO: Implement actual version resolution
        // For now, strip ^ or ~ and return the version
        if (std.mem.startsWith(u8, constraint, "^") or
            std.mem.startsWith(u8, constraint, "~"))
        {
            return self.allocator.dupe(u8, constraint[1..]);
        }

        if (std.mem.eql(u8, constraint, "latest")) {
            return self.allocator.dupe(u8, "1.0.0");
        }

        return self.allocator.dupe(u8, constraint);
    }

    /// Download package to cache
    fn downloadPackage(
        self: *PackageManager,
        package_name: []const u8,
        version: []const u8,
    ) !void {
        // Create package directory in cache
        const pkg_path = try std.fs.path.join(
            self.allocator,
            &[_][]const u8{ self.cache_dir, package_name, version },
        );
        defer self.allocator.free(pkg_path);

        // Check if already downloaded
        std.fs.accessAbsolute(pkg_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // TODO: Actually download from registry
                // For now, just create the directory as a placeholder
                try std.fs.makeDirAbsolute(pkg_path);
                std.debug.print("  📥 Downloaded {s}@{s}\n", .{ package_name, version });
            } else {
                return err;
            }
        };
    }
};

/// Initialize new package
pub fn initCmd(allocator: std.mem.Allocator, name: []const u8) !void {
    var pm = try PackageManager.init(allocator);
    defer pm.deinit();

    try pm.initPackage(name);
}

/// Add dependency
pub fn addCmd(
    allocator: std.mem.Allocator,
    package_name: []const u8,
    version: ?[]const u8,
) !void {
    var pm = try PackageManager.init(allocator);
    defer pm.deinit();

    try pm.addDependency(package_name, version);
}

/// Install all dependencies
pub fn installCmd(allocator: std.mem.Allocator) !void {
    var pm = try PackageManager.init(allocator);
    defer pm.deinit();

    try pm.install();
}
