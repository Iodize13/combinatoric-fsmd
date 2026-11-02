-- Register write-back select: ALU result, loaded word, HI, LO or nCr result.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity wb_mux is
  port (
    sel : in  wb_sel_t;
    alu : in  word_t;
    mem : in  word_t;
    hi  : in  word_t;
    lo  : in  word_t;
    ncr : in  word_t;
    y   : out word_t
  );
end entity;

architecture rtl of wb_mux is
begin
  with sel select y <=
    alu when WB_ALU,
    mem when WB_MEM,
    hi  when WB_HI,
    lo  when WB_LO,
    ncr when WB_NCR;
end architecture;
