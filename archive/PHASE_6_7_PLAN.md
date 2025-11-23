# ZigScript Phase 6 & 7 Implementation Plan

## Overview
Transform ZigScript from a language MVP into a production-ready scripting language with full standard library, proper memory management, and module system.

---

## Phase 6: Core Language Features & Standard Library

### 6.1 String Interpolation ⭐ Priority 1
**Status:** Placeholder exists, needs real implementation

**Implementation:**
- Parse string literals with `{expr}` syntax
- Lexer: Track interpolation boundaries within strings
- Parser: Build interpolation AST node with expression list
- Codegen: Generate concatenation code for interpolated strings
- Support nested expressions: `"User {user.name} has {user.age + 1} years"`

**Files to modify:**
- `src/lexer.zig` - Add string interpolation token handling
- `src/parser.zig` - Parse interpolated expressions
- `src/ast.zig` - Add `string_interpolation` expression type
- `src/codegen_wasm.zig` - Generate string concat WASM code

**Example:**
```zs
let name = "Alice";
let age = 30;
let msg = "Hello, {name}! You are {age} years old.";
```

---

### 6.2 Array Operations ⭐ Priority 1
**Current:** Arrays parse but limited operations

**Implementation:**

#### 6.2.1 Array Indexing
```zs
let arr = [1, 2, 3];
let first = arr[0];      // indexing
arr[1] = 99;             // index assignment
```

- Parser: Add index expression `expr[expr]`
- Typechecker: Validate index type (i32) and array bounds
- Codegen: Generate load/store from memory offset

#### 6.2.2 Array Methods
```zs
let nums = [1, 2, 3];
nums.push(4);            // -> [1, 2, 3, 4]
let last = nums.pop();   // -> 4, nums = [1, 2, 3]
let len = nums.len();    // -> 3
```

**Built-in methods:**
- `push(item: T) -> void` - Append to end
- `pop() -> T?` - Remove from end
- `len() -> i32` - Get length
- `get(index: i32) -> T?` - Safe indexing
- `slice(start: i32, end: i32) -> [T]` - Create subarray

#### 6.2.3 Higher-Order Array Methods
```zs
let nums = [1, 2, 3, 4];
let doubled = nums.map(fn(x) => x * 2);        // [2, 4, 6, 8]
let evens = nums.filter(fn(x) => x % 2 == 0);  // [2, 4]
let sum = nums.reduce(fn(acc, x) => acc + x, 0); // 10
```

**Files to modify:**
- `src/ast.zig` - Add index_expr, method_call expressions
- `src/parser.zig` - Parse `expr[expr]` and `expr.method(args)`
- `src/typechecker.zig` - Type check array operations
- `src/codegen_wasm.zig` - Generate array manipulation code
- `src/stdlib.zig` - Add array utility functions

---

### 6.3 Struct Methods ⭐ Priority 2
**Current:** Structs exist, no methods

**Implementation:**
```zs
struct User {
  name: string,
  age: i32,

  fn greet() -> string {
    return "Hello, I'm {self.name}!";
  }

  fn birthday() -> void {
    self.age = self.age + 1;
  }
}

let user = User { name: "Alice", age: 30 };
let msg = user.greet();
user.birthday();
```

**Features:**
- `self` keyword for instance access
- Methods defined inside struct blocks
- Method calls: `instance.method(args)`
- Both mutable and immutable methods

**Files to modify:**
- `src/ast.zig` - Add methods to StructDef
- `src/parser.zig` - Parse method definitions
- `src/typechecker.zig` - Type check method calls with self
- `src/codegen_wasm.zig` - Generate method dispatch

---

### 6.4 Standard Library Expansion ⭐ Priority 2

#### 6.4.1 String Module
```zs
import { String } from "std/string";

let s = "hello world";
let parts = String.split(s, " ");        // ["hello", "world"]
let joined = String.join(parts, "-");    // "hello-world"
let upper = String.toUpper(s);           // "HELLO WORLD"
let contains = String.contains(s, "lo"); // true
let len = String.len(s);                 // 11
let substr = String.slice(s, 0, 5);      // "hello"
```

#### 6.4.2 Array Module
```zs
import { Array } from "std/array";

let nums = [3, 1, 4, 1, 5];
Array.sort(nums);                        // [1, 1, 3, 4, 5]
let reversed = Array.reverse(nums);
let unique = Array.unique(nums);         // [1, 3, 4, 5]
let contains = Array.contains(nums, 3);  // true
```

