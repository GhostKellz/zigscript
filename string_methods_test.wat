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
    (local $s i32)
    ;; string literal "hello world" at 8192
    i32.const 8192
    i32.const 11
    i32.store
    i32.const 8196
    i32.const 104
    i32.store8
    i32.const 8197
    i32.const 101
    i32.store8
    i32.const 8198
    i32.const 108
    i32.store8
    i32.const 8199
    i32.const 108
    i32.store8
    i32.const 8200
    i32.const 111
    i32.store8
    i32.const 8201
    i32.const 32
    i32.store8
    i32.const 8202
    i32.const 119
    i32.store8
    i32.const 8203
    i32.const 111
    i32.store8
    i32.const 8204
    i32.const 114
    i32.store8
    i32.const 8205
    i32.const 108
    i32.store8
    i32.const 8206
    i32.const 100
    i32.store8
    i32.const 8192  ;; string pointer
    local.set $s
    (local $upper i32)
    call $toUpperCase
    local.set $upper
    (local $len i32)
    call $length
    local.set $len
    local.get $len
    return
  )

)
