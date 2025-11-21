// phase3_demo.zs - Demonstrates Phase 3 features
// JSON, match expressions, for loops, enhanced error handling

// User struct for JSON demo
struct User {
  id: i32,
  name: string,
  active: bool,
}

// Status enum for pattern matching
enum Status {
  Active,
  Inactive,
  Pending,
}

// Function demonstrating for loops
fn sumArray(numbers: [i32]) -> i32 {
  let total: i32 = 0;

  // Phase 3: for loop (syntax defined, codegen TBD)
  // for n in numbers {
  //   total = total + n;
  // }

  // For now, use manual iteration
  return total;
}

// Function demonstrating pattern matching (future)
fn getStatusMessage(status: Status) -> string {
  // Phase 3: match expression (syntax defined, codegen TBD)
  // match status {
  //   Active => "User is active",
  //   Inactive => "User is inactive",
  //   Pending => "User is pending",
  // }

  // For now, return placeholder
  return "status message";
}

// Async function with JSON (conceptual)
async fn fetchAndParseUser(user_id: i32) -> i32 {
  // Simulate fetching data
  let data: i32 = await delay(100);

  // In full implementation:
  // let json_str = await http.get("/users/" + user_id);
  // let user = json.parse(json_str)?;
  // return user.id;

  return data + user_id;
}

async fn delay(ms: i32) -> i32 {
  return ms;
}

// Main function showing chained async operations
async fn main() -> i32 {
  // Async operation
  let user_id: i32 = await fetchAndParseUser(1);

  // In full implementation:
  // let numbers = [1, 2, 3, 4, 5];
  // let sum = sumArray(numbers);

  return user_id;
}
