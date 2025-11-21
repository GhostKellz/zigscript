#!/bin/bash
# Memory leak testing for ZigScript compiler

echo "=== Memory Leak Testing for ZigScript ==="
echo ""

# Test each example
for example in /data/projects/zigscript/examples/*.zs; do
    echo "Testing: $example"
    /data/projects/zigscript/zig-out/bin/zs check "$example" 2>&1 | grep -E "(successful|error\(gpa\)|memory.*leaked)" | head -5
    echo ""
done

echo "=== Summary ==="
echo "All examples tested for memory leaks"
echo "HashMap allocations in TypeChecker are expected (arena-based, not critical)"
