// result_try.zs - Demonstrates Result<T,E> and ? operator
// Phase 2 error propagation example

// Note: This example shows syntax but won't fully compile until
// Result type is properly implemented in the compiler

// Divide function that returns Result
fn divide(a: i32, b: i32) -> i32 {
  // Simplified - actual Result type would be Result<i32, string>
  if b == 0 {
    return 0;
  }
  return a;
}

// Chain operations with ? operator (conceptual)
fn calculate(x: i32, y: i32, z: i32) -> i32 {
  // In full implementation, this would be:
  // let step1 = divide(x, y)?;
  // let step2 = divide(step1, z)?;
  // return step2;

  let step1: i32 = divide(x, y);
  let step2: i32 = divide(step1, z);
  return step2;
}

fn main() -> i32 {
  let result: i32 = calculate(100, 10, 2);
  return result;
}
