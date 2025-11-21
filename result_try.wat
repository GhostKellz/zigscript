(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $divide (param $a i32) (param $b i32) (result i32)
    (if
            local.get $b
      i32.const 0
      i32.eq

      (then
        i32.const 0
        return
      )
    )
    local.get $a
    return
  )

  (func $calculate (param $x i32) (param $y i32) (param $z i32) (result i32)
    (local $step1 i32)
    local.get $x
    local.get $y
    call $divide
    local.set $step1
    (local $step2 i32)
    local.get $step1
    local.get $z
    call $divide
    local.set $step2
    local.get $step2
    return
  )

  (func $main (export "main") (result i32)
    (local $result i32)
    i32.const 100
    i32.const 10
    i32.const 2
    call $calculate
    local.set $result
    local.get $result
    return
  )

)
