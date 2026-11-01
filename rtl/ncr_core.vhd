-- nCr FSMD: res <- res * (n-k+i) / i for i = 1..k, k = min(r, n-r).
-- Every division is exact, so no fractions and no floating point.
-- One shared muldiv unit: MULTU leaves the 2W-bit product in HI:LO, then
-- DIVHL divides that HI:LO by i in place, with no copy between them.
-- Pulse start while busy = '0'; n and r are latched on that cycle.
-- result is valid while done = '1'. If C(n, r) does not fit in W bits, result is all ones
-- and ovf = '1'; the loop stops at the first quotient that does not fit.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

entity ncr_core is
  generic (W : positive := 32);
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;
    n      : in  unsigned(W-1 downto 0);
    r      : in  unsigned(W-1 downto 0);
    result : out unsigned(W-1 downto 0);
    busy   : out std_logic;
    done   : out std_logic;
    ovf    : out std_logic
  );
end entity;

architecture rtl of ncr_core is
  type state_t is (S_IDLE, S_INIT, S_CHECK, S_MUL_START, S_MUL_WAIT,
                   S_DIV_START, S_DIV_WAIT, S_FIN);
  signal state : state_t;

  signal nl, rl   : unsigned(W-1 downto 0);
  signal nmr, k   : unsigned(W-1 downto 0);
  signal i, res   : unsigned(W-1 downto 0);
  signal ovf_r    : std_logic;

  signal md_start, md_done, md_ovf : std_logic;
  signal md_op                     : muldiv_op_t;
  signal md_b, md_lo               : unsigned(W-1 downto 0);
begin
  md_start <= '1' when state = S_MUL_START or state = S_DIV_START else '0';
  md_op    <= OP_MULTU when state = S_MUL_START else OP_DIVHL;
  md_b     <= nmr + i when state = S_MUL_START else i;

  u_md : entity work.muldiv
    generic map (W => W)
    port map (
      clk   => clk,
      rst   => rst,
      start => md_start,
      op    => md_op,
      a     => res,
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
      done <= '0';
      if rst = '1' then
        state <= S_IDLE;
        nl    <= (others => '0');
        rl    <= (others => '0');
        nmr   <= (others => '0');
        k     <= (others => '0');
        i     <= (others => '0');
        res   <= (others => '0');
        ovf_r <= '0';
      else
        case state is
          when S_IDLE =>
            if start = '1' then
              nl    <= n;
              rl    <= r;
              ovf_r <= '0';
              state <= S_INIT;
            end if;

          when S_INIT =>
            if rl > nl then
              res   <= (others => '0');
              state <= S_FIN;
            else
              -- k = min(r, n-r) and nmr = n - k, so the loop runs k times.
              if rl > nl - rl then
                k   <= nl - rl;
                nmr <= rl;
              else
                k   <= rl;
                nmr <= nl - rl;
              end if;
              res   <= to_unsigned(1, W);
              i     <= to_unsigned(1, W);
              state <= S_CHECK;
            end if;

          when S_CHECK =>
            if i > k then
              state <= S_FIN;
            else
              state <= S_MUL_START;
            end if;

          when S_MUL_START =>
            state <= S_MUL_WAIT;

          when S_MUL_WAIT =>
            if md_done = '1' then
              state <= S_DIV_START;
            end if;

          when S_DIV_START =>
            state <= S_DIV_WAIT;

          when S_DIV_WAIT =>
            if md_done = '1' then
              if md_ovf = '1' then
                res   <= (others => '1');
                ovf_r <= '1';
                state <= S_FIN;
              else
                res   <= md_lo;
                i     <= i + 1;
                state <= S_CHECK;
              end if;
            end if;

          when S_FIN =>
            done  <= '1';
            state <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  result <= res;
  busy   <= '0' when state = S_IDLE else '1';
  ovf    <= ovf_r;
end architecture;
