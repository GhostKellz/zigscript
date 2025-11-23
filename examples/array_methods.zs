fn main() -> i32 {
    let arr = [10, 20, 30];

    let len1 = arr.len();

    arr.push(40);
    let len2 = arr.len();

    let last = arr.pop();
    let len3 = arr.len();

    return len3;
}
