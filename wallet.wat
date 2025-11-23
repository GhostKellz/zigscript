(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $create (export "create") (param $address i32) (result i32)
    ;; struct literal at 8192
    local.get $address
    i32.const 8192
    i32.store
    i32.const 0
    i32.const 8196
    i32.store
    i32.const 8192  ;; struct pointer
    return
  )

  (func $get_balance (export "get_balance") (param $wallet i32) (result i32)
    local.get $wallet
    i32.const 4
    i32.add
    i32.load  ;; load field balance
    return
  )

)
