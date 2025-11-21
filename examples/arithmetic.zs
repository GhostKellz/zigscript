// arithmetic.zs - Basic arithmetic operations

fn add(a: i32, b: i32) -> i32 {
  return a + b;
}

fn multiply(x: i32, y: i32) -> i32 {
  return x * y;
}

fn main() -> i32 {
  let result: i32 = add(10, 20);
  let product: i32 = multiply(result, 2);
  return product;
}
