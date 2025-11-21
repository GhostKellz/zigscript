(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))

  (func $main (export "main") (result i32)
    i32.const 42
    return
  )

)
