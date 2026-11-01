-- nCr datapath: operand/loop registers, comparators and adders. The multiply/divide unit is
-- outside (md_* ports) so a CPU can share it. It only executes the control word and reports
-- status; every decision is taken in ncr_ctrl. Structural: instances and wires.
-- k_reg and nmk_reg load through a 2-input mux (k_swap) so reg_en stays a plain register.
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
    ovf    : out std_logic;
    -- to/from the shared muldiv unit
    md_start : out std_logic;
    md_op    : out muldiv_op_t;
    md_a     : out unsigned(W-1 downto 0);
    md_b     : out unsigned(W-1 downto 0);
    md_lo    : in  unsigned(W-1 downto 0);
    md_done  : in  std_logic;
    md_ovf   : in  std_logic
  );
end entity;

architecture rtl of ncr_dp is
  signal n_q, r_q       : unsigned(W-1 downto 0);
  signal k_q, nmk_q     : unsigned(W-1 downto 0);
  signal i_q, res_q     : unsigned(W-1 downto 0);
  signal n_minus_r      : unsigned(W-1 downto 0);
  signal k_d, nmk_d     : unsigned(W-1 downto 0);
  signal nmk_plus_i     : unsigned(W-1 downto 0);
  signal r_gt_n         : std_logic;
  signal r_gt_n_minus_r : std_logic;
  signal i_gt_k         : std_logic;
begin
  n_reg : entity work.reg_en
    generic map (W => W)
    port map (clk => clk, rst => rst, en => ctrl.latch_nr, d => n, q => n_q);

  r_reg : entity work.reg_en
    generic map (W => W)
    port map (clk => clk, rst => rst, en => ctrl.latch_nr, d => r, q => r_q);

  sub_nr : entity work.alu
    generic map (N => W)
    port map (a => n_q, b => r_q, sub => '1', y => n_minus_r);

  k_mux : entity work.mux2
    generic map (W => W)
    port map (sel => ctrl.k_swap, a0 => r_q, a1 => n_minus_r, y => k_d);

  nmk_mux : entity work.mux2
    generic map (W => W)
    port map (sel => ctrl.k_swap, a0 => n_minus_r, a1 => r_q, y => nmk_d);

  k_reg : entity work.reg_en
    generic map (W => W)
    port map (clk => clk, rst => rst, en => ctrl.init_k, d => k_d, q => k_q);

  nmk_reg : entity work.reg_en
    generic map (W => W)
    port map (clk => clk, rst => rst, en => ctrl.init_k, d => nmk_d, q => nmk_q);

  i_reg : entity work.up_counter
    generic map (W => W)
    port map (clk => clk, rst => rst, load => ctrl.i_load, inc => ctrl.i_inc, q => i_q);

  add_nmk_i : entity work.alu
    generic map (N => W)
    port map (a => nmk_q, b => i_q, sub => '0', y => nmk_plus_i);

  b_mux : entity work.mux2
    generic map (W => W)
    port map (sel => ctrl.md_b_sel, a0 => i_q, a1 => nmk_plus_i, y => md_b);

  cmp_r_n : entity work.cmp_gt
    generic map (W => W)
    port map (a => r_q, b => n_q, gt => r_gt_n);

  cmp_r_nmr : entity work.cmp_gt
    generic map (W => W)
    port map (a => r_q, b => n_minus_r, gt => r_gt_n_minus_r);

  cmp_i_k : entity work.cmp_gt
    generic map (W => W)
    port map (a => i_q, b => k_q, gt => i_gt_k);

  res_reg_i : entity work.res_reg
    generic map (W => W)
    port map (clk => clk, rst => rst, res_op => ctrl.res_op, lo => md_lo, q => res_q);

  ovf_flag : entity work.sr_flag
    port map (clk => clk, rst => rst, clr => ctrl.ovf_clear, set => ctrl.ovf_set, q => ovf);


  status.r_gt_n         <= r_gt_n;
  status.r_gt_n_minus_r <= r_gt_n_minus_r;
  status.i_gt_k         <= i_gt_k;
  status.md_done        <= md_done;
  status.md_ovf         <= md_ovf;

  md_start <= ctrl.md_start;
  md_op    <= ctrl.md_op;
  md_a     <= res_q;

  result <= res_q;
end architecture;
