-- muldiv datapath, "approach 2" of w03c_mult: M register -> ALU -> Product/Remainder register,
-- plus the iteration counter and the dz/ovf flag registers. It only executes the control word
-- and reports status; every decision is taken in muldiv_ctrl.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

entity muldiv_dp is
  generic (W : positive := 32);
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    ctrl   : in  muldiv_ctrl_t;
    a      : in  unsigned(W-1 downto 0);
    b      : in  unsigned(W-1 downto 0);
    status : out muldiv_status_t;
    hi     : out unsigned(W-1 downto 0);
    lo     : out unsigned(W-1 downto 0);
    dz     : out std_logic;
    ovf    : out std_logic
  );
end entity;

architecture rtl of muldiv_dp is
  signal rem_r       : unsigned(2*W downto 0);
  signal m_r         : unsigned(W-1 downto 0);
  signal cnt_r       : natural range 0 to W;
  signal dz_r, ovf_r : std_logic;
  signal alu_y       : unsigned(W downto 0);
begin
  u_alu : entity work.alu
    generic map (N => W+1)
    port map (
      a   => rem_r(2*W downto W),
      b   => '0' & m_r,
      sub => ctrl.alu_sub,
      y   => alu_y
    );

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnt_r <= 0;
        rem_r <= (others => '0');
        m_r   <= (others => '0');
        dz_r  <= '0';
        ovf_r <= '0';
      else
        case ctrl.rem_op is
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

        if ctrl.m_load = '1' then
          m_r <= b;
        end if;
        if ctrl.cnt_load = '1' then
          cnt_r <= W;
        elsif ctrl.cnt_dec = '1' then
          cnt_r <= cnt_r - 1;
        end if;
        if ctrl.flags_clear = '1' then
          dz_r  <= '0';
          ovf_r <= '0';
        end if;
        if ctrl.dz_set = '1' then
          dz_r <= '1';
        end if;
        if ctrl.ovf_set = '1' then
          ovf_r <= '1';
        end if;
      end if;
    end if;
  end process;

  status.rem_lsb  <= rem_r(0);
  status.rem_sign <= rem_r(2*W);
  status.cnt_last <= '1' when cnt_r = 1 else '0';
  status.b_zero   <= '1' when b = 0 else '0';
  status.hi_ge_b  <= '1' when rem_r(2*W-1 downto W) >= b else '0';

  hi  <= rem_r(2*W-1 downto W);
  lo  <= rem_r(W-1 downto 0);
  dz  <= dz_r;
  ovf <= ovf_r;
end architecture;
