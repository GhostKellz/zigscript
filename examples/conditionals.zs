// conditionals.zs - If/else statements

fn max(a: i32, b: i32) -> i32 {
  if a > b {
    return a;
  } else {
    return b;
  }
}

fn main() -> i32 {
  let x: i32 = 10;
  let y: i32 = 20;
  let result: i32 = max(x, y);
  return result;
}
