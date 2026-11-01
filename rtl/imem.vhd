-- Instruction memory: read-only, asynchronous read, word-addressed by addr(9 downto 2).
-- Contents are the ROM generic (a constant from program_pkg).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity imem is
  generic (ROM : mem_t);
  port (
    addr  : in  word_t;
    instr : out word_t
  );
end entity;

architecture rtl of imem is
begin
  instr <= ROM(to_integer(addr(9 downto 2)));
end architecture;
