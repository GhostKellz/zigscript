(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $testWhile (result i32)
    (local $x i32)
    i32.const 0
    local.set $x
    ;; while loop
    (block $break
      (loop $continue
        local.get $x
        i32.const 5
        i32.lt_s
        i32.eqz
        br_if $break
        (local $y i32)
        local.get $x
        i32.const 1
        i32.add
        local.set $y
        br $continue
      )
    )
    i32.const 42
    return
  )

  (func $main (export "main") (result i32)
    (local $result i32)
    call $testWhile
    local.set $result
    local.get $result
    return
  )

)
