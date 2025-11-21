(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))
  (import "nexus" "http_get" (func $nexus_http_get (param i32 i32) (result i32)))
  (import "nexus" "http_post" (func $nexus_http_post (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "fs_read_file" (func $nexus_fs_read_file (param i32 i32) (result i32)))
  (import "nexus" "fs_write_file" (func $nexus_fs_write_file (param i32 i32 i32 i32) (result i32)))
  (import "nexus" "set_timeout" (func $nexus_set_timeout (param i32) (result i32)))
  (import "nexus" "promise_await" (func $nexus_promise_await (param i32) (result i32)))

  (func $fetchUser (param $user_id i32) (result i32)
    (local $wait i32)
    local.get $user_id
    i32.const 100
    i32.mul
    local.set $wait
    local.get $wait
    return
  )

  (func $fetchMultipleUsers (result i32)
    (local $user1 i32)
    ;; await expression - evaluate promise
    i32.const 1
    call $fetchUser
    call $nexus_promise_await
    local.set $user1
    (local $user2 i32)
    ;; await expression - evaluate promise
    i32.const 2
    call $fetchUser
    call $nexus_promise_await
    local.set $user2
    (local $user3 i32)
    ;; await expression - evaluate promise
    i32.const 3
    call $fetchUser
    call $nexus_promise_await
    local.set $user3
    (local $total i32)
    local.get $user1
    local.get $user2
    i32.add
    local.get $user3
    i32.add
    local.set $total
    local.get $total
    return
  )

  (func $processUserData (param $data i32) (result i32)
    (local $processed i32)
    local.get $data
    i32.const 2
    i32.mul
    local.set $processed
    local.get $processed
    return
  )

  (func $main (export "main") (result i32)
    (local $users_data i32)
    ;; await expression - evaluate promise
    call $fetchMultipleUsers
    call $nexus_promise_await
    local.set $users_data
    (local $result i32)
    local.get $users_data
    call $processUserData
    local.set $result
    local.get $result
    return
  )

)