#### 6.4.3 Map Type
```zs
import { Map } from "std/collections";

let ages = Map.new<string, i32>();
ages.set("Alice", 30);
ages.set("Bob", 25);

let alice_age = ages.get("Alice");  // Some(30)
let has_bob = ages.has("Bob");      // true
let keys = ages.keys();             // ["Alice", "Bob"]
ages.delete("Bob");
```

#### 6.4.4 Set Type
```zs
import { Set } from "std/collections";

let nums = Set.new<i32>();
nums.add(1);
nums.add(2);
nums.add(1);  // duplicate ignored

let has = nums.has(1);     // true
let size = nums.size();    // 2
```

**Files to create:**
- `stdlib/string.zs` - String utilities
- `stdlib/array.zs` - Array utilities
- `stdlib/collections.zs` - Map, Set types
- `stdlib/math.zs` - Math functions

---

### 6.5 Error Handling Polish ⭐ Priority 3
**Current:** Result<T,E> exists, `?` operator works

**Improvements:**

#### 6.5.1 Better Error Propagation
```zs
fn readConfig(path: string) -> Result<Config, Error> {
  let content = fs.readFile(path)?;  // Auto-propagate errors
  let config = json.parse(content)?;
  return Ok(config);
}
```

#### 6.5.2 Error Matching
```zs
match result {
  Ok(value) => handleValue(value),
  Err(Error.NotFound) => handleNotFound(),
  Err(Error.PermissionDenied) => handlePermission(),
  Err(e) => handleGeneric(e),
}
```

#### 6.5.3 Try/Catch Alternative
```zs
let config = try {
  let path = env.get("CONFIG_PATH")?;
  let content = fs.readFile(path)?;
  json.parse(content)?
} catch (e) {
  Config.default()
};
```

**Files to modify:**
- `src/typechecker.zig` - Better Result type inference
- `src/parser.zig` - Add try/catch syntax
- `src/codegen_wasm.zig` - Generate error handling code

---

### 6.6 Memory Safety Improvements ⭐ Priority 3
**Current:** Bump allocator, basic tracking

**Improvements:**

#### 6.6.1 Reference Counting
- Track allocation references
- Automatic deallocation when ref count hits 0
- Cycle detection for circular references

#### 6.6.2 Arena Allocator per Scope
```zs
fn processData() {
  // All allocations in this scope use arena
  let data = allocLargeArray();
  let processed = transform(data);
  return processed;
  // Arena freed automatically at scope exit
}
```

#### 6.6.3 Lifetime Annotations (Optional)
```zs
fn longest<'a>(s1: &'a string, s2: &'a string) -> &'a string {
  if s1.len() > s2.len() { s1 } else { s2 }
}
```

**Files to modify:**
- `src/wasm_memory.zig` - Add ref counting
- `src/codegen_wasm.zig` - Generate inc/dec ref code
- Add memory leak detection tests

---

## Phase 7: Module System & Production Readiness

### 7.1 Module System ⭐ Priority 1
**Current:** Single-file compilation only

**Implementation:**

#### 7.1.1 Import/Export Syntax
```zs
// user.zs
export struct User {
  name: string,
  age: i32,
}

export fn createUser(name: string, age: i32) -> User {
  return User { name, age };
}

// main.zs
import { User, createUser } from "./user";

fn main() {
  let user = createUser("Alice", 30);
}
```

#### 7.1.2 Standard Library Imports
```zs
import { http } from "std/http";
import { fs } from "std/fs";
import * as json from "std/json";
```

#### 7.1.3 Module Resolution
- Relative imports: `./user`, `../utils/helper`
- Std imports: `std/http`, `std/fs`
- Package imports: `@author/package`

**Files to modify:**
- `src/ast.zig` - Add import/export statements
- `src/parser.zig` - Parse import/export
- Add `src/module_resolver.zig` - Resolve module paths
- Add `src/module_loader.zig` - Load and cache modules
- `src/compiler.zig` - Multi-file compilation

---

### 7.2 Package Manager Integration
**Goal:** Work with ZIM (your Zig package manager)

```toml
# zim.toml
[project]
name = "my-app"
language = "zigscript"
version = "0.1.0"

[dependencies]
http-client = { git = "gh/ghostkellz/zs-http", tag = "v0.1.0" }
```

---

### 7.3 Comprehensive Examples ⭐ Priority 1

#### 7.3.1 HTTP Server Example
```zs
// examples/http_server.zs
import { http } from "std/http";
import { json } from "std/json";

struct User {
  id: i32,
  name: string,
  email: string,
}

async fn handleRequest(req: http.Request) -> http.Response {
  match req.path {
    "/users" => {
      let users = [
        User { id: 1, name: "Alice", email: "alice@example.com" },
        User { id: 2, name: "Bob", email: "bob@example.com" },
      ];
      return http.json(users);
    },
    _ => return http.notFound(),
  }
}

async fn main() {
  let server = http.createServer(handleRequest);
  await server.listen(3000);
  console.log("Server running on :3000");
}
```

