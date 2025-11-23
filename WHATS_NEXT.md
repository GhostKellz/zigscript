# 🚀 What's Next for ZigScript?

Based on the current state and roadmap analysis, here are the recommended next steps:

---

## ✅ What You Just Completed

**Tree-sitter Grammar + LSP Server = DONE! 🎉**

You've just completed two critical items from Phase 8:
- ✅ tree-sitter-zigscript grammar (COMPLETE)
- ✅ zsls (ZigScript Language Server) (ALL 11 FEATURES COMPLETE)

This is **HUGE** for developer experience!

---

## 🎯 Immediate Next Steps (Priority Order)

### 1. **Missing Core Language Features** ⚡ CRITICAL

These are language features that exist in the parser/type system but need **codegen** or are partially implemented:

#### 1.1 Lambda Functions / Closures
**Status**: Skeleton exists, needs full implementation
**Urgency**: HIGH - Required for `map()`, `filter()`, `reduce()`

**What's Missing**:
```zs
// This should work but doesn't yet:
let nums = [1, 2, 3];
let doubled = nums.map(fn(x: i32) -> i32 { return x * 2; });
```

**Implementation Needed**:
- Lambda expression parsing (partially done)
- Closure capture analysis
- WASM codegen for anonymous functions
- Function type compatibility checking

**Time**: 1-2 weeks
**Impact**: Unlocks functional programming paradigm

---

#### 1.2 Array Literals & Operations
**Status**: Placeholders exist, needs codegen
**Urgency**: HIGH - Essential data structure

**What's Missing**:
```zs
// Array creation
let arr = [1, 2, 3, 4, 5];  // Doesn't compile yet

// Array operations (exist but limited)
arr.push(6);     // ✅ Works
arr[0] = 10;     // ✅ Works
let x = arr[2];  // ✅ Works
```

**Implementation Needed**:
- Array literal WASM codegen
- Memory allocation for arrays
- Array type inference improvements
- Spread operator `...arr`

**Time**: 1 week
**Impact**: Critical for real-world programs

---

#### 1.3 Struct Literals & Methods
**Status**: Parsing done, codegen TODO
**Urgency**: HIGH - Object-oriented features

**What's Missing**:
```zs
struct Point {
    x: i32,
    y: i32,

    fn distance(self) -> f64 {  // Parsed but no codegen
        return sqrt(self.x * self.x + self.y * self.y);
    }
}

let p = Point { x: 10, y: 20 };  // Literal doesn't compile
```

**Implementation Needed**:
- Struct literal memory layout
- Method call codegen (self parameter)
- Constructor functions
- Struct field access optimization

**Time**: 1-2 weeks
**Impact**: Enables OOP patterns

---

#### 1.4 Match Expression Codegen
**Status**: Parsing done, codegen incomplete
**Urgency**: MEDIUM - Pattern matching is powerful

**What's Missing**:
```zs
match response {
    Ok(value) => processValue(value),
    Err(e) => handleError(e),
}
```

**Implementation Needed**:
- Pattern matching compilation
- Exhaustiveness checking
- Enum variant extraction
- Jump table optimization

**Time**: 1 week
**Impact**: Improves error handling ergonomics

---

### 2. **Standard Library Expansion** 📚 HIGH PRIORITY

**Current**: Basic modules (http, fs, string, array, math)
**Needed**: Comprehensive stdlib

#### 2.1 Essential Modules to Add:

1. **Collections**
   ```zs
   // HashMap, HashSet, Queue, Stack
   import { HashMap } from "std/collections";

   let map = HashMap.new<str, i32>();
   map.set("answer", 42);
   ```

2. **DateTime**
   ```zs
   import { DateTime } from "std/time";

   let now = DateTime.now();
   let formatted = now.format("YYYY-MM-DD");
   ```

3. **Crypto**
   ```zs
   import { sha256, random } from "std/crypto";

   let hash = sha256("hello world");
   let uuid = random.uuid();
   ```

4. **Testing Framework**
   ```zs
   import { test, expect } from "std/testing";

   test("addition works", fn() {
       expect(2 + 2).toBe(4);
   });
   ```

5. **Path/URL Utilities**
   ```zs
   import { Path, URL } from "std/path";

   let p = Path.join("foo", "bar", "baz.txt");
   let url = URL.parse("https://example.com/api?q=test");
   ```

**Time**: 2-3 weeks for essentials
**Impact**: Makes ZigScript practical for real apps

---

