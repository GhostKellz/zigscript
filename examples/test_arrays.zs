// Test array functionality
fn main() -> i32 {
    let arr = [1, 2, 3];
    arr.push(4);
    arr.push(5);

    let last = arr.pop();
    let len = arr.len();

    return len; // Should be 4
}
