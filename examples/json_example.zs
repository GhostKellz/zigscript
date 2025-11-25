// JSON encode/decode example

struct User {
    id: i32,
    name: string,
    active: bool,
}

fn main() -> i32 {
    // Create a user
    let user = User {
        id: 1,
        name: "Alice",
        active: true,
    };

    // In a full implementation, this would work:
    // let json_str = JSON.encode(user)?;
    // console.log(json_str);
    // let decoded = JSON.decode<User>(json_str)?;

    // For now, just return success
    return user.id;
}
