(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $sumArray (param $numbers i32) (result i32)
    (local $total i32)
    i32.const 0
    local.set $total
    local.get $total
    return
  )

  (func $getStatusMessage (param $status i32) (result i32)
    ;; string literal "status message" at 8192
    i32.const 8192
    i32.const 14
    i32.store
    i32.const 8196
    i32.const 115
    i32.store8
    i32.const 8197
    i32.const 116
    i32.store8
    i32.const 8198
    i32.const 97
    i32.store8
    i32.const 8199
    i32.const 116
    i32.store8
    i32.const 8200
    i32.const 117
    i32.store8
    i32.const 8201
    i32.const 115
    i32.store8
    i32.const 8202
    i32.const 32
    i32.store8
    i32.const 8203
    i32.const 109
    i32.store8
    i32.const 8204
    i32.const 101
    i32.store8
    i32.const 8205
    i32.const 115
    i32.store8
    i32.const 8206
    i32.const 115
    i32.store8
    i32.const 8207
    i32.const 97
    i32.store8
    i32.const 8208
    i32.const 103
    i32.store8
    i32.const 8209
    i32.const 101
    i32.store8
    i32.const 8192  ;; string pointer
    return
  )

  (func $fetchAndParseUser (param $user_id i32) (result i32)
    (local $data i32)
    ;; await expression - evaluate promise
    i32.const 100
    call $delay
    call $nexus_promise_await
    local.set $data
    local.get $data
    local.get $user_id
    i32.add
    return
  )

  (func $delay (param $ms i32) (result i32)
    local.get $ms
    return
  )

  (func $main (export "main") (result i32)
    (local $user_id i32)
    ;; await expression - evaluate promise
    i32.const 1
    call $fetchAndParseUser
    call $nexus_promise_await
    local.set $user_id
    local.get $user_id
    return
  )

)
