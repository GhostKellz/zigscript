# ZigScript Phase 2 - Async/Await + Nexus IO Integration

## Overview

Phase 2 adds async/await support and integrates ZigScript with the Nexus runtime for real async IO operations.

## Architecture

### 1. Async/Await Model

ZigScript will use a **stackless coroutine** model compatible with WASM:

```zs
// ZigScript async function
async fn fetchUser(id: string) -> Result<User, Error> {
  let response = await http.get("https://api.example.com/users/{id}");
  if response.status != 200 {
    return Err(Error.Network("Failed to fetch user"));
  }

  let user = json.decode<User>(response.body)?;
  return Ok(user);
}
```

**Compiles to:**
- WASM functions that return Promise handles
- Suspend points at each `await`
- Resume via Nexus event loop callback

### 2. Runtime Integration

```
┌─────────────────────────────────────────────────────────────┐
│                    ZigScript Application                     │
│              (hello.zs compiled to hello.wasm)               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  ZigScript WASM Runtime                      │
│  ┌──────────────────┬────────────────────┬─────────────┐    │
│  │  Async Scheduler │  Promise Registry  │  Memory     │    │
│  │  (suspend/resume)│  (pending futures) │  (linear)   │    │
│  └──────────────────┴────────────────────┴─────────────┘    │
└────────────────────────┬────────────────────────────────────┘
                         │ Host Function Calls
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     Nexus Runtime                            │
│  ┌───────────────┬──────────────┬───────────────────┐       │
│  │  Event Loop   │   HTTP       │   FS / Timer      │       │
│  │  (epoll/...)  │   (async)    │   (async)         │       │
│  └───────────────┴──────────────┴───────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Steps

### Step 1: Global Function Symbol Table

**Problem:** Type checker can't resolve function calls because it doesn't track function declarations globally.

**Solution:**
- Add `functions: std.StringHashMap(FunctionSignature)` to `TypeChecker`
- First pass: collect all function declarations
- Second pass: type-check bodies with function context

```zig
// typechecker.zig additions
pub const FunctionSignature = struct {
    params: []ast.Type,
    return_type: ?ast.Type,
    is_async: bool,
};

// In checkModule:
// Pass 1: Collect types and functions
for (module.stmts) |stmt| {
    switch (stmt) {
        .fn_decl => |fn_decl| {
            try self.functions.put(fn_decl.name, .{
                .params = fn_decl.params.map(|p| p.type_annotation),
                .return_type = fn_decl.return_type,
                .is_async = fn_decl.is_async,
            });
        },
        // ... structs, enums
    }
}
```

### Step 2: Async/Await Syntax Support

**Lexer changes:**
- Keywords `async`, `await` already added ✅

**Parser changes:**
- Parse `async fn` declarations
- Parse `await` expressions

**AST changes:**
```zig
// ast.zig
pub const FnDecl = struct {
    // ... existing fields
    is_async: bool, // ← already exists!
};

pub const Expr = union(enum) {
    // ... existing variants
    await_expr: struct {  // ← already exists!
        expr: *Expr,
        loc: SourceLocation,
    },
};
```

### Step 3: Promise/Future Type

Add built-in `Promise<T>` type for async values:

```zig
// ast.zig Type additions
pub const Type = union(enum) {
    // ... existing variants
    promise: *Type, // Promise<T>
};
```

**Type checking:**
- `async fn foo() -> T` has type `fn() -> Promise<T>`
- `await promise_expr` where `promise_expr: Promise<T>` yields type `T`

### Step 4: WASM Async Codegen

**Challenge:** WASM doesn't have native async/await. We need to:

1. **Transform async functions into state machines**
2. **Generate suspend/resume points**
3. **Use Asyncify or manual CPS transformation**

**Approach A: Asyncify** (easier, larger binary)
- Use Binaryen's Asyncify pass
- Works with existing WASM toolchain
- ~50KB overhead

**Approach B: Manual CPS** (harder, smaller binary)
- Transform to continuation-passing style manually
- Generate explicit state machine
- Full control, optimized

**Recommendation:** Start with **Asyncify**, migrate to manual CPS in Phase 3.

**Codegen strategy:**
```zig
// For async fn:
fn genAsyncFnDecl(self: *WasmCodegen, fn_decl: *ast.FnDecl) !void {
    // Generate wrapper that returns promise handle
    try self.emit("(func ${s}_async (export \"{s}\") (result i32)\n",
        .{fn_decl.name, fn_decl.name});

    // Call Asyncify-wrapped version
    try self.emit("  call ${s}_impl\n", .{fn_decl.name});

    // Return promise ID
    try self.emit(")\n");

    // Generate actual implementation
    try self.genFnDeclImpl(fn_decl);
}
```

### Step 5: Nexus Host Functions

Create WASM imports for Nexus IO:

```wat
;; HTTP client
(import "nexus" "http_get" (func $nexus_http_get
    (param i32 i32)   ;; url ptr, url len
    (result i32)))    ;; promise handle

;; Filesystem
(import "nexus" "fs_read_file" (func $nexus_fs_read_file
    (param i32 i32)   ;; path ptr, path len
    (result i32)))    ;; promise handle

;; Timer
(import "nexus" "set_timeout" (func $nexus_set_timeout
    (param i32 i32)   ;; callback ptr, delay_ms
    (result i32)))    ;; timer id
