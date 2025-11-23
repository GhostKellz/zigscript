# ZigScript Priority Matrix

## 🎯 Quick Decision Guide

```
HIGH IMPACT + LOW EFFORT = DO NOW! ⚡
HIGH IMPACT + HIGH EFFORT = PLAN CAREFULLY 📋
LOW IMPACT + LOW EFFORT = FILL GAPS 🔧
LOW IMPACT + HIGH EFFORT = DEFER ⏸️
```

---

## Immediate Priorities (Next 2-4 Weeks)

### ⚡ DO NOW (High Impact + Low-Medium Effort)

| Task | Impact | Effort | Days | Why Now? |
|------|--------|--------|------|----------|
| **Array Literals** | 🔥🔥🔥🔥🔥 | 3d | 3-4 | Unblocks everything |
| **Struct Literals** | 🔥🔥🔥🔥 | 4d | 3-5 | Essential for data |
| **VS Code Extension** | 🔥🔥🔥🔥 | 2d | 2-3 | LSP already done! |
| **Better Errors** | 🔥🔥🔥 | 5d | 5-7 | Great DX win |
| **Example TODO App** | 🔥🔥🔥 | 2d | 2-3 | Proves viability |

**Total**: ~2-3 weeks, massive value unlock

---

### 📋 PLAN CAREFULLY (High Impact + High Effort)

| Task | Impact | Effort | Weeks | Dependencies |
|------|--------|--------|-------|--------------|
| **Lambda Functions** | 🔥🔥🔥🔥🔥 | 2w | 1-2 | None |
| **Stdlib Expansion** | 🔥🔥🔥🔥 | 3w | 2-3 | Arrays, Structs |
| **Package Manager (ZIM)** | 🔥🔥🔥🔥🔥 | 4w | 3-4 | Stdlib, Examples |
| **Match Codegen** | 🔥🔥🔥 | 1w | 1 | Enums working |
| **Documentation Gen** | 🔥🔥🔥 | 2w | 1-2 | Stdlib complete |

**Timeline**: ~3 months for all

---

### 🔧 FILL GAPS (Low Effort, Nice to Have)

| Task | Impact | Effort | Days |
|------|--------|--------|------|
| Benchmarks | 🔥🔥 | 3d | 2-3 |
| Watch mode | 🔥🔥 | 2d | 1-2 |
| REPL | 🔥🔥 | 5d | 3-5 |
| More examples | 🔥 | 1d each | - |

---

### ⏸️ DEFER (Low ROI for Now)

| Task | Why Defer |
|------|-----------|
| Debugger (DAP) | Chrome DevTools work for now |
| NPM interop | Complex, fragile, non-essential |
| Playground | Can use local dev first |
| Advanced optimizations | Premature optimization |

---

## 📅 Recommended 90-Day Sprint

### Weeks 1-2: Language Completion Sprint

**Goal**: All core features working

```
Week 1:
├── Mon-Tue: Array literal codegen ✅
├── Wed-Thu: Struct literal codegen ✅
└── Fri: Testing & bug fixes

Week 2:
├── Mon-Wed: Lambda functions & closures ✅
├── Thu: Match expression codegen ✅
└── Fri: Integration testing
```

**Deliverable**: Feature-complete language

---

### Weeks 3-4: Developer Experience Sprint

**Goal**: Pleasant development workflow

```
Week 3:
├── Mon: VS Code extension skeleton
├── Tue-Wed: LSP integration + snippets ✅
├── Thu-Fri: Better error messages ✅

Week 4:
├── Mon-Tue: Documentation generator
├── Wed: Example TODO app
├── Thu-Fri: Example REST API
```

**Deliverable**: Professional tooling

---

### Weeks 5-8: Standard Library Sprint

**Goal**: Practical stdlib for real apps

```
Week 5-6: Core Modules
├── Collections (HashMap, Set, etc.)
├── DateTime & Time utilities
├── Path & URL utilities
└── Testing framework

Week 7-8: Integration Modules
├── Enhanced HTTP client
├── File system operations
├── Crypto utilities
└── JSON improvements
```

**Deliverable**: Production-ready stdlib

---

### Weeks 9-12: Ecosystem Sprint

**Goal**: Package manager + community

```
Week 9-10: Package Manager
├── ZIM CLI tool (init, install, publish)
├── Lock file system
├── Dependency resolution
└── Local testing

Week 11: Polish
├── Benchmark suite
├── Performance optimizations
├── More examples
└── Bug fixes

Week 12: Launch Prep
├── Website / landing page
├── Tutorial series
├── Registry backend (basic)
└── Beta release!
```

**Deliverable**: Public beta ready

---

## 🎯 Success Criteria for v1.0

### Must Have ✅
- [ ] All language features working (arrays, structs, lambdas)
- [ ] Standard library (20+ modules)
- [ ] Package manager (basic)
- [ ] VS Code extension
- [ ] Good error messages
- [ ] 5+ real-world examples
- [ ] Documentation

