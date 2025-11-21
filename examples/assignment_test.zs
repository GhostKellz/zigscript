fn testAssignment() -> i32 {
  let x: i32 = 10;
  x = x + 5;
  x = x * 2;
  return x;
}

fn testWhileWithAssignment() -> i32 {
  let sum: i32 = 0;
  let i: i32 = 0;

  while i < 10 {
    sum = sum + i;
    i = i + 1;
  }

  return sum;
}

fn main() -> i32 {
  let result: i32 = testWhileWithAssignment();
  return result;
}
