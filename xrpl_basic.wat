(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $create_account (export "create_account") (param $address i32) (result i32)
    ;; struct literal at 8192
    local.get $address
    i32.const 8192
    i32.store
    i32.const 0
    i32.const 8196
    i32.store
    i32.const 0
    i32.const 8200
    i32.store
    i32.const 8192  ;; struct pointer
    return
  )

  (func $make_payment (export "make_payment") (param $from i32) (param $to_address i32) (param $amount i64) (result i32)
    ;; struct literal at 8204
    local.get $from
    i32.load  ;; load field address
    i32.const 8204
    i32.store
    local.get $to_address
    i32.const 8208
    i32.store
    local.get $amount
    i32.const 8212
    i32.store
    i32.const 8204  ;; struct pointer
    return
  )

  (func $main (export "main") (result i32)
    (local $account i32)
    ;; string literal "rN7n7otQDd6FczFgLdlq..." at 8216
    i32.const 8216
    i32.const 34
    i32.store
    i32.const 8220
    i32.const 114
    i32.store8
    i32.const 8221
    i32.const 78
    i32.store8
    i32.const 8222
    i32.const 55
    i32.store8
    i32.const 8223
    i32.const 110
    i32.store8
    i32.const 8224
    i32.const 55
    i32.store8
    i32.const 8225
    i32.const 111
    i32.store8
    i32.const 8226
    i32.const 116
    i32.store8
    i32.const 8227
    i32.const 81
    i32.store8
    i32.const 8228
    i32.const 68
    i32.store8
    i32.const 8229
    i32.const 100
    i32.store8
    i32.const 8230
    i32.const 54
    i32.store8
    i32.const 8231
    i32.const 70
    i32.store8
    i32.const 8232
    i32.const 99
    i32.store8
    i32.const 8233
    i32.const 122
    i32.store8
    i32.const 8234
    i32.const 70
    i32.store8
    i32.const 8235
    i32.const 103
    i32.store8
    i32.const 8236
    i32.const 76
    i32.store8
    i32.const 8237
    i32.const 100
    i32.store8
    i32.const 8238
    i32.const 108
    i32.store8
    i32.const 8239
    i32.const 113
    i32.store8
    i32.const 8240
    i32.const 116
    i32.store8
    i32.const 8241
    i32.const 121
    i32.store8
    i32.const 8242
    i32.const 77
    i32.store8
    i32.const 8243
    i32.const 86
    i32.store8
    i32.const 8244
    i32.const 114
    i32.store8
    i32.const 8245
    i32.const 110
    i32.store8
    i32.const 8246
    i32.const 51
    i32.store8
    i32.const 8247
    i32.const 76
    i32.store8
    i32.const 8248
    i32.const 78
    i32.store8
    i32.const 8249
    i32.const 85
    i32.store8
    i32.const 8250
    i32.const 56
    i32.store8
    i32.const 8251
    i32.const 75
    i32.store8
    i32.const 8252
    i32.const 105
    i32.store8
    i32.const 8253
    i32.const 52
    i32.store8
    i32.const 8216  ;; string pointer
    call $create_account
    local.set $account
    (local $payment i32)
    local.get $account
    ;; string literal "rDestination123" at 8256
    i32.const 8256
    i32.const 15
    i32.store
    i32.const 8260
    i32.const 114
    i32.store8
    i32.const 8261
    i32.const 68
    i32.store8
    i32.const 8262
    i32.const 101
    i32.store8
    i32.const 8263
    i32.const 115
    i32.store8
    i32.const 8264
    i32.const 116
    i32.store8
    i32.const 8265
    i32.const 105
    i32.store8
    i32.const 8266
    i32.const 110
    i32.store8
    i32.const 8267
    i32.const 97
    i32.store8
    i32.const 8268
    i32.const 116
    i32.store8
    i32.const 8269
    i32.const 105
    i32.store8
    i32.const 8270
    i32.const 111
    i32.store8
    i32.const 8271
    i32.const 110
    i32.store8
    i32.const 8272
    i32.const 49
    i32.store8
    i32.const 8273
    i32.const 50
    i32.store8
    i32.const 8274
    i32.const 51
    i32.store8
    i32.const 8256  ;; string pointer
    i64.const 1000000
    call $make_payment
    local.set $payment
    i32.const 0
    return
  )

)
