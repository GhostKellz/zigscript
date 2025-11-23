// Math utilities for ZigScript
// Provides common mathematical functions and constants

// Mathematical constants
let PI: f64 = 3.141592653589793;
let E: f64 = 2.718281828459045;

// Absolute value
fn abs(x: i32) -> i32 {
    if x < 0 {
        return -x;
    }
    return x;
}

fn absf(x: f64) -> f64 {
    if x < 0.0 {
        return -x;
    }
    return x;
}

// Minimum of two values
fn min(a: i32, b: i32) -> i32 {
    if a < b {
        return a;
    }
    return b;
}

fn minf(a: f64, b: f64) -> f64 {
    if a < b {
        return a;
    }
    return b;
}

// Maximum of two values
fn max(a: i32, b: i32) -> i32 {
    if a > b {
        return a;
    }
    return b;
}

fn maxf(a: f64, b: f64) -> f64 {
    if a > b {
        return a;
    }
    return b;
}

// Clamp value between min and max
fn clamp(value: i32, min_val: i32, max_val: i32) -> i32 {
    if value < min_val {
        return min_val;
    }
    if value > max_val {
        return max_val;
    }
    return value;
}

fn clampf(value: f64, min_val: f64, max_val: f64) -> f64 {
    if value < min_val {
        return min_val;
    }
    if value > max_val {
        return max_val;
    }
    return value;
}

// Power function (integer exponent)
fn pow(base: i32, exponent: i32) -> i32 {
    if exponent == 0 {
        return 1;
    }

    let result = 1;
    let exp = exponent;
    let b = base;

    if exp < 0 {
        return 0;
    }

    while exp > 0 {
        if exp % 2 == 1 {
            result = result * b;
        }
        b = b * b;
        exp = exp / 2;
    }

    return result;
}

// Square root (integer approximation using Newton's method)
fn sqrt(n: i32) -> i32 {
    if n <= 0 {
        return 0;
    }
    if n == 1 {
        return 1;
    }

    let x = n;
    let y = (x + 1) / 2;

    while y < x {
        x = y;
        y = (x + n / x) / 2;
    }

    return x;
}

// Floor (already integer for i32)
fn floor(x: i32) -> i32 {
    return x;
}

// Ceiling (already integer for i32)
fn ceil(x: i32) -> i32 {
    return x;
}

// Round (already integer for i32)
fn round(x: i32) -> i32 {
    return x;
}

// Sign function
fn sign(x: i32) -> i32 {
    if x > 0 {
        return 1;
    }
    if x < 0 {
        return -1;
    }
    return 0;
}

fn signf(x: f64) -> i32 {
    if x > 0.0 {
        return 1;
    }
    if x < 0.0 {
        return -1;
    }
    return 0;
}

// Trigonometric functions using Taylor series approximations
fn sin(x: f64) -> f64 {
    // Normalize x to [-PI, PI]
    let normalized = x;
    while normalized > PI {
        normalized = normalized - (2.0 * PI);
    }
    while normalized < -PI {
        normalized = normalized + (2.0 * PI);
    }

    // Taylor series: sin(x) = x - x^3/3! + x^5/5! - x^7/7! + ...
    let result = normalized;
    let term = normalized;
    let i = 1;

    while i < 10 {
        term = term * (-normalized) * normalized / ((2.0 * i) * (2.0 * i + 1.0));
        result = result + term;
        i = i + 1;
    }

    return result;
}

fn cos(x: f64) -> f64 {
    // Normalize x to [-PI, PI]
    let normalized = x;
    while normalized > PI {
        normalized = normalized - (2.0 * PI);
    }
    while normalized < -PI {
        normalized = normalized + (2.0 * PI);
    }

    // Taylor series: cos(x) = 1 - x^2/2! + x^4/4! - x^6/6! + ...
    let result = 1.0;
    let term = 1.0;
    let i = 1;

    while i < 10 {
        term = term * (-normalized) * normalized / ((2.0 * i - 1.0) * (2.0 * i));
        result = result + term;
        i = i + 1;
    }

    return result;
}

fn tan(x: f64) -> f64 {
    let cos_val = cos(x);
    if absf(cos_val) < 0.000001 {
        return 0.0;
    }
    return sin(x) / cos_val;
}

fn asin(x: f64) -> f64 {
    // Taylor series for small values
    if x > 1.0 || x < -1.0 {
        return 0.0;
    }

    let result = x;
    let term = x;
    let i = 1;

    while i < 10 {
        let n = 2.0 * i - 1.0;
        term = term * (n * n * x * x) / (n * (n + 1.0));
        result = result + term / (2.0 * i + 1.0);
        i = i + 1;
    }

    return result;
}

fn acos(x: f64) -> f64 {
    return PI / 2.0 - asin(x);
}

fn atan(x: f64) -> f64 {
    // Taylor series for |x| < 1
    if absf(x) > 1.0 {
        if x > 0.0 {
            return PI / 2.0 - atan(1.0 / x);
        } else {
            return -PI / 2.0 - atan(1.0 / x);
        }
    }

    let result = x;
    let term = x;
    let i = 1;

    while i < 10 {
        term = term * (-x) * x;
        result = result + term / (2.0 * i + 1.0);
        i = i + 1;
    }

    return result;
}