### 3. **Package Manager (ZIM)** 📦 CRITICAL FOR ECOSYSTEM

**Current**: Basic `zim.json` structure exists
**Needed**: Full package management

#### 3.1 CLI Tool: `zim`
```bash
zim init                    # Create new project
zim install axios           # Install package
zim install --dev prettier  # Dev dependency
zim publish                 # Publish to registry
zim run build               # Run script
zim test                    # Run tests
```

#### 3.2 Package Structure
```json
{
  "name": "my-app",
  "version": "1.0.0",
  "dependencies": {
    "http-client": "^2.1.0",
    "json": "^1.0.0"
  },
  "devDependencies": {
    "test-framework": "^0.5.0"
  },
  "scripts": {
    "build": "zs build src/main.zs",
    "test": "zs test tests/",
    "dev": "zs watch src/main.zs"
  }
}
```

#### 3.3 Registry Backend
- Package hosting (S3/CDN)
- Search API
- Version resolution
- Authentication

**Time**: 3-4 weeks
**Impact**: Enables ecosystem growth

---

### 4. **Improved Error Messages** 🐛 HIGH VALUE

**Current**: Basic error reporting
**Needed**: Rust/TypeScript-level diagnostics

**Examples**:

**Before**:
```
Error: Type mismatch on line 42
```

**After**:
```
Error: Type mismatch in function call
  ┌─ src/main.zs:42:5
  │
42│     greet(123);
  │           ^^^ Expected type 'str', found 'i32'
  │
  = help: Convert to string with `toString(123)`
  = note: Function 'greet' is defined at src/main.zs:10
```

**Features**:
- Source code snippets
- Colored output
- Suggestions for fixes
- Related errors grouped
- Help messages

**Time**: 1 week
**Impact**: Much better DX

---

### 5. **Documentation Generator** 📖 MEDIUM PRIORITY

**Goal**: Auto-generate docs from code comments

