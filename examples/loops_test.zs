fn testWhile() -> i32 {
  // While loop test - just verify it parses and generates code
  let x: i32 = 0;
  while x < 5 {
    let y: i32 = x + 1;
  }
  return 42;
}

fn main() -> i32 {
  let result: i32 = testWhile();
  return result;
}
