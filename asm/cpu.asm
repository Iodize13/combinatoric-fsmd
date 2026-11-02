; customasm ruledef for the CPU's MIPS subset plus ncr (rtl/cpu_pkg.vhd).
;   customasm asm/cpu.asm prog.s -f binary -o prog.bin   big-endian words, word 0 first
; Addresses count 32-bit words, so labels, j/jal targets and beq offsets are word indexes.

#bankdef rom
{
    #bits 32
    #addr 0
    #size 256
    #outp 0
}

#subruledef reg
{
    $zero => 0`5
    $at => 1`5
    $v0 => 2`5
    $v1 => 3`5
    $a0 => 4`5
    $a1 => 5`5
    $a2 => 6`5
    $a3 => 7`5
    $t0 => 8`5
    $t1 => 9`5
    $t2 => 10`5
    $t3 => 11`5
    $t4 => 12`5
    $t5 => 13`5
    $t6 => 14`5
    $t7 => 15`5
    $s0 => 16`5
    $s1 => 17`5
    $s2 => 18`5
    $s3 => 19`5
    $s4 => 20`5
    $s5 => 21`5
    $s6 => 22`5
    $s7 => 23`5
    $t8 => 24`5
    $t9 => 25`5
    $k0 => 26`5
    $k1 => 27`5
    $gp => 28`5
    $sp => 29`5
    $fp => 30`5
    $ra => 31`5
    ${n: u5} => n
}

; R-type funct, I-type opcode
#subruledef rop
{
    add => 0x20`6
    sub => 0x22`6
    and => 0x24`6
    or  => 0x25`6
    slt => 0x2a`6
}

#subruledef mfop
{
    mfhi => 0x10`6
    mflo => 0x12`6
}

#subruledef mdop
{
    multu => 0x19`6
    divu  => 0x1b`6
}

#subruledef memop
{
    lw => 0x23`6
    sw => 0x2b`6
}

#subruledef jop
{
    j   => 0x02`6
    jal => 0x03`6
}

#ruledef
{
    {f: rop} {rd: reg}, {rs: reg}, {rt: reg} => 0`6 @ rs @ rt @ rd @ 0`5 @ f
    {f: mfop} {rd: reg} => 0`16 @ rd @ 0`5 @ f
    {f: mdop} {rs: reg}, {rt: reg} => 0`6 @ rs @ rt @ 0`10 @ f
    jr {rs: reg} => 0`6 @ rs @ 0`15 @ 0x08`6
    ncr {rd: reg}, {rs: reg}, {rt: reg} => 0x1c`6 @ rs @ rt @ rd @ 0`5 @ 0x1c`6
    addi {rt: reg}, {rs: reg}, {imm: s16} => 0x08`6 @ rs @ rt @ imm
    {op: memop} {rt: reg}, {off: s16}({rs: reg}) => op @ rs @ rt @ off
    beq {rs: reg}, {rt: reg}, {target: u8} =>
    {
        off = target - $ - 1
        0x04`6 @ rs @ rt @ off`16
    }
    {op: jop} {target: u8} => op @ 0`18 @ target
}

; Print through the program's putc routine: $a0 = character, then jal putc.
#fn putc_asm(c) => asm
{
    addi $a0, $zero, {c}
    jal putc
}

; Split in halves rather than one character at a time: customasm caps recursion depth.
#fn puts_asm(s) =>
{
    n = $sizeof(s)
    h = n / 16 * 8
    n == 8 ? putc_asm(s) : puts_asm(s[n-1:n-h]) @ puts_asm(s[n-h-1:0])
}

#ruledef
{
    putc {s} =>
    {
        $assert($sizeof(s) == 8)
        putc_asm(s)
    }
    puts {s} => puts_asm(s)
}