```zs
/// Calculates the factorial of a number.
///
/// # Arguments
/// * `n` - The number to calculate factorial for
///
/// # Returns
/// The factorial of n
///
/// # Example
/// ```zs
/// let result = factorial(5);  // returns 120
/// ```
fn factorial(n: i32) -> i32 {
    // ...
}
```

**Output**: HTML docs like Rust's rustdoc or TypeScript's TSDoc

**Time**: 1-2 weeks
**Impact**: Essential for library adoption

---

### 6. **VS Code Extension** 🎨 HIGH VALUE

**Now that you have tree-sitter + LSP**, create a proper VS Code extension:

```json
{
  "name": "zigscript",
  "displayName": "ZigScript",
  "description": "ZigScript language support",
  "version": "0.1.0",
  "publisher": "yourname",
  "engines": {
    "vscode": "^1.80.0"
  },
  "activationEvents": [
    "onLanguage:zigscript"
  ],
  "main": "./out/extension.js",
  "contributes": {
    "languages": [{
      "id": "zigscript",
      "extensions": [".zs"],
      "aliases": ["ZigScript", "zs"]
    }],
    "grammars": [{
      "language": "zigscript",
      "scopeName": "source.zigscript",
      "path": "./syntaxes/zigscript.tmLanguage.json"
    }]
  }
}
```

**Features**:
- Syntax highlighting (from tree-sitter)
- LSP integration (zsls)
- Snippets
- Code formatting
- Debugging support

**Time**: 3-5 days
**Impact**: Makes ZigScript accessible to millions

---

### 7. **Benchmarks & Performance** ⚡ IMPORTANT

**Goal**: Prove ZigScript is fast

#### 7.1 Benchmark Suite
```zs
// benchmarks/fib.zs
fn fibonacci(n: i32) -> i32 {
    if n <= 1 { return n; }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// Compare with JS, TS, Python, etc.
```

#### 7.2 Optimization Passes
- Constant folding
- Dead code elimination
- Tail call optimization
- Inline expansion

**Time**: 2-3 weeks
**Impact**: Marketing advantage

---

### 8. **Real-World Example Apps** 🌍 CRITICAL FOR ADOPTION

Build showcase applications:

#### 8.1 TODO MVC
Classic TODO app with:
- HTTP API
- JSON persistence
- Async operations
- Error handling

#### 8.2 REST API Server
```zs
import { serve } from "std/http";

async fn handler(req: Request) -> Response {
    match req.method {
        "GET" => handleGet(req),
        "POST" => handlePost(req),
        _ => Response.json({ error: "Not Found" }, 404),
    }
}

serve(handler, { port: 3000 });
```

#### 8.3 CLI Tool
File processor, build tool, or code generator

**Time**: 1-2 weeks total
**Impact**: Demonstrates real-world viability

---

## 🗺️ Recommended Roadmap (Next 3 Months)

### Month 1: Core Language Completion
**Week 1-2**:
- ✅ Array literals + operations
- ✅ Lambda functions basics

**Week 3-4**:
- ✅ Struct literals + methods
- ✅ Match expression codegen

**Deliverable**: All language features functional

---

### Month 2: Developer Experience
**Week 1-2**:
- ✅ VS Code extension
- ✅ Improved error messages
- ✅ Documentation generator

**Week 3-4**:
- ✅ Standard library expansion
- ✅ Package manager (ZIM) basics

**Deliverable**: Pleasant development workflow

---

### Month 3: Ecosystem & Polish
**Week 1-2**:
- ✅ Real-world example apps
- ✅ Benchmark suite
- ✅ Performance optimizations

**Week 3-4**:
- ✅ Website + landing page
- ✅ Tutorial series
- ✅ Package registry beta

**Deliverable**: Public beta release ready

---

## 🎯 Critical Path (Must-Have for v1.0)

1. **Array literals** - Can't do anything without arrays
2. **Lambda functions** - Needed for functional patterns
3. **Struct literals/methods** - OOP is essential
4. **Standard library** - Need fs, http, json, etc.
5. **Package manager** - Ecosystem depends on it
6. **VS Code extension** - Accessibility
7. **Documentation** - Can't grow without docs
8. **Example apps** - Proof of viability

---

## 💡 Optional (Nice to Have)

- Debugger integration (DAP)
- Hot reload / watch mode
- REPL (interactive shell)
- Playground (web-based)
- NPM interop (use existing packages)
- TypeScript definitions generator

---

## 📊 Current State vs Ideal

| Feature | Current | Needed for v1.0 |
|---------|---------|-----------------|
| Parser | ✅ 95% | ✅ 100% |
| Type System | ✅ 90% | ✅ 100% |
| Codegen | ⚠️ 70% | ✅ 100% |
| Stdlib | ⚠️ 30% | ✅ 80% |
| Tooling | ✅ 80% (LSP done!) | ✅ 90% |
| Docs | ❌ 10% | ✅ 80% |
| Examples | ⚠️ 40% | ✅ 80% |
| Package Manager | ❌ 20% | ✅ 80% |

---

## 🚀 Quick Wins (Do These First!)

1. **Array literal codegen** (3-4 days)
   - High impact, medium effort
   - Unlocks real programs

2. **Struct literal codegen** (3-5 days)
   - High impact, medium effort
   - Enables data modeling

3. **VS Code extension** (2-3 days)
   - You already have LSP!
   - Just package it up

4. **Better error messages** (5-7 days)
   - High developer satisfaction
   - Low-hanging fruit

5. **Example TODO app** (2-3 days)
   - Shows real-world usage
   - Great for README

---

## 🎉 Recommended: Start Here

**Next immediate task**:

### Implement Array Literal Codegen

**Why**:
- Most critical missing feature
- Unblocks many examples
- Required for stdlib expansion
- Relatively straightforward

**Implementation**:
```zig
// In codegen_wasm.zig
fn generateArrayLiteral(
    self: *CodeGenerator,
    array_expr: *ast.ArrayLiteralExpr
) !void {
    // 1. Allocate memory for array
    // 2. Store length
    // 3. Store each element
    // 4. Return array pointer
}
```

**Test with**:
```zs
let nums = [1, 2, 3, 4, 5];
let sum = nums.reduce(fn(a, b) { return a + b; }, 0);
```

**After this**: Move to lambdas, then structs!

---

## 📞 Questions to Consider

1. **Target Audience**: Web developers? Systems programmers? Both?
2. **Killer Feature**: What makes ZigScript unique? (Async+WASM?)
3. **Performance Goal**: Faster than JS? Match TypeScript?
4. **NPM Compatibility**: Should we support importing npm packages?
5. **Browser First?**: Focus on browser WASM or Node.js-like runtime?

---

## Summary

**You've completed Phase 8 (tooling)! 🎉**

**Next priority**:
1. Core language features (arrays, lambdas, structs)
2. Standard library expansion
3. VS Code extension
4. Real-world examples
5. Package manager

**With these done, ZigScript becomes truly usable!**
