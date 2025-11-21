// async_http.zs - Async HTTP example with Nexus integration
// Demonstrates Phase 2 async/await functionality

// Simulate async delay
async fn delay(ms: i32) -> i32 {
  return ms;
}

// Fetch user data (simulated)
async fn fetchUser(user_id: i32) -> i32 {
  // Simulate network delay
  let wait: i32 = await delay(1000);

  // Return user ID as result
  return user_id + wait;
}

// Fetch multiple users concurrently
async fn fetchMultipleUsers() -> i32 {
  let user1: i32 = await fetchUser(1);
  let user2: i32 = await fetchUser(2);

  return user1 + user2;
}

// Main async function
async fn main() -> i32 {
  let result: i32 = await fetchMultipleUsers();
  return result;
}
