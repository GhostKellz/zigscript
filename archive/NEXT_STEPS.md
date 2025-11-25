# Next Steps for the Complete ZigScript Ecosystem

## Current Status

✅ **ZigScript Compiler** - 100% feature complete (40/40 examples working)
✅ **Nexus Runtime** - Host functions implemented, WASM loader ready
✅ **Package System** - ZSON-based package.zson, zs init/add/install commands
✅ **ZSON Parser** - JSON superset for config files
✅ **ZIM Integration** - Generate build.zig.zon for Zig dependencies

---

## Immediate Priorities (Next 1-2 Weeks)

### 1. **Test the Complete Stack End-to-End**

**Why**: Verify everything actually works together before shipping

**Tasks**:
- [ ] Build Nexus with ZigScript integration: `cd /data/projects/nexus && zig build`
- [ ] Build ZigScript compiler: `cd /data/projects/zigscript && zig build`
- [ ] Compile example: `zs build examples/web_server/server.zs`
- [ ] Run on Nexus: `nexus-zs run examples/web_server/server.wasm`
- [ ] Fix any compilation errors or runtime issues
- [ ] Verify all 9 host functions work correctly

**Success Criteria**: Can compile ZigScript → WASM → Run on Nexus with HTTP/JSON/FS working

---

### 2. **Implement Real Host Functions in Nexus**

**Why**: Currently host functions are stubs/mocks

**File**: `/data/projects/nexus/src/zigscript/host.zig`

**Tasks**:

#### JSON Host Functions
```zig
// Currently: Just reads/writes strings
// Needed: Actual struct ↔ JSON conversion

pub fn json_decode(params: []const Value, allocator: Allocator) ![]Value {
    const json_str = try ctx.readString(params[0].toInt(u32));

    // Use Zig's std.json to parse
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});

    // Convert to WASM struct layout
    const struct_ptr = try writeStructToMemory(parsed.value);

    return &[_]Value{Value.fromZig(struct_ptr)};
}
```

#### HTTP Host Functions
```zig
// Currently: Returns mock data
// Needed: Real HTTP client using Nexus stdlib

pub fn http_get(params: []const Value, allocator: Allocator) ![]Value {
    const url = try ctx.readString(params[0].toInt(u32));

    // Use Nexus HTTP client
    const client = try http.Client.init(allocator);
    defer client.deinit();

    const response = try client.get(url);
    defer response.deinit();

    const body_ptr = try ctx.writeString(response.body);

    // Return promise that resolves to body
    const promise_id = try ctx.promises.create();
    try ctx.promises.resolve(promise_id, response.body);

    return &[_]Value{Value.fromZig(promise_id)};
}
```

#### File System Host Functions
```zig
// Currently: Synchronous reads
// Needed: Async I/O via event loop

pub fn fs_read_file(params: []const Value, allocator: Allocator) ![]Value {
    const path = try ctx.readString(params[0].toInt(u32));
    const promise_id = try ctx.promises.create();

    // Spawn async task
    const task = try allocator.create(FsReadTask);
    task.* = .{
        .path = try allocator.dupe(u8, path),
        .promise_id = promise_id,
        .ctx = ctx,
    };

    try ctx.event_loop.task_queue.enqueue(FsReadTask.execute, task);

    return &[_]Value{Value.fromZig(promise_id)};
}
```

**Estimate**: 3-5 days

---

### 3. **Fix REPL I/O for Zig 0.16.0**

**Why**: REPL is 95% done but has stdin/stdout issues

**File**: `/data/projects/zigscript/src/repl.zig`

**Current Issue**:
```zig
// Lines 41-46: Zig 0.16.0 I/O API changed
var stdin_io = std.fs.File.Io{};  // This API doesn't exist anymore
var stdin_reader = stdin_handle.reader(stdin_io, &stdin_buffer);
```

**Fix**:
```zig
// Use new Zig 0.16.0 I/O API
const stdin = std.io.getStdIn();
var buffered_reader = std.io.bufferedReader(stdin.reader());
const reader = buffered_reader.reader();

while (true) {
    try stdout.print("\x1b[32m[{d}]\x1b[0m >>> ", .{line_num});
    try stdout.flush();

    const line = try reader.readUntilDelimiterOrEof(&line_buffer, '\n') orelse break;

    // ... rest of REPL logic
}
```

**Also Add**:
- [ ] Multiline input support (detect unclosed braces)
- [ ] Variable persistence between evaluations
- [ ] Actual expression evaluation (not just parsing)
- [ ] Integration with Nexus runtime (execute WASM in REPL)

**Estimate**: 1-2 days

---

### 4. **Update zsls for Package Awareness**

**Why**: LSP should autocomplete imports from package.zson dependencies

**File**: `/data/projects/zsls/src/*.zig`

**Tasks**:

