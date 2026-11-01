-- nCr datapath: operand/loop registers, comparators, adders, and the muldiv unit as its
-- multiply/divide functional unit. It only executes the control word and reports status;
-- every decision is taken in ncr_ctrl.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;
use work.ncr_pkg.all;

entity ncr_dp is
  generic (W : positive := 32);
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    ctrl   : in  ncr_ctrl_t;
    n      : in  unsigned(W-1 downto 0);
    r      : in  unsigned(W-1 downto 0);
    status : out ncr_status_t;
    result : out unsigned(W-1 downto 0);
    ovf    : out std_logic
  );
end entity;

architecture rtl of ncr_dp is
  signal n_l, r_l         : unsigned(W-1 downto 0);
  signal n_minus_k, k_r   : unsigned(W-1 downto 0);
  signal i_r, res_r       : unsigned(W-1 downto 0);
  signal ovf_r            : std_logic;

  signal md_done, md_ovf : std_logic;
  signal md_b, md_lo     : unsigned(W-1 downto 0);
begin
  md_b <= n_minus_k + i_r when ctrl.md_b_sel = '1' else i_r;

  u_md : entity work.muldiv
    generic map (W => W)
    port map (
      clk   => clk,
      rst   => rst,
      start => ctrl.md_start,
      op    => ctrl.md_op,
      a     => res_r,
      b     => md_b,
      hi    => open,
      lo    => md_lo,
      busy  => open,
      done  => md_done,
      dz    => open,
      ovf   => md_ovf
    );

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        n_l       <= (others => '0');
        r_l       <= (others => '0');
        n_minus_k <= (others => '0');
        k_r       <= (others => '0');
        i_r       <= (others => '0');
        res_r     <= (others => '0');
        ovf_r     <= '0';
      else
        if ctrl.latch_nr = '1' then
          n_l <= n;
          r_l <= r;
        end if;
        if ctrl.init_k = '1' then
          if ctrl.k_swap = '1' then
            k_r       <= n_l - r_l;
            n_minus_k <= r_l;
          else
            k_r       <= r_l;
            n_minus_k <= n_l - r_l;
          end if;
        end if;

        case ctrl.res_op is
          when RES_HOLD     => null;
          when RES_ONE      => res_r <= to_unsigned(1, W);
          when RES_ZERO     => res_r <= (others => '0');
          when RES_SATURATE => res_r <= (others => '1');
          when RES_LOAD_LO  => res_r <= md_lo;
        end case;

        case ctrl.i_op is
          when I_HOLD => null;
          when I_ONE  => i_r <= to_unsigned(1, W);
          when I_INC  => i_r <= i_r + 1;
        end case;

        if ctrl.ovf_clear = '1' then
          ovf_r <= '0';
        end if;
        if ctrl.ovf_set = '1' then
          ovf_r <= '1';
        end if;
      end if;
    end if;
  end process;

  status.r_gt_n         <= '1' when r_l > n_l else '0';
  status.r_gt_n_minus_r <= '1' when r_l > n_l - r_l else '0';
  status.i_gt_k         <= '1' when i_r > k_r else '0';
  status.md_done        <= md_done;
  status.md_ovf         <= md_ovf;

  result <= res_r;
  ovf    <= ovf_r;
end architecture;
