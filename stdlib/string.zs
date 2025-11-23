// String utilities for ZigScript
// Provides common string manipulation functions

// Split string by delimiter
fn split(s: string, delimiter: string) -> [string] {
    let result: [string] = [];
    let len = s.len();
    let delim_len = delimiter.len();

    if delim_len == 0 {
        return result;
    }

    let start = 0;
    let i = 0;

    while i <= len - delim_len {
        let match = true;
        let j = 0;

        while j < delim_len {
            if s.charAt(i + j) != delimiter.charAt(j) {
                match = false;
            }
            j = j + 1;
        }

        if match {
            result.push(s.slice(start, i));
            i = i + delim_len;
            start = i;
        } else {
            i = i + 1;
        }
    }

    result.push(s.slice(start, len));
    return result;
}

// Join array of strings with delimiter
fn join(arr: [string], delimiter: string) -> string {
    let len = arr.len();
    if len == 0 {
        return "";
    }

    let result = arr[0];
    let i = 1;

    while i < len {
        result = result + delimiter + arr[i];
        i = i + 1;
    }

    return result;
}

// Convert string to uppercase
fn toUpper(s: string) -> string {
    let result = "";
    let len = s.len();
    let i = 0;

    while i < len {
        let ch = s.charAt(i);
        let code = ch.charCodeAt(0);

        if code >= 97 && code <= 122 {
            result = result + String.fromCharCode(code - 32);
        } else {
            result = result + ch;
        }

        i = i + 1;
    }

    return result;
}

// Convert string to lowercase
fn toLower(s: string) -> string {
    let result = "";
    let len = s.len();
    let i = 0;

    while i < len {
        let ch = s.charAt(i);
        let code = ch.charCodeAt(0);

        if code >= 65 && code <= 90 {
            result = result + String.fromCharCode(code + 32);
        } else {
            result = result + ch;
        }

        i = i + 1;
    }

    return result;
}

// Helper: check if character is whitespace
fn isWhitespace(ch: string) -> bool {
    let code = ch.charCodeAt(0);
    return code == 32 || code == 9 || code == 10 || code == 13;
}

// Trim whitespace from both ends
fn trim(s: string) -> string {
    return trimEnd(trimStart(s));
}

// Trim whitespace from start
fn trimStart(s: string) -> string {
    let len = s.len();
    let start = 0;

    while start < len && isWhitespace(s.charAt(start)) {
        start = start + 1;
    }

    return s.slice(start, len);
}

// Trim whitespace from end
fn trimEnd(s: string) -> string {
    let len = s.len();
    let end = len;

    while end > 0 && isWhitespace(s.charAt(end - 1)) {
        end = end - 1;
    }

    return s.slice(0, end);
}

// Replace all occurrences of pattern with replacement
fn replace(s: string, pattern: string, replacement: string) -> string {
    let result = "";
    let len = s.len();
    let pattern_len = pattern.len();

    if pattern_len == 0 {
        return s;
    }

    let i = 0;

    while i < len {
        let match = true;
        let j = 0;

        if i + pattern_len <= len {
            while j < pattern_len {
                if s.charAt(i + j) != pattern.charAt(j) {
                    match = false;
                }
                j = j + 1;
            }
        } else {
            match = false;
        }

        if match {
            result = result + replacement;
            i = i + pattern_len;
        } else {
            result = result + s.charAt(i);
            i = i + 1;
        }
    }

    return result;
}

// Check if string starts with prefix
fn startsWith(s: string, prefix: string) -> bool {
    let prefix_len = prefix.len();
    if s.len() < prefix_len {
        return false;
    }

    let i = 0;
    while i < prefix_len {
        if s.charAt(i) != prefix.charAt(i) {
            return false;
        }
        i = i + 1;
    }

    return true;
}

// Check if string ends with suffix
fn endsWith(s: string, suffix: string) -> bool {
    let len = s.len();
    let suffix_len = suffix.len();

    if len < suffix_len {
        return false;
    }

    let start = len - suffix_len;
    let i = 0;

    while i < suffix_len {
        if s.charAt(start + i) != suffix.charAt(i) {
            return false;
        }
        i = i + 1;
    }

    return true;
}

// Check if string contains substring
fn contains(s: string, substring: string) -> bool {
    return indexOf(s, substring) >= 0;
}

// Get substring from start to end index
fn slice(s: string, start: i32, end: i32) -> string {
    let len = s.len();
    let actual_start = start;
    let actual_end = end;

    if actual_start < 0 {
        actual_start = 0;
    }
    if actual_end > len {
        actual_end = len;
    }
    if actual_start >= actual_end {
        return "";
    }

    let result = "";
    let i = actual_start;

    while i < actual_end {
        result = result + s.charAt(i);
        i = i + 1;
    }

    return result;
}

// Get character at index
fn charAt(s: string, index: i32) -> string {
    // Note: This should be implemented as a host function
    // returning a single-character string at the given index
    // For now, placeholder - requires WASM string interop
    return "";
}

// Get string length
fn len(s: string) -> i32 {
    // Note: This should be implemented as a host function
    // returning the UTF-8 byte length or character count
    // For now, placeholder - requires WASM string interop
    return 0;
}

// Find index of first occurrence of substring
fn indexOf(s: string, substring: string) -> i32 {
    let len = s.len();
    let sub_len = substring.len();

    if sub_len == 0 || sub_len > len {
        return -1;
    }

    let i = 0;

    while i <= len - sub_len {
        let match = true;
        let j = 0;

        while j < sub_len {
            if s.charAt(i + j) != substring.charAt(j) {
                match = false;
            }
            j = j + 1;
        }

        if match {
            return i;
        }

        i = i + 1;
    }

    return -1;
}

// Find index of last occurrence of substring
fn lastIndexOf(s: string, substring: string) -> i32 {
    let len = s.len();
    let sub_len = substring.len();

    if sub_len == 0 || sub_len > len {
        return -1;
    }

    let i = len - sub_len;

    while i >= 0 {
        let match = true;
        let j = 0;

        while j < sub_len {
            if s.charAt(i + j) != substring.charAt(j) {
                match = false;
            }
            j = j + 1;
        }

        if match {
            return i;
        }

        i = i - 1;
    }

    return -1;
}

// Repeat string n times
fn repeat(s: string, n: i32) -> string {
    let result = "";
    let i = 0;

    while i < n {
        result = result + s;
        i = i + 1;
    }

    return result;
}

// Pad string to length with fill character
fn padStart(s: string, length: i32, fill: string) -> string {
    let len = s.len();
    if len >= length {
        return s;
    }

    let padding = repeat(fill, length - len);
    return padding + s;
}

fn padEnd(s: string, length: i32, fill: string) -> string {
    let len = s.len();
    if len >= length {
        return s;
    }

    let padding = repeat(fill, length - len);
    return s + padding;
}

// Reverse string
fn reverse(s: string) -> string {
    let result = "";
    let len = s.len();
    let i = len - 1;

    while i >= 0 {
        result = result + s.charAt(i);
        i = i - 1;
    }

    return result;
}