#### Module Resolution
```zig
// src/module_resolver.zig
pub fn resolveImport(import_path: []const u8) ![]const u8 {
    // 1. Check built-in modules
    if (std.mem.startsWith(u8, import_path, "std/")) {
        return resolveBuiltin(import_path);
    }

    // 2. Check relative imports
    if (std.mem.startsWith(u8, import_path, "./") or
        std.mem.startsWith(u8, import_path, "../")) {
        return resolveRelative(import_path);
    }

    // 3. Check package.zson dependencies
    const manifest = try loadManifest("package.zson");
    defer manifest.deinit();

    if (manifest.dependencies.get(import_path)) |version| {
        const cache_path = try getCachePath(import_path, version);
        return cache_path;
    }

    return error.ModuleNotFound;
}
```

#### Autocomplete for Package Imports
```zig
// When user types: import { } from "
// Show autocomplete with:
// - std/* modules (built-in)
// - Packages from dependencies
// - Relative files (./*.zs)

pub fn getImportCompletions(ctx: *CompletionContext) ![]CompletionItem {
    var items = std.ArrayList(CompletionItem).init(allocator);

    // Add built-in modules
    try items.append(.{ .label = "std/json", .kind = .Module });
    try items.append(.{ .label = "std/http", .kind = .Module });
    try items.append(.{ .label = "std/fs", .kind = .Module });

    // Add packages from package.zson
    const manifest = loadManifest("package.zson") catch return items.items;
    defer manifest.deinit();

    var it = manifest.dependencies.iterator();
    while (it.next()) |entry| {
        try items.append(.{ .label = entry.key_ptr.*, .kind = .Module });
    }

    return items.items;
}
```

**Estimate**: 2-3 days

---

## Short-Term Goals (Next 1-2 Months)

### 5. **Build a Real Package Registry**

**Why**: Need a central place to publish/download packages

**Options**:

#### Option A: GitHub-based (Quick)
```bash
# packages are just GitHub repos
$ zs add github:user/http-server@v2.1.0

# ZigScript downloads from GitHub releases
# https://github.com/user/http-server/archive/v2.1.0.tar.gz
```

**Implementation**:
```zig
// src/package_manager.zig
fn downloadFromGithub(repo: []const u8, version: []const u8) !void {
    const url = try std.fmt.allocPrint(
        allocator,
        "https://github.com/{s}/archive/{s}.tar.gz",
        .{repo, version}
    );
    defer allocator.free(url);

    // Download using curl or Zig's HTTP client
    // Extract to cache directory
}
```

#### Option B: Custom Registry (Better)
```bash
# Centralized registry at registry.zigscript.dev
$ zs add http-server@^2.1.0

# Registry API:
# GET /packages/http-server/versions
# GET /packages/http-server/2.1.0/download
```

**Start with Option A, migrate to Option B later**

**Estimate**: 1-2 weeks for GitHub-based

---

### 6. **Create Essential Packages**

**Why**: Need core packages for ecosystem to be useful

**Packages to Build**:

#### http-server (Priority #1)
```zs
// Package: http-server
// Provides Express-like HTTP server

import { Server } from "http-server";

let app = Server.create();

app.get("/users/:id", fn(req, res) {
    let user = await db.getUser(req.params.id);
    res.json(user);
});

app.listen(3000);
```

#### postgres (Priority #2)
```zs
// Package: postgres
// PostgreSQL client

import { Pool } from "postgres";

let db = Pool.connect("postgres://localhost/mydb");

let users = await db.query<User>("SELECT * FROM users WHERE active = $1", [true]);
```

#### test-framework (Priority #3)
```zs
// Package: test-framework
// Jest-like testing

import { test, expect } from "test-framework";

test("addition works", fn() {
    expect(2 + 2).toBe(4);
});

test("async operations", async fn() {
    let result = await fetchData();
    expect(result).toHaveProperty("id");
});
```

#### cli-framework (Priority #4)
```zs
// Package: cli-framework
// Commander.js-like CLI builder

import { CLI } from "cli-framework";

CLI.command("build")
    .option("-o, --output <file>", "Output file")
    .action(fn(opts) {
        build(opts.output);
    });

CLI.parse(args);
```

**Each package needs**:
- `package.zson` manifest
- Source code (`.zs` files)
- Tests
- README.md with examples
- Published to registry

**Estimate**: 1-2 weeks per package (can be done in parallel)

---

### 7. **Integrate ZSON with ZigScript Parser**

**Why**: Currently using std.json for package.zson, should use ZSON

**File**: `/data/projects/zigscript/src/package.zig`

**Current**:
```zig
// Uses std.json (requires valid JSON, no comments)
const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
```

