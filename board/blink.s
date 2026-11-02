; Loader smoke test for the Nexys A7 CPU top: send with scripts/load.py board/blink.s.
; Prints a greeting, then about every 0.7 s (12.5 MHz) toggles LED15 and prints the next
; letter A..Z, starting a new line after Z.
      puts "hello from a loaded program\r\n"
      addi $s0, $zero, 65          ; 'A'
      addi $s1, $zero, 0           ; LED15 state
tick: addi $t3, $zero, 1
      sub  $s1, $t3, $s1           ; toggle 0 <-> 1
      sw   $s1, 1040($zero)        ; LED15
      add  $a0, $s0, $zero
      jal  putc
      addi $s0, $s0, 1
      addi $t4, $zero, 91          ; one past 'Z'
      slt  $t3, $s0, $t4
      beq  $t3, $zero, wrap
      j    delay
wrap: addi $s0, $zero, 65
      puts "\r\n"

; 100 * 30000 * 3 cycles = 9e6 cycles
delay: addi $t1, $zero, 100
outer: addi $t2, $zero, 30000
inner: addi $t2, $t2, -1
      beq  $t2, $zero, next
      j    inner
next: addi $t1, $t1, -1
      beq  $t1, $zero, tick
      j    outer

; putc: send the low byte of $a0 once the UART is free. Clobbers $t9.
putc: lw   $t9, 1036($zero)
      beq  $t9, $zero, putc_go
      j    putc
putc_go: sw $a0, 1036($zero)
      jr   $ra
