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
    (local $nums i32)
    ;; array literal at 8192
    i32.const 8192
    i32.const 4
    i32.store
    i32.const 8196
    i32.const 8
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
    i32.const 4
    i32.const 8212
    i32.store
    i32.const 8192  ;; array pointer
    local.set $nums
    (local $doubled i32)
    local.get $nums
    local.tee $src_arr
    i32.load  ;; load source length
    local.tee $arr_len
    i32.const 4
    i32.mul  ;; elements size
    i32.const 8
    i32.add  ;; + metadata
    call $alloc
    local.tee $new_arr
    local.get $arr_len
    i32.store  ;; store length
    local.get $new_arr
    i32.const 4
    i32.add
    local.get $arr_len
    i32.store  ;; store capacity
    i32.const 0
    local.set $i
    (loop $map_loop
      local.get $i
      local.get $arr_len
      i32.lt_s
      if
        local.get $src_arr
        i32.const 8
        i32.add
        local.get $i
        i32.const 4
        i32.mul
        i32.add
        i32.load  ;; load element
        local.get $new_arr
        i32.const 8
        i32.add
        local.get $i
        i32.const 4
        i32.mul
        i32.add
        i32.store
        local.get $i
        i32.const 1
        i32.add
        local.set $i
        br $map_loop
      end
    )
    local.get $new_arr
    local.set $doubled
    (local $sum i32)
    local.get $nums
    local.tee $arr_ptr
    i32.load  ;; load length
    local.set $arr_len
    i32.const 0
    local.set $acc
    i32.const 0
    local.set $i
    (loop $reduce_loop
      local.get $i
      local.get $arr_len
      i32.lt_s
      if
        local.get $arr_ptr
        i32.const 8
        i32.add
        local.get $i
        i32.const 4
        i32.mul
        i32.add
        i32.load  ;; current element
        local.get $acc
        i32.add
        local.set $acc
        local.get $i
        i32.const 1
        i32.add
        local.set $i
        br $reduce_loop
      end
    )
    local.get $acc
    local.set $sum
    local.get $sum
    return
  )

)
