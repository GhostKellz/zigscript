(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (type $lambda_type_0 (func (result i32)))
  (type $lambda_type_1 (func (param i32) (result i32)))
  (type $lambda_type_2 (func (param i32) (param i32) (result i32)))
  (type $lambda_type_3 (func (param i32) (param i32) (param i32) (result i32)))
  (type $lambda_type_4 (func (param i32) (param i32) (param i32) (param i32) (result i32)))

  (func $main (export "main") (result i32)
    (local $x i32)
    i32.const 5
    local.set $x
    (local $adder i32)
    i32.const 0  ;; lambda index
    local.set $adder
    i32.const 3
    local.get $adder
    call_indirect (type $lambda_type_1)
    return
  )

    (func $lambda_0 (param $y i32) (result i32)
      local.get $x
      local.get $y
      i32.add
      return
    )

  (table 1 funcref)
  (elem (i32.const 0) $lambda_0)
)
