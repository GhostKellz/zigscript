fn main() -> i32 {
    let nums = [1, 2, 3, 4];

    // Map: create new array (currently copies)
    let doubled = nums.map(fn(x) => x * 2);

    // Reduce: sum all elements
    let sum = nums.reduce(fn(acc, x) => acc + x, 0);

    return sum;
}
