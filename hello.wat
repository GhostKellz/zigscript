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
  (import "env" "alloc" (func $alloc (param i32) (result i32)))

  (func $main (export "main") (result i32)
    i32.const 42
    return
  )

)
