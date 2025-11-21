(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))

  (func $delay (param $ms i32) (result i32)
    local.get $ms
    return
  )

  (func $main (export "main") (result i32)
    (local $result i32)
    ;; await expression (runtime stub)
    i32.const 1000
    call $delay
    local.set $result
    local.get $result
    return
  )

)
