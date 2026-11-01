-- Shared unsigned multiply/divide unit, "approach 2" from w03c_mult:
-- one W-bit ALU, one 2W-bit HI:LO register, one M register (multiplicand or divisor).
-- W cycles per operation; hi/lo are valid in the cycle where done = '1'.
--
--   op = OP_MULTU : HI:LO <= a * b
--   op = OP_DIVU  : LO <= a / b, HI <= a mod b             (dividend = 0:a)
--   op = OP_DIVHL : LO <= HI:LO / b, HI <= HI:LO mod b      (dividend = current HI:LO)
--
-- Divide flags (latched until the next start):
--   dz  = '1' : b = 0; no division is done (HI:LO holds the undivided dividend).
--   ovf = '1' : OP_DIVHL with HI >= b, so the quotient would not fit in W bits.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package muldiv_pkg is
  subtype muldiv_op_t is std_logic_vector(1 downto 0);
  constant OP_MULTU : muldiv_op_t := "00";
  constant OP_DIVU  : muldiv_op_t := "01";
  constant OP_DIVHL : muldiv_op_t := "10";
end package;

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
  signal hi_r, lo_r, m : unsigned(W-1 downto 0);
  signal is_div        : std_logic;
  signal cnt           : natural range 0 to W;
  signal run           : std_logic;
  signal dz_r, ovf_r   : std_logic;

  -- The one shared ALU: W-bit add or subtract with carry/borrow out.
  signal alu_a, alu_sum : unsigned(W downto 0);
  signal alu_sub        : std_logic;
begin
  alu_sub <= is_div;
  alu_a   <= '0' & hi_r                       when is_div = '0' else
             '0' & hi_r(W-2 downto 0) & lo_r(W-1);
  alu_sum <= alu_a + ('0' & m)                when alu_sub = '0' else
             alu_a - ('0' & m);

  process (clk)
    variable fits : boolean;
  begin
    if rising_edge(clk) then
      done <= '0';
      if rst = '1' then
        run    <= '0';
        cnt    <= 0;
        is_div <= '0';
        hi_r   <= (others => '0');
        lo_r   <= (others => '0');
        m      <= (others => '0');
        dz_r   <= '0';
        ovf_r  <= '0';
      elsif run = '0' then
        if start = '1' then
          dz_r  <= '0';
          ovf_r <= '0';
          m     <= b;
          case op is
            when OP_MULTU =>
              is_div <= '0';
              hi_r   <= (others => '0');
              lo_r   <= a;
              cnt    <= W;
              run    <= '1';
            when OP_DIVU | OP_DIVHL =>
              is_div <= '1';
              if op = OP_DIVU then
                hi_r <= (others => '0');
                lo_r <= a;
              end if;
              if b = 0 then
                dz_r <= '1';
                done <= '1';
              elsif op = OP_DIVHL and hi_r >= b then
                ovf_r <= '1';
                done  <= '1';
              else
                cnt <= W;
                run <= '1';
              end if;
            when others =>
              done <= '1';
          end case;
        end if;
      else
        if is_div = '0' then
          -- Multiply: if LO(0) = 1 add M into HI; then shift {carry, HI, LO} right.
          if lo_r(0) = '1' then
            hi_r <= alu_sum(W downto 1);
            lo_r <= alu_sum(0) & lo_r(W-1 downto 1);
          else
            hi_r <= '0' & hi_r(W-1 downto 1);
            lo_r <= hi_r(0) & lo_r(W-1 downto 1);
          end if;
        else
          -- Divide: shift {HI, LO} left; if the shifted HI >= M, subtract and set the quotient bit.
          -- The shifted HI is W+1 bits wide: the bit pushed out of HI(W-1) counts as 2^W.
          fits := hi_r(W-1) = '1' or alu_sum(W) = '0';
          if fits then
            hi_r <= alu_sum(W-1 downto 0);
            lo_r <= lo_r(W-2 downto 0) & '1';
          else
            hi_r <= hi_r(W-2 downto 0) & lo_r(W-1);
            lo_r <= lo_r(W-2 downto 0) & '0';
          end if;
        end if;
        if cnt = 1 then
          run  <= '0';
          done <= '1';
        end if;
        cnt <= cnt - 1;
      end if;
    end if;
  end process;

  hi   <= hi_r;
  lo   <= lo_r;
  busy <= run;
  dz   <= dz_r;
  ovf  <= ovf_r;
end architecture;
