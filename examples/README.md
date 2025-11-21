# ZigScript Examples

This directory contains example ZigScript programs demonstrating Phase 1 features.

## Examples

### hello.zs
The simplest possible ZigScript program - returns 42.

```bash
zs build examples/hello.zs
```

### arithmetic.zs
Demonstrates basic arithmetic operations and function calls.

```bash
zs build examples/arithmetic.zs
```

### conditionals.zs
Shows if/else control flow and comparison operations.

```bash
zs build examples/conditionals.zs
```

## Running Examples

To compile an example:
```bash
zig build
./zig-out/bin/zs build examples/hello.zs
```

This will generate a `.wat` (WebAssembly Text) file that can be converted to binary WASM:
```bash
wat2wasm hello.wat -o hello.wasm
```

## Phase 1 Features Demonstrated

- ✓ Function declarations
- ✓ Basic types (i32, i64, f64, bool)
- ✓ Let declarations with type annotations
- ✓ Binary operations (+, -, *, /, ==, !=, <, >, etc.)
- ✓ If/else statements
- ✓ Return statements
- ✓ Function calls