#### 7.3.2 CLI Tool Example
```zs
// examples/file_processor.zs
import { fs } from "std/fs";
import { String } from "std/string";

async fn processFile(path: string) -> Result<void, Error> {
  let content = await fs.readFile(path)?;
  let lines = String.split(content, "\n");

  for line in lines {
    if String.contains(line, "TODO") {
      console.log("Found TODO: {line}");
    }
  }

  return Ok(());
}

async fn main() {
  let args = env.args();
  if args.len() < 2 {
    console.error("Usage: process <file>");
    return;
  }

  match await processFile(args[1]) {
    Ok(_) => console.log("Done!"),
    Err(e) => console.error("Error: {e}"),
  }
}
```

#### 7.3.3 Data Processing Pipeline
```zs
// examples/data_pipeline.zs
import { fs } from "std/fs";
import { json } from "std/json";
import { Array } from "std/array";

struct Record {
  id: i32,
  value: f64,
  tags: [string],
}

async fn loadRecords(path: string) -> Result<[Record], Error> {
  let content = await fs.readFile(path)?;
  return json.parse<[Record]>(content);
}

fn filterByTag(records: [Record], tag: string) -> [Record] {
  return records.filter(fn(r) => Array.contains(r.tags, tag));
}

fn calculateAverage(records: [Record]) -> f64 {
  let sum = records.reduce(fn(acc, r) => acc + r.value, 0.0);
  return sum / records.len() as f64;
}

async fn main() {
  let records = await loadRecords("data.json")?;
  let filtered = filterByTag(records, "important");
  let avg = calculateAverage(filtered);

  console.log("Average value: {avg}");
}
```

---

## Implementation Order

### Sprint 1: Core Language Features (Days 1-3)
1. ✅ String interpolation - Most visible feature
2. ✅ Array indexing - Essential for usability
3. ✅ Basic array methods (push, pop, len)

### Sprint 2: Advanced Features (Days 4-6)
4. ✅ Struct methods with self
5. ✅ Higher-order array functions (map, filter, reduce)
6. ✅ Error handling improvements

### Sprint 3: Standard Library (Days 7-9)
7. ✅ String module
8. ✅ Array module
9. ✅ Collections (Map, Set)
10. ✅ Math module

### Sprint 4: Module System (Days 10-12)
11. ✅ Import/export syntax
12. ✅ Module resolver
13. ✅ Multi-file compilation

### Sprint 5: Memory & Examples (Days 13-15)
14. ✅ Memory safety improvements
15. ✅ Comprehensive examples
16. ✅ Documentation & testing

---

## Success Criteria

### Phase 6 Complete When:
- ✅ String interpolation works in all contexts
- ✅ Arrays have full CRUD operations + higher-order functions
- ✅ Structs can have methods with self
- ✅ Standard library has 50+ utility functions
- ✅ Error handling is ergonomic and type-safe
- ✅ Memory leaks are tracked and minimized

### Phase 7 Complete When:
- ✅ Multi-file projects compile correctly
- ✅ Import/export system is working
- ✅ At least 5 real-world examples run successfully
- ✅ Documentation covers all features
- ✅ ZigScript can build non-trivial applications

---

## Files to Create/Modify

### New Files:
- `stdlib/string.zs`
- `stdlib/array.zs`
- `stdlib/collections.zs`
- `stdlib/math.zs`
- `src/module_resolver.zig`
- `src/module_loader.zig`
- `examples/http_server.zs`
- `examples/file_processor.zs`
- `examples/data_pipeline.zs`
- `examples/todo_app.zs`
- `examples/json_validator.zs`

### Modified Files:
- `src/lexer.zig` - String interpolation tokens
- `src/parser.zig` - All new syntax
- `src/ast.zig` - New AST nodes
- `src/typechecker.zig` - Type checking for all features
- `src/codegen_wasm.zig` - WASM generation for all features
- `src/compiler.zig` - Multi-file compilation
- `src/wasm_memory.zig` - Memory improvements

---

## Testing Strategy

1. **Unit tests** for each feature in isolation
2. **Integration tests** for multi-file compilation
3. **Memory leak tests** for all allocations
4. **Example tests** - All examples must compile and run
5. **Regression tests** - Ensure old features still work

---

Let's start with Sprint 1!
