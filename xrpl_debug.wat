(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $make_payment (param $from i32) (param $to_address i32) (result i32)
    i32.const 0
    return
  )

  (func $main (export "main") (result i32)
    (local $account i32)
    ;; struct literal at 8192
    ;; string literal "test" at 8196
    i32.const 8196
    i32.const 4
    i32.store
    i32.const 8200
    i32.const 116
    i32.store8
    i32.const 8201
    i32.const 101
    i32.store8
    i32.const 8202
    i32.const 115
    i32.store8
    i32.const 8203
    i32.const 116
    i32.store8
    i32.const 8196  ;; string pointer
    i32.const 8192
    i32.store
    i32.const 8192  ;; struct pointer
    local.set $account
    (local $x i32)
    local.get $account
    ;; string literal "dest" at 8204
    i32.const 8204
    i32.const 4
    i32.store
    i32.const 8208
    i32.const 100
    i32.store8
    i32.const 8209
    i32.const 101
    i32.store8
    i32.const 8210
    i32.const 115
    i32.store8
    i32.const 8211
    i32.const 116
    i32.store8
    i32.const 8204  ;; string pointer
    call $make_payment
    local.set $x
    local.get $x
    return
  )

)
