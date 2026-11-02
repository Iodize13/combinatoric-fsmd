-- 32-bit CPU ALU: add, sub, and, or, set-on-less-than (signed). zero = '1' when y = 0.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu_alu is
  port (
    op   : in  alu_op_t;
    a    : in  word_t;
    b    : in  word_t;
    y    : out word_t;
    zero : out std_logic
  );
end entity;

architecture rtl of cpu_alu is
  signal y_i, lt : word_t;
begin
  lt <= to_unsigned(1, 32) when signed(a) < signed(b) else to_unsigned(0, 32);

  with op select y_i <=
    a + b   when A_ADD,
    a - b   when A_SUB,
    a and b when A_AND,
    a or b  when A_OR,
    lt      when A_SLT;

  y    <= y_i;
  zero <= '1' when y_i = 0 else '0';
end architecture;
