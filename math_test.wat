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
    (local $a i32)
    i32.const 10
    local.set $a
    (local $b i32)
    i32.const 20
    local.set $b
    (local $sum i32)
    local.get $a
    local.get $b
    i32.add
    local.set $sum
    (local $product i32)
    f64.const 3.14
    f64.const 2
    f64.mul
    local.set $product
    (local $diff i32)
    f64.const 10.5
    f64.const 3.2
    f64.sub
    local.set $diff
    (local $quotient i32)
    f64.const 8
    f64.const 2
    f64.div
    local.set $quotient
    (local $is_greater i32)
    f64.const 5.5
    f64.const 3.3
    f64.gt
    local.set $is_greater
    local.get $sum
    return
  )

)
