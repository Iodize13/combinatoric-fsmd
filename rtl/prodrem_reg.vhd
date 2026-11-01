-- Product/Remainder register of w03c_mult: 2W+1 bits (HI:LO plus a carry bit above HI),
-- one update per cycle selected by rem_op; synchronous reset to 0.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

entity prodrem_reg is
  generic (W : positive);
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    rem_op : in  rem_op_t;
    alu_y  : in  unsigned(W downto 0);
    a      : in  unsigned(W-1 downto 0);
    q      : out unsigned(2*W downto 0)
  );
end entity;

architecture rtl of prodrem_reg is
  signal rem_r : unsigned(2*W downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rem_r <= (others => '0');
      else
        case rem_op is
          when R_HOLD =>
            null;
          when R_LOAD_A =>
            rem_r <= resize(a, 2*W+1);
          when R_CLR_TOP =>
            rem_r <= '0' & rem_r(2*W-1 downto 0);
          when R_ADD_SHR =>
            rem_r <= '0' & alu_y & rem_r(W-1 downto 1);
          when R_SHR =>
            rem_r <= "00" & rem_r(2*W-1 downto 1);
          when R_SHL0 =>
            rem_r <= rem_r(2*W-1 downto 0) & '0';
          when R_WR_LEFT =>
            rem_r(2*W downto W) <= alu_y;
          when R_RESTORE_SHL0 =>
            rem_r <= alu_y(W-1 downto 0) & rem_r(W-1 downto 0) & '0';
          when R_SHL1 =>
            rem_r <= rem_r(2*W-1 downto 0) & '1';
          when R_FIX =>
            rem_r <= '0' & rem_r(2*W downto W+1) & rem_r(W-1 downto 0);
        end case;
      end if;
    end if;
  end process;

  q <= rem_r;
end architecture;
