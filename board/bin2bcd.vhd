-- Binary to packed BCD by double dabble (shift and add 3), one input bit per cycle.
-- Pulse start; done pulses W cycles later with bcd valid until the next start.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bin2bcd is
  generic (
    W      : positive;
    DIGITS : positive
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    bin   : in  unsigned(W-1 downto 0);
    bcd   : out unsigned(4*DIGITS-1 downto 0);
    done  : out std_logic
  );
end entity;

architecture rtl of bin2bcd is
  signal bin_r : unsigned(W-1 downto 0) := (others => '0');
  signal bcd_r : unsigned(4*DIGITS-1 downto 0) := (others => '0');
  signal left  : natural range 0 to W := 0;
begin
  process (clk)
    variable v : unsigned(4*DIGITS-1 downto 0);
  begin
    if rising_edge(clk) then
      done <= '0';
      if rst = '1' then
        left <= 0;
      elsif start = '1' then
        bin_r <= bin;
        bcd_r <= (others => '0');
        left  <= W;
      elsif left /= 0 then
        v := bcd_r;
        for d in 0 to DIGITS-1 loop
          if v(4*d+3 downto 4*d) >= 5 then
            v(4*d+3 downto 4*d) := v(4*d+3 downto 4*d) + 3;
          end if;
        end loop;
        bcd_r <= v(4*DIGITS-2 downto 0) & bin_r(W-1);
        bin_r <= bin_r(W-2 downto 0) & '0';
        left  <= left - 1;
        if left = 1 then
          done <= '1';
        end if;
      end if;
    end if;
  end process;

  bcd <= bcd_r;
end architecture;
