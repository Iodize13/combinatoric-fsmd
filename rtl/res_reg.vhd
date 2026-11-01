-- Result register of the nCr datapath: hold, 1, 0, all ones, or the muldiv LO word;
-- synchronous reset to 0.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ncr_pkg.all;

entity res_reg is
  generic (W : positive);
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    res_op : in  res_op_t;
    lo     : in  unsigned(W-1 downto 0);
    q      : out unsigned(W-1 downto 0)
  );
end entity;

architecture rtl of res_reg is
  signal q_r : unsigned(W-1 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        q_r <= (others => '0');
      else
        case res_op is
          when RES_HOLD     => null;
          when RES_ONE      => q_r <= to_unsigned(1, W);
          when RES_ZERO     => q_r <= (others => '0');
          when RES_SATURATE => q_r <= (others => '1');
          when RES_LOAD_LO  => q_r <= lo;
        end case;
      end if;
    end if;
  end process;

  q <= q_r;
end architecture;
