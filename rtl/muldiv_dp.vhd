-- muldiv datapath, "approach 2" of w03c_mult: M register -> ALU -> Product/Remainder register,
-- plus the iteration counter and the dz/ovf flag registers. It only executes the control word
-- and reports status; every decision is taken in muldiv_ctrl. Structural: instances and wires.
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
  signal rem_q    : unsigned(2*W downto 0);
  signal m_q      : unsigned(W-1 downto 0);
  signal alu_y    : unsigned(W downto 0);
  signal cnt_last : std_logic;
  signal b_zero   : std_logic;
  signal hi_ge_b  : std_logic;
  signal rem_lsb  : std_logic;
  signal rem_sign : std_logic;
begin
  m_reg : entity work.reg_en
    generic map (W => W)
    port map (clk => clk, rst => rst, en => ctrl.m_load, d => b, q => m_q);

  alu_i : entity work.alu
    generic map (N => W+1)
    port map (a => rem_q(2*W downto W), b => '0' & m_q, sub => ctrl.alu_sub, y => alu_y);

  prodrem_reg : entity work.prodrem_reg
    generic map (W => W)
    port map (clk => clk, rst => rst, rem_op => ctrl.rem_op, alu_y => alu_y, a => a, q => rem_q);

  cnt : entity work.down_counter
    generic map (W => W)
    port map (clk => clk, rst => rst, load => ctrl.cnt_load, dec => ctrl.cnt_dec, last => cnt_last);

  dz_flag : entity work.sr_flag
    port map (clk => clk, rst => rst, clr => ctrl.flags_clear, set => ctrl.dz_set, q => dz);

  ovf_flag : entity work.sr_flag
    port map (clk => clk, rst => rst, clr => ctrl.flags_clear, set => ctrl.ovf_set, q => ovf);

  status_i : entity work.muldiv_status
    generic map (W => W)
    port map (
      b        => b,
      rem_q    => rem_q,
      b_zero   => b_zero,
      hi_ge_b  => hi_ge_b,
      rem_lsb  => rem_lsb,
      rem_sign => rem_sign
    );

  status.rem_lsb  <= rem_lsb;
  status.rem_sign <= rem_sign;
  status.cnt_last <= cnt_last;
  status.b_zero   <= b_zero;
  status.hi_ge_b  <= hi_ge_b;

  hi <= rem_q(2*W-1 downto W);
  lo <= rem_q(W-1 downto 0);
end architecture;