fn atan2(y: f64, x: f64) -> f64 {
    if x > 0.0 {
        return atan(y / x);
    }
    if x < 0.0 && y >= 0.0 {
        return atan(y / x) + PI;
    }
    if x < 0.0 && y < 0.0 {
        return atan(y / x) - PI;
    }
    if x == 0.0 && y > 0.0 {
        return PI / 2.0;
    }
    if x == 0.0 && y < 0.0 {
        return -PI / 2.0;
    }
    return 0.0;
}

// Logarithmic functions using series approximations
fn log(x: f64) -> f64 {
    // Natural logarithm using Taylor series for ln(1+x)
    if x <= 0.0 {
        return 0.0;
    }

    // For x near 1, use ln(x) = ln(1 + (x-1))
    let y = x - 1.0;

    // If |y| > 0.5, use log laws to reduce range
    if absf(y) > 0.5 {
        return log(sqrt(x)) * 2.0;
    }

    // Taylor series: ln(1+y) = y - y^2/2 + y^3/3 - y^4/4 + ...
    let result = y;
    let term = y;
    let i = 2;

    while i < 20 {
        term = term * (-y);
        result = result + term / i;
        i = i + 1;
    }

    return result;
}

fn log10(x: f64) -> f64 {
    return log(x) / log(10.0);
}

fn log2(x: f64) -> f64 {
    return log(x) / log(2.0);
}

fn exp(x: f64) -> f64 {
    // Taylor series: e^x = 1 + x + x^2/2! + x^3/3! + ...
    let result = 1.0;
    let term = 1.0;
    let i = 1;

    while i < 20 {
        term = term * x / i;
        result = result + term;
        i = i + 1;
    }

    return result;
}

// Square root for f64 (uses WASM f64.sqrt instruction)
extern fn sqrtf_wasm(x: f64) -> f64;

fn sqrtf(x: f64) -> f64 {
    // Prefer native WASM instruction when available
    return sqrtf_wasm(x);
}

// Floor, ceil, trunc, round using WASM instructions
extern fn floorf_wasm(x: f64) -> f64;
extern fn ceilf_wasm(x: f64) -> f64;
extern fn truncf_wasm(x: f64) -> f64;
extern fn roundf_wasm(x: f64) -> f64;

fn floorf(x: f64) -> f64 {
    return floorf_wasm(x);
}

fn ceilf(x: f64) -> f64 {
    return ceilf_wasm(x);
}

fn truncf(x: f64) -> f64 {
    return truncf_wasm(x);
}

fn roundf(x: f64) -> f64 {
    return roundf_wasm(x);
}

// Linear Congruential Generator for pseudo-random numbers
// State needs to be managed externally or as a global
let RAND_SEED: i32 = 12345;

fn random() -> f64 {
    // LCG: seed = (a * seed + c) mod m
    let a = 1103515245;
    let c = 12345;
    let m = 2147483647;

    RAND_SEED = (a * RAND_SEED + c) % m;

    return RAND_SEED / m;
}

fn randomInt(min_val: i32, max_val: i32) -> i32 {
    let range = max_val - min_val;
    if range <= 0 {
        return min_val;
    }

    let r = random();
    return min_val + (r * range);
}

fn setSeed(seed: i32) -> void {
    RAND_SEED = seed;
}

// Linear interpolation
fn lerp(a: f64, b: f64, t: f64) -> f64 {
    return a + (b - a) * t;
}

// Map value from one range to another
fn map(value: f64, in_min: f64, in_max: f64, out_min: f64, out_max: f64) -> f64 {
    let in_range = in_max - in_min;
    if absf(in_range) < 0.000001 {
        return out_min;
    }

    return (value - in_min) * (out_max - out_min) / in_range + out_min;
}

// Greatest common divisor (Euclidean algorithm)
fn gcd(a: i32, b: i32) -> i32 {
    let x = abs(a);
    let y = abs(b);

    while y != 0 {
        let temp = y;
        y = x % y;
        x = temp;
    }

    return x;
}

// Least common multiple
fn lcm(a: i32, b: i32) -> i32 {
    if a == 0 || b == 0 {
        return 0;
    }
    return abs(a * b) / gcd(a, b);
}

// Factorial
fn factorial(n: i32) -> i32 {
    if n <= 1 {
        return 1;
    }

    let result = 1;
    let i = 2;

    while i <= n {
        result = result * i;
        i = i + 1;
    }

    return result;
}

// Check if number is even
fn isEven(n: i32) -> bool {
    return n % 2 == 0;
}

// Check if number is odd
fn isOdd(n: i32) -> bool {
    return n % 2 != 0;
}

// Check if number is prime (simple trial division)
fn isPrime(n: i32) -> bool {
    if n <= 1 {
        return false;
    }
    if n <= 3 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }

    let i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i = i + 6;
    }

    return true;
}