### Nice to Have 🌟
- [ ] Benchmarks showing competitive performance
- [ ] REPL for interactive development
- [ ] 50+ packages in registry
- [ ] Tutorial series (10+ lessons)
- [ ] Playground (web-based)

### Can Wait 💤
- [ ] Debugger integration
- [ ] Hot reload
- [ ] Advanced optimizations
- [ ] NPM compatibility

---

## 💡 Current Momentum

### ✅ Recently Completed (Massive!)
- Tree-sitter grammar (DONE)
- Full LSP server with 11 features (DONE)
- Semantic analysis + type checking (DONE)
- Workspace symbols (DONE)
- Code formatting (DONE)

### 🔥 Ready to Build On
You have the **BEST DEVELOPER TOOLING** already!
- Syntax highlighting (tree-sitter)
- LSP (zsls)
- Type information
- Go-to-definition
- Auto-completion
- Formatting

**Now you need**:
- Core language features → WASM
- Standard library → More modules
- Package ecosystem → ZIM

---

## 🚀 The Path to 1000 Users

```
Week 0 (NOW):
└── You have: Great tools, incomplete language

Week 4:
└── You have: Complete language, great tools

Week 8:
└── You have: Complete language, great tools, useful stdlib

Week 12:
└── You have: Everything + package manager
    └── Launch beta!
        └── Get first 10 users

Week 16:
└── 100 users (if good examples + docs)

Week 24:
└── 1000 users (if packages + community)
```

**Bottleneck**: Need working arrays/structs/lambdas ASAP!

---

## 🎓 Lessons from Other Languages

### What Made Them Successful?

**TypeScript**:
- Excellent VS Code integration ✅ (You have this!)
- Incremental adoption (JS compatible) ⚠️ (Not your goal)
- Strong stdlib ❌ (You need this)

**Rust**:
- Incredible error messages ⚠️ (Working on this)
- Cargo (package manager) ❌ (You need this)
- Strong community ❌ (Will come)

**Go**:
- Simple, complete stdlib ❌ (You need this)
- Fast compilation ✅ (Zig is fast)
- Excellent tooling ✅ (You have this!)

**Deno**:
- Modern standard library ❌ (You need this)
- Built-in TypeScript ✅ (You have types)
- Good DX ✅ (You have this!)

**Takeaway**: You have the tooling! Now need stdlib + packages.

---

## 🏁 Start Here Tomorrow

### Day 1 Task: Array Literal Codegen

**File**: `src/codegen_wasm.zig`

**Add function**:
```zig
fn generateArrayLiteralExpr(
    self: *CodeGenerator,
    expr: *ast.Expression
) !void {
    const array_lit = expr.ArrayLiteral;

    // 1. Calculate size needed
    const elem_size: u32 = 4; // i32 for now
    const total_size = elem_size * @as(u32, array_lit.elements.len);

    // 2. Allocate memory (call malloc or use linear allocator)
    try self.writer.writeAll("  (call $malloc ");
    try self.writer.print("(i32.const {}))\n", .{total_size + 4});

    // 3. Store length at offset 0
    try self.writer.writeAll("  (local.set $arr_ptr)\n");
    try self.writer.writeAll("  (i32.store (local.get $arr_ptr) ");
    try self.writer.print("(i32.const {}))\n", .{array_lit.elements.len});

    // 4. Store each element
    for (array_lit.elements, 0..) |elem, i| {
        const offset = 4 + (i * elem_size);
        try self.generateExpression(elem);
        try self.writer.writeAll("  (i32.store ");
        try self.writer.print("(i32.add (local.get $arr_ptr) (i32.const {})) ", .{offset});
        try self.writer.writeAll(")\n");
    }

    // 5. Return pointer
    try self.writer.writeAll("  (local.get $arr_ptr)\n");
}
```

**Test with**:
```zs
let nums = [1, 2, 3];
```

**Expected**: Compiles to WASM!

---

## 📊 Progress Tracker

| Phase | Status | Completion |
|-------|--------|-----------|
| Parser | ✅ | 95% |
| Type System | ✅ | 90% |
| **Codegen** | ⚠️ | **70%** ← FOCUS HERE |
| Stdlib | ⚠️ | 30% |
| Tooling | ✅ | 80% |
| Docs | ❌ | 10% |
| Ecosystem | ❌ | 20% |

**Blocker**: Codegen gaps (arrays, structs, lambdas)

---

## 🎯 Summary: What's Next?

**Option A: Safe & Steady** (Recommended)
1. Array literals (1 week)
2. Struct literals (1 week)
3. VS Code extension (3 days)
4. Lambda functions (2 weeks)
5. Stdlib expansion (3 weeks)

**Timeline**: 2 months to feature-complete

**Option B: Move Fast & Break Things**
1. Do all codegen in 2 weeks (intense!)
2. Package manager in week 3-4
3. Examples week 5
4. Beta launch week 6

**Timeline**: 6 weeks to beta (risky but exciting!)

**Recommended**: **Option A** - Steady quality over speed

---

**Next Commit**: Array literal codegen! 🚀
