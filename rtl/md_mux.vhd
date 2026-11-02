-- Who drives the shared muldiv unit: the ncr engine (to_ncr = '1') or the CPU (multu/divu).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;
use work.cpu_pkg.all;

entity md_mux is
  port (
    to_ncr    : in  std_logic;
    cpu_start : in  std_logic;
    cpu_op    : in  muldiv_op_t;
    cpu_a     : in  word_t;
    cpu_b     : in  word_t;
    ncr_start : in  std_logic;
    ncr_op    : in  muldiv_op_t;
    ncr_a     : in  word_t;
    ncr_b     : in  word_t;
    start     : out std_logic;
    op        : out muldiv_op_t;
    a         : out word_t;
    b         : out word_t
  );
end entity;

architecture rtl of md_mux is
begin
  start <= ncr_start when to_ncr = '1' else cpu_start;
  op    <= ncr_op    when to_ncr = '1' else cpu_op;
  a     <= ncr_a     when to_ncr = '1' else cpu_a;
  b     <= ncr_b     when to_ncr = '1' else cpu_b;
end architecture;
