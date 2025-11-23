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
    (local $name i32)
    ;; string literal "Alice" at 8192
    i32.const 8192
    i32.const 5
    i32.store
    i32.const 8196
    i32.const 65
    i32.store8
    i32.const 8197
    i32.const 108
    i32.store8
    i32.const 8198
    i32.const 105
    i32.store8
    i32.const 8199
    i32.const 99
    i32.store8
    i32.const 8200
    i32.const 101
    i32.store8
    i32.const 8192  ;; string pointer
    local.set $name
    (local $age i32)
    i32.const 30
    local.set $age
    (local $city i32)
    ;; string literal "San Francisco" at 8204
    i32.const 8204
    i32.const 13
    i32.store
    i32.const 8208
    i32.const 83
    i32.store8
    i32.const 8209
    i32.const 97
    i32.store8
    i32.const 8210
    i32.const 110
    i32.store8
    i32.const 8211
    i32.const 32
    i32.store8
    i32.const 8212
    i32.const 70
    i32.store8
    i32.const 8213
    i32.const 114
    i32.store8
    i32.const 8214
    i32.const 97
    i32.store8
    i32.const 8215
    i32.const 110
    i32.store8
    i32.const 8216
    i32.const 99
    i32.store8
    i32.const 8217
    i32.const 105
    i32.store8
    i32.const 8218
    i32.const 115
    i32.store8
    i32.const 8219
    i32.const 99
    i32.store8
    i32.const 8220
    i32.const 111
    i32.store8
    i32.const 8204  ;; string pointer
    local.set $city
    (local $greeting i32)
    ;; String interpolation
    i32.const 8224  ;; interpolated string ptr
    local.set $greeting
    (local $bio i32)
    ;; String interpolation
    i32.const 8480  ;; interpolated string ptr
    local.set $bio
    (local $next_year i32)
    ;; String interpolation
    i32.const 8736  ;; interpolated string ptr
    local.set $next_year
    (local $calc i32)
    ;; String interpolation
    i32.const 8992  ;; interpolated string ptr
    local.set $calc
    i32.const 0
    return
  )

)