```

**Nexus side implementation:**
```zig
// In nexus/src/wasm/host.zig
pub fn registerZigScriptHostFunctions(instance: *WasmInstance) !void {
    // Register HTTP
    try instance.addHostFunction("nexus", "http_get", httpGet);
    try instance.addHostFunction("nexus", "fs_read_file", fsReadFile);
    try instance.addHostFunction("nexus", "set_timeout", setTimeout);
}

fn httpGet(url_ptr: i32, url_len: i32) i32 {
    // Get URL from WASM memory
    const url = instance.memory.data[url_ptr..url_ptr+url_len];

    // Create promise
    const promise_id = promise_registry.create();

    // Enqueue async HTTP request
    nexus.http.get(url) catch |err| {
        promise_registry.reject(promise_id, err);
        return promise_id;
    } then |response| {
        // Write response to WASM memory
        const response_ptr = writeToWasmMemory(response);
        promise_registry.resolve(promise_id, response_ptr);
    };

    return promise_id;
}
```

### Step 6: ZigScript Stdlib Updates

```zs
// stdlib/http.zs
export module http {
    pub struct Response {
        status: i32,
        headers: Map<string, string>,
        body: string,
    }

    pub async fn get(url: string) -> Result<Response, Error> {
        // Calls host function via extern
        let promise_id = extern_http_get(url.ptr, url.len);
        let response_ptr = await promise_await(promise_id);

        // Deserialize response from WASM memory
        let response = Response.fromPtr(response_ptr);

        if response.status >= 400 {
            return Err(Error.Http(response.status));
        }

        return Ok(response);
    }

    pub async fn post(url: string, body: string) -> Result<Response, Error> {
        // Similar...
    }
}
```

### Step 7: Error Propagation with `?`

Add syntactic sugar for Result unwrapping:

```zs
// Before:
let user = match fetchUser(id) {
    Ok(u) => u,
    Err(e) => return Err(e),
};

// After:
let user = fetchUser(id)?;
```

**Parser:**
```zig
// In parsePostfix
.question => {
    try self.advance();
    expr = ast.Expr{
        .try_expr = .{  // Already exists!
            .expr = try self.ast_builder.createExpr(expr),
            .loc = loc,
        },
    };
}
```

**Codegen:**
```zig
fn genTryExpr(self: *WasmCodegen, try_expr: *ast.Expr.try_expr) !void {
    // Generate:
    // 1. Evaluate expression (returns Result)
    // 2. Check if Err variant
    // 3. If Err: return early with error
    // 4. If Ok: unwrap value

    try self.genExpr(try_expr.expr);

    // Assuming Result is represented as {tag: i32, value: T}
    try self.emit("  ;; Check Result tag\n");
    try self.emit("  local.get $result_temp\n");
    try self.emit("  i32.load offset=0  ;; Load tag\n");
    try self.emit("  i32.const 1  ;; Err tag\n");
    try self.emit("  i32.eq\n");
    try self.emit("  if\n");
    try self.emit("    ;; Return error\n");
    try self.emit("    local.get $result_temp\n");
    try self.emit("    return\n");
    try self.emit("  end\n");
    try self.emit("  ;; Unwrap Ok value\n");
    try self.emit("  local.get $result_temp\n");
    try self.emit("  i32.load offset=4\n");
}
```

## Testing Plan

### Test 1: Basic Async Function
```zs
// test_async.zs
async fn delay(ms: i32) -> Result<void, Error> {
    await nexus.setTimeout(ms);
    return Ok(());
}

async fn main() -> Result<void, Error> {
    console.log("Starting...");
    await delay(1000)?;
    console.log("Done!");
    return Ok(());
}
```

### Test 2: HTTP Request
```zs
// test_http.zs
async fn fetchUser(id: string) -> Result<User, Error> {
    let url = "https://jsonplaceholder.typicode.com/users/{id}";
    let response = await http.get(url)?;
    let user = json.decode<User>(response.body)?;
    return Ok(user);
}
```

### Test 3: Concurrent Requests
```zs
// test_concurrent.zs
async fn fetchMultiple() -> Result<void, Error> {
    let user1_promise = fetchUser("1");
    let user2_promise = fetchUser("2");

    let user1 = await user1_promise?;
    let user2 = await user2_promise?;

    console.log("User 1: {user1.name}");
    console.log("User 2: {user2.name}");

    return Ok(());
}
```

## Milestones

- **Milestone 1:** Global function table + fix type checking
- **Milestone 2:** Parse async/await syntax
- **Milestone 3:** Basic async codegen (stub promises)
- **Milestone 4:** Nexus host function integration
- **Milestone 5:** Real async HTTP example working
- **Milestone 6:** Error propagation with `?`
- **Milestone 7:** Full Phase 2 async/await complete

## Files to Modify

1. `src/typechecker.zig` - Add function symbol table
2. `src/parser.zig` - Already supports async/await ✅
3. `src/ast.zig` - Add Promise type
4. `src/codegen_wasm.zig` - Async function codegen
5. `src/stdlib.zig` - HTTP, FS async APIs

## Files to Create

1. `src/async_runtime.zig` - Promise registry, scheduler
2. `src/nexus_host.zig` - Nexus host function bindings
3. `examples/async_http.zs` - Async HTTP example
4. `examples/async_fs.zs` - Async FS example

## Next Steps

Let's start with **Milestone 1**: Fix the type checker by adding a global function symbol table so our examples compile!
