(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $testAssignment (result i32)
    (local $x i32)
    i32.const 10
    local.set $x
    local.get $x
    i32.const 5
    i32.add
    local.set $x
    local.get $x
  drop
    local.get $x
    i32.const 2
    i32.mul
    local.set $x
    local.get $x
  drop
    local.get $x
    return
  )

  (func $testWhileWithAssignment (result i32)
    (local $sum i32)
    i32.const 0
    local.set $sum
    (local $i i32)
    i32.const 0
    local.set $i
    ;; while loop
    (block $break
      (loop $continue
        local.get $i
        i32.const 10
        i32.lt_s
        i32.eqz
        br_if $break
        local.get $sum
        local.get $i
        i32.add
        local.set $sum
        local.get $sum
  drop
        local.get $i
        i32.const 1
        i32.add
        local.set $i
        local.get $i
  drop
        br $continue
      )
    )
    local.get $sum
    return
  )

  (func $main (export "main") (result i32)
    (local $result i32)
    call $testWhileWithAssignment
    local.set $result
    local.get $result
    return
  )

)