**Better**:
```zig
// Use ZSON parser
const zson = @import("zson");

pub fn load(allocator: Allocator, path: []const u8) !Manifest {
    const content = try std.fs.cwd().readFileAlloc(...);
    defer allocator.free(content);

    // Parse ZSON (supports comments, unquoted keys, trailing commas)
    var value = try zson.parse(allocator, content);
    defer value.deinit(allocator);

    return try manifestFromZsonValue(allocator, value);
}
```

**Add ZSON to build.zig.zon**:
```zig
// /data/projects/zigscript/build.zig.zon
.{
    .name = "zigscript",
    .version = "0.1.0",
    .dependencies = .{
        .zson = .{
            .path = "../zson",
        },
    },
}
```

**Estimate**: 1 day

---

### 8. **Add Source Map Generation**

**Why**: Currently just comments in WAT, need proper .map files

**File**: `/data/projects/zigscript/src/codegen_wasm.zig`

**Implement**:
```zig
pub const SourceMap = struct {
    version: u32 = 3,
    file: []const u8,
    sources: [][]const u8,
    names: [][]const u8,
    mappings: []const u8,

    pub fn generate(allocator: Allocator, ast: *ast.Module, output_file: []const u8) !SourceMap {
        var map = SourceMap{
            .file = output_file,
            .sources = &[_][]const u8{ast.source_path},
            .names = try collectNames(allocator, ast),
            .mappings = try generateMappings(allocator, ast),
        };
        return map;
    }

    pub fn write(self: *SourceMap, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try std.json.stringify(self, .{}, file.writer());
    }
};
```

**Usage**:
```bash
$ zs build server.zs --source-map
✅ Generated server.wat
✅ Generated server.wat.map
```

**Integrate with Nexus debugger**:
```zig
// When WASM error occurs, use source map to show ZigScript line
Error at WASM instruction 1234
  -> server.zs:42:15: let user = await fetchData();
```

**Estimate**: 3-4 days

---

## Medium-Term Goals (2-6 Months)

### 9. **ZIM Full Integration**

**Why**: Currently generates build.zig.zon, but ZIM should manage ZigScript packages too

**Integration Points**:

#### ZIM should understand ZigScript packages
```bash
$ zim add zigscript:http-server@^2.1.0
📦 Adding ZigScript package: http-server@^2.1.0
✅ Installed to ~/.cache/zim/zigscript/packages/
```

#### ZIM manifest should support ZigScript
```toml
# zim.toml
[project]
name = "my-app"
version = "1.0.0"

[zigscript]
version = "^0.1.0"

[dependencies.zigscript]
http-server = "^2.1.0"
postgres = "^1.0.0"

[dependencies.zig]
network = { url = "...", hash = "..." }
```

#### Unified dependency resolution
```bash
$ zim install
📦 Resolving dependencies...
  ✅ Zig dependencies (2 packages)
  ✅ ZigScript dependencies (2 packages)
📥 Downloading...
✅ Installed 4 packages total
```

**Files to Modify**:
- `/data/projects/zim/src/deps/resolver.zig` - Add ZigScript package type
- `/data/projects/zim/src/deps/manifest.zig` - Parse ZigScript section
- `/data/projects/zim/src/deps/handlers.zig` - Handle ZigScript downloads

**Estimate**: 2-3 weeks

---

### 10. **Hot Reload Support**

**Why**: Developer experience - instant feedback on code changes

**Architecture**:
```
┌─────────────────┐         ┌─────────────────┐
│  File Watcher   │ ──────> │  ZigScript      │
│  (inotify)      │         │  Compiler       │
└─────────────────┘         └────────┬────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │  Nexus Runtime  │
                            │  - Reload WASM  │
                            │  - Preserve     │
                            │    state        │
                            └─────────────────┘
```

**Implementation**:

#### File Watcher
```zig
// src/hot_reload.zig
pub fn watchAndReload(allocator: Allocator, source_path: []const u8) !void {
    const watcher = try FileWatcher.init(allocator, source_path);
    defer watcher.deinit();

    while (true) {
        watcher.wait() catch continue;

        std.debug.print("🔄 File changed, recompiling...\n", .{});

        // Recompile
        compile(allocator, .{ .source_path = source_path }) catch |err| {
            std.debug.print("❌ Compilation failed: {}\n", .{err});
            continue;
        };

        // Reload in Nexus
        try nexus.reloadModule(source_path);

        std.debug.print("✅ Reloaded successfully\n", .{});
    }
}
```

#### Nexus Hot Reload
```zig
// /data/projects/nexus/src/runtime/hot_reload.zig
pub fn reloadModule(runtime: *Runtime, wasm_path: []const u8) !void {
    // Load new WASM module
    const new_module = try loadWasmModule(wasm_path);

    // Preserve state (globals, memory)
    const state = try runtime.captureState();

    // Swap modules
    runtime.module.deinit();
    runtime.module = new_module;

    // Restore state
    try runtime.restoreState(state);

    std.debug.print("🔄 Module reloaded\n", .{});
}
```

