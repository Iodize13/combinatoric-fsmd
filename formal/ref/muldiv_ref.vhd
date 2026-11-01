-- FROZEN REFERENCE: copy of rtl/muldiv.vhd at 9322694, renamed to muldiv_ref.
-- Used only by the equivalence checks (formal/equiv_*.vhd, tb/tb_equiv.vhd).
-- Do not edit; delete it once the structural RTL has been accepted.
-- Shared unsigned multiply/divide unit, "approach 2" from w03c_mult:
-- one 2W+1-bit HI:LO remainder/product register, one M register (multiplicand or divisor),
-- one adder/subtractor shared by multiply and divide.
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

entity muldiv_ref is
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

architecture rtl of muldiv_ref is
  type phase_t is (P_IDLE, P_MUL, P_DIV_SHIFT0, P_DIV_SUB, P_DIV_TEST, P_DIV_FIX);
  signal phase_r     : phase_t;
  signal rem_r       : unsigned(2*W downto 0);
  signal m_r         : unsigned(W-1 downto 0);
  signal cnt_r       : natural range 0 to W;
  signal dz_r, ovf_r : std_logic;

  -- The one shared ALU, W+1 bits: left half of rem_r +/- M, modulo 2**(W+1).
  signal alu_y   : unsigned(W downto 0);
  signal alu_sub : std_logic;
begin
  alu_sub <= '1' when phase_r = P_DIV_SUB else '0';
  alu_y   <= rem_r(2*W downto W) - ('0' & m_r) when alu_sub = '1' else
             rem_r(2*W downto W) + ('0' & m_r);

  process (clk)
  begin
    if rising_edge(clk) then
      done <= '0';
      if rst = '1' then
        phase_r <= P_IDLE;
        cnt_r   <= 0;
        rem_r   <= (others => '0');
        m_r     <= (others => '0');
        dz_r    <= '0';
        ovf_r   <= '0';
      else
        case phase_r is
          when P_IDLE =>
            if start = '1' then
              dz_r  <= '0';
              ovf_r <= '0';
              m_r   <= b;
              if op = OP_DIVHL then
                rem_r <= '0' & rem_r(2*W-1 downto 0);
              else
                rem_r <= resize(a, 2*W+1);
              end if;
              if op = OP_MULTU then
                cnt_r   <= W;
                phase_r <= P_MUL;
              elsif b = 0 then
                dz_r <= '1';
                done <= '1';
              elsif op = OP_DIVHL and rem_r(2*W-1 downto W) >= b then
                ovf_r <= '1';
                done  <= '1';
              else
                phase_r <= P_DIV_SHIFT0;
              end if;
            end if;

          when P_MUL =>
            -- If LO(0) = 1 add M into HI; then shift {carry, HI, LO} right.
            if rem_r(0) = '1' then
              rem_r <= '0' & alu_y & rem_r(W-1 downto 1);
            else
              rem_r <= "00" & rem_r(2*W-1 downto 1);
            end if;
            if cnt_r = 1 then
              phase_r <= P_IDLE;
              done    <= '1';
            end if;
            cnt_r <= cnt_r - 1;

          when P_DIV_SHIFT0 =>
            rem_r   <= rem_r(2*W-1 downto 0) & '0';
            cnt_r   <= W;
            phase_r <= P_DIV_SUB;

          when P_DIV_SUB =>
            rem_r(2*W downto W) <= alu_y;
            phase_r             <= P_DIV_TEST;

          when P_DIV_TEST =>
            -- The sign of the difference is the top bit of the left half.
            if rem_r(2*W) = '1' then
              rem_r <= alu_y(W-1 downto 0) & rem_r(W-1 downto 0) & '0';
            else
              rem_r <= rem_r(2*W-1 downto 0) & '1';
            end if;
            if cnt_r = 1 then
              phase_r <= P_DIV_FIX;
            else
              phase_r <= P_DIV_SUB;
            end if;
            cnt_r <= cnt_r - 1;

          when P_DIV_FIX =>
            rem_r   <= '0' & rem_r(2*W downto W+1) & rem_r(W-1 downto 0);
            phase_r <= P_IDLE;
            done    <= '1';
        end case;
      end if;
    end if;
  end process;

  hi   <= rem_r(2*W-1 downto W);
  lo   <= rem_r(W-1 downto 0);
  busy <= '0' when phase_r = P_IDLE else '1';
  dz   <= dz_r;
  ovf  <= ovf_r;
end architecture;
