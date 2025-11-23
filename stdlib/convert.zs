// Type conversion utilities for ZigScript

// Convert i32 to f64
extern fn i32_to_f64(x: i32) -> f64;

// Convert f64 to i32 (truncate)
extern fn f64_to_i32(x: f64) -> i32;

// Convert f64 to i32 (round)
extern fn f64_to_i32_round(x: f64) -> i32;

// String conversion functions
extern fn i32_to_string(x: i32) -> string;
extern fn f64_to_string(x: f64) -> string;
extern fn bool_to_string(x: bool) -> string;

// Parse string to numbers
extern fn parse_i32(s: string) -> i32;
extern fn parse_f64(s: string) -> f64;

// WASM-level conversion helpers
// These map directly to WASM instructions

fn toF64(x: i32) -> f64 {
    // Should emit: f64.convert_i32_s
    return i32_to_f64(x);
}

fn toI32(x: f64) -> i32 {
    // Should emit: i32.trunc_f64_s
    return f64_to_i32(x);
}

fn toI32Round(x: f64) -> i32 {
    // Should emit: i32.trunc_f64_s with rounding
    return f64_to_i32_round(x);
}

// Floor for f64 (WASM f64.floor)
extern fn floorf(x: f64) -> f64;

// Ceil for f64 (WASM f64.ceil)
extern fn ceilf(x: f64) -> f64;

// Truncate for f64 (WASM f64.trunc)
extern fn truncf(x: f64) -> f64;

// Nearest int for f64 (WASM f64.nearest)
extern fn roundf(x: f64) -> f64;

// Min for f64 (WASM f64.min)
extern fn minf_wasm(a: f64, b: f64) -> f64;

// Max for f64 (WASM f64.max)
extern fn maxf_wasm(a: f64, b: f64) -> f64;

// Copysign for f64 (WASM f64.copysign)
extern fn copysignf(x: f64, y: f64) -> f64;

// Sqrt for f64 (WASM f64.sqrt)
extern fn sqrtf_wasm(x: f64) -> f64;

// Abs for f64 (WASM f64.abs)
extern fn absf_wasm(x: f64) -> f64;
