(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $main (export "main") (result i32)
    (local $arr i32)
    ;; array literal at 8192
    i32.const 8192
    i32.const 4
    i32.store
    i32.const 8196
    i32.const 8
    i32.store
    i32.const 10
    i32.const 8200
    i32.store
    i32.const 20
    i32.const 8204
    i32.store
    i32.const 30
    i32.const 8208
    i32.store
    i32.const 40
    i32.const 8212
    i32.store
    i32.const 8192  ;; array pointer
    local.set $arr
    (local $first i32)
    local.get $arr
    i32.const 8
    i32.add
    i32.const 0
    i32.const 4
    i32.mul
    i32.add
    i32.load
    local.set $first
    (local $second i32)
    local.get $arr
    i32.const 8
    i32.add
    i32.const 1
    i32.const 4
    i32.mul
    i32.add
    i32.load
    local.set $second
    local.get $arr
    i32.const 8
    i32.add
    i32.const 2
    i32.const 4
    i32.mul
    i32.add
    i32.const 99
    i32.store
    i32.const 99
  drop
    (local $modified i32)
    local.get $arr
    i32.const 8
    i32.add
    i32.const 2
    i32.const 4
    i32.mul
    i32.add
    i32.load
    local.set $modified
    local.get $modified
    return
  )

)
