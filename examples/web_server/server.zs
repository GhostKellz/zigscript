// ZigScript Web Server Example
// Demonstrates async/await, HTTP, JSON, and file I/O on Nexus runtime

import { JSON } from "std/json";
import { http } from "std/http";
import { fs } from "std/fs";

struct User {
    id: i32,
    name: string,
    email: string,
}

struct Response {
    status: i32,
    message: string,
    data: User,
}

async fn handleRequest(path: string) -> i32 {
    console.log("Handling request: " ++ path);

    if (path == "/users") {
        return await getUsers();
    } else if (path == "/health") {
        console.log("Health check OK");
        return 0;
    } else {
        console.log("404 Not Found");
        return 404;
    }
}

async fn getUsers() -> i32 {
    // Create sample user
    let user = User {
        id: 1,
        name: "Alice",
        email: "alice@example.com",
    };

    // In a real app, we'd encode to JSON and return it
    // let json_str = JSON.encode(user)?;

    console.log("Returning user: " ++ user.name);

    return 0;
}

async fn fetchExternalData() -> i32 {
    console.log("Fetching external API...");

    // Make HTTP request using Nexus host function
    let response = await http.get("https://api.example.com/data");

    console.log("Got response from API");

    // Parse JSON response
    // let data = JSON.decode<Response>(response)?;

    return 0;
}

async fn saveData(filename: string, content: string) -> i32 {
    console.log("Saving data to: " ++ filename);

    // Write file using Nexus host function
    await fs.writeFile(filename, content);

    console.log("Data saved successfully");

    return 0;
}

async fn loadData(filename: string) -> i32 {
    console.log("Loading data from: " ++ filename);

    // Read file using Nexus host function
    let content = await fs.readFile(filename);

    console.log("Data loaded successfully");

    return 0;
}

fn main() -> i32 {
    console.log("🚀 ZigScript Web Server starting...");
    console.log("Running on Nexus runtime");

    // Demonstrate async operations
    // In a real server, this would be the event loop

    // Simulate request handling
    let status = await handleRequest("/users");

    console.log("✨ Server demo complete");

    return status;
}
