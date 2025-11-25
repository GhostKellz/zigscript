(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "std" "json_decode" (func $json_decode (param i32 i32) (result i32)))
  (import "std" "json_encode" (func $json_encode (param i32) (result i32)))
  (import "std" "http_get" (func $http_get (param i32 i32) (result i32)))
  (import "std" "http_post" (func $http_post (param i32 i32 i32 i32) (result i32)))
  (import "std" "fs_read_file" (func $fs_read_file (param i32 i32) (result i32)))
  (import "std" "fs_write_file" (func $fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "std" "set_timeout" (func $set_timeout (param i32 i32) (result i32)))
  (import "std" "clear_timeout" (func $clear_timeout (param i32)))
  (import "std" "promise_await" (func $promise_await (param i32) (result i32)))

  (func $main (export "main") (result i32)
    (local $user i32)
    ;; struct literal at 8192
    i32.const 1
    i32.const 8192
    i32.store
    ;; string literal "Alice" at 8204
    i32.const 8204
    i32.const 5
    i32.store
    i32.const 8208
    i32.const 65
    i32.store8
    i32.const 8209
    i32.const 108
    i32.store8
    i32.const 8210
    i32.const 105
    i32.store8
    i32.const 8211
    i32.const 99
    i32.store8
    i32.const 8212
    i32.const 101
    i32.store8
    i32.const 8204  ;; string pointer
    i32.const 8196
    i32.store
    i32.const 1
    i32.const 8200
    i32.store
    i32.const 8192  ;; struct pointer
    local.set $user
    local.get $user
    i32.load  ;; load field id
    return
  )

)
