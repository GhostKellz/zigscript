// async_basic.zs - Basic async function example

async fn delay(ms: i32) -> i32 {
  return ms;
}

async fn main() -> i32 {
  let result: i32 = await delay(1000);
  return result;
}
