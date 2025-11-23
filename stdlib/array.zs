// Array utilities for ZigScript
// Provides common array manipulation functions

// Sort array in ascending order (quicksort)
fn sort(arr: [i32]) -> [i32] {
    let len = arr.len();
    if len <= 1 {
        return arr;
    }

    return quicksort(arr, 0, len - 1);
}

// Quicksort helper
fn quicksort(arr: [i32], low: i32, high: i32) -> [i32] {
    if low < high {
        let pi = partition(arr, low, high);
        arr = quicksort(arr, low, pi - 1);
        arr = quicksort(arr, pi + 1, high);
    }
    return arr;
}

// Partition helper for quicksort
fn partition(arr: [i32], low: i32, high: i32) -> i32 {
    let pivot = arr[high];
    let i = low - 1;
    let j = low;

    while j < high {
        if arr[j] < pivot {
            i = i + 1;
            let temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
        j = j + 1;
    }

    let temp = arr[i + 1];
    arr[i + 1] = arr[high];
    arr[high] = temp;

    return i + 1;
}

// Reverse array
fn reverse(arr: [i32]) -> [i32] {
    let len = arr.len();
    let result = [];
    let i = len - 1;

    while i >= 0 {
        result.push(arr[i]);
        i = i - 1;
    }

    return result;
}

// Get unique elements
fn unique(arr: [i32]) -> [i32] {
    let result: [i32] = [];
    let len = arr.len();
    let i = 0;

    while i < len {
        if !contains(result, arr[i]) {
            result.push(arr[i]);
        }
        i = i + 1;
    }

    return result;
}

// Check if array contains element
fn contains(arr: [i32], element: i32) -> bool {
    let i = 0;
    let len = arr.len();

    while i < len {
        if arr[i] == element {
            return true;
        }
        i = i + 1;
    }

    return false;
}

// Find index of element (-1 if not found)
fn indexOf(arr: [i32], element: i32) -> i32 {
    let i = 0;
    let len = arr.len();

    while i < len {
        if arr[i] == element {
            return i;
        }
        i = i + 1;
    }

    return -1;
}

// Find last index of element
fn lastIndexOf(arr: [i32], element: i32) -> i32 {
    let len = arr.len();
    let i = len - 1;

    while i >= 0 {
        if arr[i] == element {
            return i;
        }
        i = i - 1;
    }

    return -1;
}

// Get slice of array from start to end
fn slice(arr: [i32], start: i32, end: i32) -> [i32] {
    let result = [];
    let i = start;

    while i < end {
        if i >= 0 && i < arr.len() {
            result.push(arr[i]);
        }
        i = i + 1;
    }

    return result;
}

// Concatenate two arrays
fn concat(arr1: [i32], arr2: [i32]) -> [i32] {
    let result = [];
    let i = 0;

    while i < arr1.len() {
        result.push(arr1[i]);
        i = i + 1;
    }

    i = 0;
    while i < arr2.len() {
        result.push(arr2[i]);
        i = i + 1;
    }

    return result;
}

// Fill array with value
fn fill(arr: [i32], value: i32) -> [i32] {
    let i = 0;
    let len = arr.len();

    while i < len {
        arr[i] = value;
        i = i + 1;
    }

    return arr;
}

// Find first element matching predicate
// TODO: requires lambda support
// fn find(arr: [i32], predicate: fn(i32) -> bool) -> i32

// Check if every element matches predicate
// TODO: requires lambda support
// fn every(arr: [i32], predicate: fn(i32) -> bool) -> bool

// Check if some element matches predicate
// TODO: requires lambda support
// fn some(arr: [i32], predicate: fn(i32) -> bool) -> bool

// Flatten nested array
fn flatten(arr: [[i32]]) -> [i32] {
    let result: [i32] = [];
    let len = arr.len();
    let i = 0;

    while i < len {
        let inner = arr[i];
        let inner_len = inner.len();
        let j = 0;

        while j < inner_len {
            result.push(inner[j]);
            j = j + 1;
        }

        i = i + 1;
    }

    return result;
}

// Get first element
fn first(arr: [i32]) -> i32 {
    if arr.len() > 0 {
        return arr[0];
    }
    return 0;
}

// Get last element
fn last(arr: [i32]) -> i32 {
    let len = arr.len();
    if len > 0 {
        return arr[len - 1];
    }
    return 0;
}

// Get sum of all elements
fn sum(arr: [i32]) -> i32 {
    return arr.reduce(fn(acc, x) => acc + x, 0);
}

// Get average of all elements
fn average(arr: [i32]) -> i32 {
    let len = arr.len();
    if len == 0 {
        return 0;
    }
    return sum(arr) / len;
}

// Get minimum element
fn min(arr: [i32]) -> i32 {
    if arr.len() == 0 {
        return 0;
    }

    let minVal = arr[0];
    let i = 1;

    while i < arr.len() {
        if arr[i] < minVal {
            minVal = arr[i];
        }
        i = i + 1;
    }

    return minVal;
}

// Get maximum element
fn max(arr: [i32]) -> i32 {
    if arr.len() == 0 {
        return 0;
    }

    let maxVal = arr[0];
    let i = 1;

    while i < arr.len() {
        if arr[i] > maxVal {
            maxVal = arr[i];
        }
        i = i + 1;
    }

    return maxVal;
}
