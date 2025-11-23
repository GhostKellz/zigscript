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

  (func $main (export "main") (result i32)
    (local $wallet i32)
    ;; string literal "rN7n7otQDd6FczFgLdlq..." at 8200
    i32.const 8200
    i32.const 34
    i32.store
    i32.const 8204
    i32.const 114
    i32.store8
    i32.const 8205
    i32.const 78
    i32.store8
    i32.const 8206
    i32.const 55
    i32.store8
    i32.const 8207
    i32.const 110
    i32.store8
    i32.const 8208
    i32.const 55
    i32.store8
    i32.const 8209
    i32.const 111
    i32.store8
    i32.const 8210
    i32.const 116
    i32.store8
    i32.const 8211
    i32.const 81
    i32.store8
    i32.const 8212
    i32.const 68
    i32.store8
    i32.const 8213
    i32.const 100
    i32.store8
    i32.const 8214
    i32.const 54
    i32.store8
    i32.const 8215
    i32.const 70
    i32.store8
    i32.const 8216
    i32.const 99
    i32.store8
    i32.const 8217
    i32.const 122
    i32.store8
    i32.const 8218
    i32.const 70
    i32.store8
    i32.const 8219
    i32.const 103
    i32.store8
    i32.const 8220
    i32.const 76
    i32.store8
    i32.const 8221
    i32.const 100
    i32.store8
    i32.const 8222
    i32.const 108
    i32.store8
    i32.const 8223
    i32.const 113
    i32.store8
    i32.const 8224
    i32.const 116
    i32.store8
    i32.const 8225
    i32.const 121
    i32.store8
    i32.const 8226
    i32.const 77
    i32.store8
    i32.const 8227
    i32.const 86
    i32.store8
    i32.const 8228
    i32.const 114
    i32.store8
    i32.const 8229
    i32.const 110
    i32.store8
    i32.const 8230
    i32.const 51
    i32.store8
    i32.const 8231
    i32.const 76
    i32.store8
    i32.const 8232
    i32.const 78
    i32.store8
    i32.const 8233
    i32.const 85
    i32.store8
    i32.const 8234
    i32.const 56
    i32.store8
    i32.const 8235
    i32.const 75
    i32.store8
    i32.const 8236
    i32.const 105
    i32.store8
    i32.const 8237
    i32.const 52
    i32.store8
    i32.const 8200  ;; string pointer
    call $create
    local.set $wallet
    (local $balance i32)
    local.get $wallet
    call $get_balance
    local.set $balance
    local.get $balance
    return
  )

)
