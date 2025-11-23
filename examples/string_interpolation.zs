// String Interpolation Example
// Tests the new {expr} syntax in strings

fn main() -> i32 {
    let name = "Alice";
    let age = 30;
    let city = "San Francisco";

    // Basic interpolation
    let greeting = "Hello, {name}!";

    // Multiple interpolations
    let bio = "{name} is {age} years old and lives in {city}";

    // Interpolation with expressions
    let next_year = "{name} will be {age + 1} next year";

    // Nested expressions
    let calc = "The result is {(age * 2) + 10}";

    return 0;
}
