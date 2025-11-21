// ZigScript + Nexus Runtime Example
// A complete async HTTP API example demonstrating real-world usage

struct User {
  id: i32,
  name: string,
  email: string,
}

struct ApiResponse {
  status: i32,
  data: string,
}

// Fetch a user from the API
async fn fetchUser(user_id: i32) -> i32 {
  // Simulate HTTP GET request
  // In real Nexus integration, this would call actual HTTP
  let wait: i32 = user_id * 100;
  return wait;
}

// Fetch multiple users in parallel
async fn fetchMultipleUsers() -> i32 {
  let user1: i32 = await fetchUser(1);
  let user2: i32 = await fetchUser(2);
  let user3: i32 = await fetchUser(3);

  let total: i32 = user1 + user2 + user3;
  return total;
}

// Process user data
fn processUserData(data: i32) -> i32 {
  let processed: i32 = data * 2;
  return processed;
}

// Main entry point
async fn main() -> i32 {
  // Fetch users asynchronously
  let users_data: i32 = await fetchMultipleUsers();

  // Process the data
  let result: i32 = processUserData(users_data);

  // Return final result
  return result;
}
