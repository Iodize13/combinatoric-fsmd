-- Data address map: 0x000-0x3FF is the data RAM, 0x400-0x7FF is I/O (address bit 10);
-- higher addresses alias these. Stores to I/O do not reach the RAM; loads from I/O return
-- io_rd, which the board top decodes from the address.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity mem_map is
  port (
    we     : in  std_logic;
    addr   : in  word_t;
    ram_rd : in  word_t;
    io_rd  : in  word_t;
    ram_we : out std_logic;
    rd     : out word_t
  );
end entity;

architecture rtl of mem_map is
begin
  ram_we <= we and not addr(10);
  rd     <= io_rd when addr(10) = '1' else ram_rd;
end architecture;
