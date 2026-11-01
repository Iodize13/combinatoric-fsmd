-- 32 x 32-bit register file: two asynchronous read ports, one write port on the clock edge.
-- $0 reads as 0 and ignores writes.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity regfile is
  port (
    clk : in  std_logic;
    we  : in  std_logic;
    ra1 : in  unsigned(4 downto 0);
    ra2 : in  unsigned(4 downto 0);
    wa  : in  unsigned(4 downto 0);
    wd  : in  word_t;
    rd1 : out word_t;
    rd2 : out word_t
  );
end entity;

architecture rtl of regfile is
  type regs_t is array (0 to 31) of word_t;
  signal regs : regs_t := (others => (others => '0'));
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' and wa /= 0 then
        regs(to_integer(wa)) <= wd;
      end if;
    end if;
  end process;

  rd1 <= (others => '0') when ra1 = 0 else regs(to_integer(ra1));
  rd2 <= (others => '0') when ra2 = 0 else regs(to_integer(ra2));
end architecture;
