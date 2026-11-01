-- Shared unsigned multiply/divide unit, "approach 2" from w03c_mult:
-- one 2W+1-bit HI:LO remainder/product register, one M register (multiplicand or divisor),
-- one adder/subtractor shared by multiply and divide.
-- Structural top: muldiv_ctrl (control unit) drives muldiv_dp (datapath: registers + ALU).
-- Multiply takes W cycles; divide takes 2W+2 (shift, then W x {subtract, test}, then fix-up).
-- hi/lo are valid in the cycle where done = '1'.
--
--   op = OP_MULTU : HI:LO <= a * b
--   op = OP_DIVU  : LO <= a / b, HI <= a mod b             (dividend = 0:a)
--   op = OP_DIVHL : LO <= HI:LO / b, HI <= HI:LO mod b      (dividend = current HI:LO)
--
-- Divide is the refined restoring divider of the slides: Remainder := dividend, shifted
-- left once; then W times: left half -= divisor, and if that went negative, add the
-- divisor back and shift in a 0, else shift in a 1; finally the left half is shifted
-- right once. HI = remainder, LO = quotient.
--
-- The ALU is not a plain W-bit adder. The divide's left half is W+1 bits (the dividend
-- may be up to 2b-1 after the first shift, and the sign of the difference is its top
-- bit), so the ALU is W+1 bits wide and the remainder register keeps one extra bit
-- above HI.
--
-- Divide flags (latched until the next start):
--   dz  = '1' : b = 0; no division is done (HI:LO holds the undivided dividend).
--   ovf = '1' : OP_DIVHL with HI >= b, so the quotient would not fit in W bits.
--               HI:LO is left as it was.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

entity muldiv is
  generic (W : positive := 32);
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    op    : in  muldiv_op_t;
    a     : in  unsigned(W-1 downto 0);
    b     : in  unsigned(W-1 downto 0);
    hi    : out unsigned(W-1 downto 0);
    lo    : out unsigned(W-1 downto 0);
    busy  : out std_logic;
    done  : out std_logic;
    dz    : out std_logic;
    ovf   : out std_logic
  );
end entity;

architecture rtl of muldiv is
  signal ctrl   : muldiv_ctrl_t;
  signal status : muldiv_status_t;
begin
  u_ctrl : entity work.muldiv_ctrl
    port map (
      clk    => clk,
      rst    => rst,
      start  => start,
      op     => op,
      status => status,
      ctrl   => ctrl,
      busy   => busy,
      done   => done
    );

  u_dp : entity work.muldiv_dp
    generic map (W => W)
    port map (
      clk    => clk,
      rst    => rst,
      ctrl   => ctrl,
      a      => a,
      b      => b,
      status => status,
      hi     => hi,
      lo     => lo,
      dz     => dz,
      ovf    => ovf
    );
end architecture;
