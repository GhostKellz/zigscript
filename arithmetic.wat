(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))

  (func $add (param $a i32) (param $b i32) (result i32)
    local.get $a
    local.get $b
    i32.add
    return
  )

  (func $multiply (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    i32.mul
    return
  )

  (func $main (export "main") (result i32)
    (local $result i32)
    i32.const 10
    i32.const 20
    call $add
    local.set $result
    (local $product i32)
    local.get $result
    i32.const 2
    call $multiply
    local.set $product
    local.get $product
    return
  )

)
