fn testForLoop() -> i32 {
  let arr: [i32] = [1, 2, 3, 4, 5];

  // For loop test - iterate over array
  for item in arr {
    let doubled: i32 = item + item;
  }

  return 42;
}

fn main() -> i32 {
  let result: i32 = testForLoop();
  return result;
}