**Usage**:
```bash
$ nexus-zs run --watch server.zs
🚀 Starting with hot reload enabled...
✅ Loaded server.zs
🔄 Watching for changes...

# Edit server.zs
🔄 File changed, recompiling...
✅ Reloaded successfully
```

**Estimate**: 1-2 weeks

---

### 11. **Native Compilation (AOT)**

**Why**: Even faster than WASM - compile directly to native code

**Architecture**:
```
ZigScript (.zs) → LLVM IR → Native Binary
```

**Implementation**:

#### Option A: WASM → Native (using wasm2c or wasmer)
```bash
$ zs build --native server.zs
✅ Compiled to server.wat
🔄 Converting WASM to C...
🔄 Compiling C to native...
✅ Generated server (native binary)

$ ./server
🚀 Running natively (no WASM runtime!)
```

#### Option B: Direct LLVM Backend
```zig
// Add LLVM backend to ZigScript compiler
pub fn generateLLVM(allocator: Allocator, module: *ast.Module) ![]const u8 {
    const llvm_ctx = llvm.Context.create();
    defer llvm_ctx.dispose();

    const llvm_module = llvm.Module.create("main", llvm_ctx);

    // Generate LLVM IR from AST
    for (module.decls) |decl| {
        try genDecl(llvm_module, decl);
    }

    // Optimize
    const pm = llvm.PassManager.create(llvm_module);
    llvm.addStandardOptimizations(pm);
    pm.run(llvm_module);

    // Emit native object file
    return llvm_module.emitObjectCode();
}
```

**Performance Target**: 50-100x faster than WASM

**Estimate**: 1-2 months

---

## Long-Term Vision (6-12 Months)

### 12. **Effect System**

Track side effects in the type system:
```zs
fn pure(x: i32) -> i32 {
    return x * 2;  // No effects
}

fn impure() -> io Effect<i32, Error> {
    let content = fs.readFile("data.txt")?;  // io effect
    return content.len;
}

fn cannot_call_io() -> i32 {
    impure();  // ERROR: io effect not allowed in pure context
    return 0;
}
```

**Benefits**: Compiler enforces purity, easier testing, better optimization

**Estimate**: 2-3 months

---

### 13. **Distributed Nexus**

Multi-machine runtime for ZigScript:
```zs
// Run on multiple servers automatically
@distributed
async fn processLargeDataset(data: Data[]) -> Results {
    let chunks = data.chunk(1000);

    // Nexus distributes across cluster
    let results = await parallel(chunks.map(processChunk));

    return aggregate(results);
}
```

**Estimate**: 3-4 months

---

## Prioritized Roadmap

### Week 1-2 (Critical Path)
1. ✅ Test complete stack end-to-end
2. ✅ Fix REPL I/O
3. ✅ Implement real host functions in Nexus

### Week 3-4 (Developer Experience)
4. ✅ Update zsls for package awareness
5. ✅ GitHub-based package registry
6. ✅ Integrate ZSON parser

### Month 2 (Essential Packages)
7. ✅ Build http-server package
8. ✅ Build test-framework package
9. ✅ Build cli-framework package
10. ✅ Add source map generation

### Month 3-4 (Polish)
11. ✅ ZIM full integration
12. ✅ Hot reload support
13. ✅ Better error messages with suggestions

### Month 5-6 (Performance)
14. ✅ Native compilation (AOT)
15. ✅ Performance profiling tools
16. ✅ Optimization passes

### Month 7-12 (Advanced)
17. ✅ Effect system
18. ✅ Distributed runtime
19. ✅ Production deployments
20. ✅ Community growth

---

## Success Metrics

**By End of Month 1**:
- [ ] 5+ real applications built with ZigScript + Nexus
- [ ] All examples running on Nexus runtime
- [ ] REPL fully functional

**By End of Month 3**:
- [ ] 10+ packages in registry
- [ ] zsls autocompletes package imports
- [ ] Source maps working in debugger

**By End of Month 6**:
- [ ] 50+ packages in registry
- [ ] Native compilation working
- [ ] Hot reload in production use

**By End of Month 12**:
- [ ] 100+ packages
- [ ] 1000+ GitHub stars
- [ ] 10+ production deployments
- [ ] Effect system implemented

---

## Resource Allocation

**If Solo**:
- Focus on: Testing stack, real host functions, REPL, essential packages
- Defer: Effect system, distributed runtime, advanced features

**If Team of 2-3**:
- Person 1: Core compiler + runtime
- Person 2: Packages + ecosystem
- Person 3: Tooling (zsls, debugger, profiler)

**If Community Contributors**:
- Core team: Compiler, runtime, standards
- Community: Packages, examples, documentation

---

**Version**: 1.0
**Date**: 2025-01-23
**Status**: Ready to execute! 🚀
