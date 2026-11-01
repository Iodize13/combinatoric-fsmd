# C(5,2) and every ALU op
      addi $t0, $zero, 5
      addi $t1, $zero, 2
      ncr  $t2, $t0, $t1
      sw   $t2, 0($zero)
      add  $t3, $t2, $t0
      sub  $t4, $t3, $t1
      and  $t5, $t3, $t4
      or   $t6, $t3, $t1
      slt  $t7, $t1, $t0
      slt  $s0, $t0, $t1
      sw   $t3, 4($zero)
      sw   $t4, 8($zero)
      sw   $t5, 12($zero)
      sw   $t6, 16($zero)
      sw   $t7, 20($zero)
      sw   $s0, 24($zero)
# load, negative immediate, writes to $zero are dropped
      lw   $s1, 0($zero)
      addi $s1, $s1, -3
      sw   $s1, 28($zero)
      addi $zero, $zero, 5
      sw   $zero, 32($zero)
# multu: 0xFFFFFFFF^2 = 0xFFFFFFFE_00000001
      addi $s2, $zero, -1
      multu $s2, $s2
      mfhi $s3
      mflo $s4
      sw   $s3, 36($zero)
      sw   $s4, 40($zero)
# slt is signed: -1 < 2
      slt  $s0, $s2, $t1
      sw   $s0, 68($zero)
# divu: 100 / 7 = 14 rem 2
      addi $s5, $zero, 100
      addi $s6, $zero, 7
      divu $s5, $s6
      mflo $s3
      mfhi $s4
      sw   $s3, 44($zero)
      sw   $s4, 48($zero)
# ncr overflow saturates; r > n gives 0; largest 32-bit C(34,17)
      addi $t0, $zero, 67
      addi $t1, $zero, 33
      ncr  $t2, $t0, $t1
      sw   $t2, 52($zero)
      ncr  $t2, $t1, $t0
      sw   $t2, 56($zero)
      addi $t0, $zero, 34
      addi $t1, $zero, 17
      ncr  $t2, $t0, $t1
      sw   $t2, 60($zero)
# sum of C(10,k) for k = 0..10 = 1024: beq taken and not taken, j, ncr back to back with add
      addi $t0, $zero, 10
      addi $t1, $zero, 0
      addi $t2, $zero, 0
      addi $t3, $zero, 11
loop: beq  $t1, $t3, done
      ncr  $t4, $t0, $t1
      add  $t2, $t2, $t4
      addi $t1, $t1, 1
      j    loop
done: sw   $t2, 64($zero)
# jal / jr: a subroutine doubles $a0 into $v0 and returns through $ra
      addi $a0, $zero, 21
      jal  double
      sw   $v0, 72($zero)
halt: j    halt
double: add $v0, $a0, $a0
      jr   $ra
