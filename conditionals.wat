(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $max (param $a i32) (param $b i32) (result i32)
    (if
            local.get $a
      local.get $b
      i32.gt_s

      (then
        local.get $a
        return
      )
      (else
        local.get $b
        return
      )
    )
  )

  (func $main (export "main") (result i32)
    (local $x i32)
    i32.const 10
    local.set $x
    (local $y i32)
    i32.const 20
    local.set $y
    (local $result i32)
    local.get $x
    local.get $y
    call $max
    local.set $result
    local.get $result
    return
  )

)
