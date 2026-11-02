; nCr calculator for the Nexys A7 CPU top (board/nexys_a7_cpu_top.vhd, I/O in board/cpu_io.vhd).
; Waits for a run request (BTNC, or a switch change in debug mode), computes C(n, r) with
; the ncr instruction, and prints "C(n,r) = <decimal>" or "C(n,r) = overflow" on the UART.
; Decimal conversion is software: repeated divu by 10.
      puts "nCr CPU ready: n = SW6..0, r = SW13..7, BTNC = run, BTNU = debug\r\n"
wait: lw   $t0, 1032($zero)        ; run requested?
      beq  $t0, $zero, wait
      sw   $zero, 1032($zero)      ; take it (records the switches for debug mode)
      lw   $s0, 1024($zero)        ; n
      lw   $s1, 1028($zero)        ; r
      ncr  $s2, $s0, $s1
      puts "C("
      add  $a0, $s0, $zero
      jal  putdec
      putc ","
      add  $a0, $s1, $zero
      jal  putdec
      puts ") = "
      addi $t0, $zero, -1          ; ncr saturates to all ones on overflow
      beq  $s2, $t0, over
      sw   $zero, 1040($zero)      ; LED15 off
      add  $a0, $s2, $zero
      jal  putdec
      j    eol
over: addi $t0, $zero, 1
      sw   $t0, 1040($zero)        ; LED15 on
      puts "overflow"
eol:  puts "\r\n"
      j    wait

; putc: send the low byte of $a0 once the UART is free. Clobbers $t9.
putc: lw   $t9, 1036($zero)
      beq  $t9, $zero, putc_go
      j    putc
putc_go: sw $a0, 1036($zero)
      jr   $ra

; putdec: print $a0 in decimal. Digits go to RAM words 0, 1, ... lowest first, then are
; printed back from the top. Clobbers $a0, $t1-$t3, $t9, $s6 ($ra across the putc calls).
putdec: add $s6, $ra, $zero
      addi $t1, $zero, 10
      addi $t2, $zero, 0
pd_div: divu $a0, $t1
      mfhi $t3                     ; lowest digit
      mflo $a0
      sw   $t3, 0($t2)
      addi $t2, $t2, 4
      beq  $a0, $zero, pd_out
      j    pd_div
pd_out: addi $t2, $t2, -4
      lw   $a0, 0($t2)
      addi $a0, $a0, 48            ; '0'
      jal  putc
      beq  $t2, $zero, pd_end
      j    pd_out
pd_end: add $ra, $s6, $zero
      jr   $ra
