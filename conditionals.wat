(module
  (memory (import "env" "memory") 1)
  (import "env" "js_console_log" (func $console_log (param i32 i32)))

  (func $max (param $a i32) (param $b i32) (result i32)
    (if
            local.get $a
      local.get $b
      i32.gt_s

      (then
        local.get $a
        return
      )
      (else
        local.get $b
        return
      )
    )
  )

  (func $main (export "main") (result i32)
    (local $x i32)
    i32.const 10
    local.set $x
    (local $y i32)
    i32.const 20
    local.set $y
    (local $result i32)
    local.get $x
    local.get $y
    call $max
    local.set $result
    local.get $result
    return
  )

)
