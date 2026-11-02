-- Instruction memory: asynchronous read, word-addressed by addr(9 downto 2), plus a write
-- port on the clock edge (waddr is a word index) for loading programs at run time.
-- Starts as the ROM generic (a constant from program_pkg). STYLE picks the hardware:
-- IMEM_LUTRAM infers the LUT RAM; IMEM_REGISTERS builds it from one register per word,
-- a write decoder (waddr = i) and a 256:1 read mux.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity imem is
  generic (
    ROM   : mem_t;
    STYLE : imem_style_t := IMEM_LUTRAM
  );
  port (
    clk   : in  std_logic;
    we    : in  std_logic;
    waddr : in  unsigned(7 downto 0);
    wdata : in  word_t;
    addr  : in  word_t;
    instr : out word_t
  );
end entity;

architecture rtl of imem is
begin
  lutram : if STYLE = IMEM_LUTRAM generate
    signal ram : mem_t := ROM;
    -- keeps the asynchronous read: yosys would otherwise fold the PC register into a block RAM
    attribute ram_style : string;
    attribute ram_style of ram : signal is "distributed";
  begin
    process (clk)
    begin
      if rising_edge(clk) then
        if we = '1' then
          ram(to_integer(waddr)) <= wdata;
        end if;
      end if;
    end process;

    instr <= ram(to_integer(addr(9 downto 2)));
  end generate;

  registers : if STYLE = IMEM_REGISTERS generate
    signal words : mem_t;
  begin
    word : for i in mem_t'range generate
      signal q : word_t := ROM(i);
    begin
      process (clk)
      begin
        if rising_edge(clk) then
          if we = '1' and waddr = i then
            q <= wdata;
          end if;
        end if;
      end process;
      words(i) <= q;
    end generate;

    instr <= words(to_integer(addr(9 downto 2)));
  end generate;
end architecture;
