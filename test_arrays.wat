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
    (local $arr i32)
    ;; array literal at 8192
    i32.const 8192
    i32.const 3
    i32.store
    i32.const 8196
    i32.const 6
    i32.store
    i32.const 1
    i32.const 8200
    i32.store
    i32.const 2
    i32.const 8204
    i32.store
    i32.const 3
    i32.const 8208
    i32.store
    i32.const 8192  ;; array pointer
    local.set $arr
    local.get $arr
    local.tee $arr_ptr
    i32.load  ;; load length
    local.set $arr_len
    local.get $arr_ptr
    i32.const 8
    i32.add
    local.get $arr_len
    i32.const 4
    i32.mul
    i32.add
    i32.const 4
    i32.store
    local.get $arr_ptr
    local.get $arr_len
    i32.const 1
    i32.add
    i32.store
    i32.const 0
  drop
    local.get $arr
    local.tee $arr_ptr
    i32.load  ;; load length
    local.set $arr_len
    local.get $arr_ptr
    i32.const 8
    i32.add
    local.get $arr_len
    i32.const 4
    i32.mul
    i32.add
    i32.const 5
    i32.store
    local.get $arr_ptr
    local.get $arr_len
    i32.const 1
    i32.add
    i32.store
    i32.const 0
  drop
    (local $last i32)
    local.get $arr
    local.tee $arr_ptr
    i32.load  ;; load length
    local.tee $arr_len
    i32.const 0
    i32.eq
    if
      i32.const 0  ;; return 0 if empty
      return
    end
    local.get $arr_ptr
    local.get $arr_len
    i32.const 1
    i32.sub
    local.tee $arr_len
    i32.store
    local.get $arr_ptr
    i32.const 8
    i32.add
    local.get $arr_len
    i32.const 4
    i32.mul
    i32.add
    i32.load  ;; load popped value
    local.set $last
    (local $len i32)
    local.get $arr
    i32.load  ;; load array length
    local.set $len
    local.get $len
    return
  )

)
