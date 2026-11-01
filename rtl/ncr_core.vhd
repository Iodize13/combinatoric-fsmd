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
  signal state_r : state_t;

  signal n_l, r_l         : unsigned(W-1 downto 0);
  signal n_minus_k, k_r   : unsigned(W-1 downto 0);
  signal i_r, res_r       : unsigned(W-1 downto 0);
  signal ovf_r            : std_logic;

  signal md_start, md_done, md_ovf : std_logic;
  signal md_op                     : muldiv_op_t;
  signal md_b, md_lo               : unsigned(W-1 downto 0);
begin
  -- Operands for the shared unit: MULTU res * (n-k+i), then DIVHL by i.
  process (state_r, n_minus_k, i_r)
  begin
    md_start <= '0';
    md_op    <= OP_DIVHL;
    md_b     <= i_r;
    case state_r is
      when S_MUL_START =>
        md_start <= '1';
        md_op    <= OP_MULTU;
        md_b     <= n_minus_k + i_r;
      when S_DIV_START =>
        md_start <= '1';
      when others =>
        null;
    end case;
  end process;

  u_md : entity work.muldiv
    generic map (W => W)
    port map (
      clk   => clk,
      rst   => rst,
      start => md_start,
      op    => md_op,
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
      done <= '0';
      if rst = '1' then
        state_r   <= S_IDLE;
        n_l       <= (others => '0');
        r_l       <= (others => '0');
        n_minus_k <= (others => '0');
        k_r       <= (others => '0');
        i_r       <= (others => '0');
        res_r     <= (others => '0');
        ovf_r     <= '0';
      else
        case state_r is
          when S_IDLE =>
            if start = '1' then
              n_l     <= n;
              r_l     <= r;
              ovf_r   <= '0';
              state_r <= S_INIT;
            end if;

          when S_INIT =>
            if r_l > n_l then
              res_r   <= (others => '0');
              state_r <= S_FIN;
            else
              -- k = min(r, n-r) and n_minus_k = n - k, so the loop runs k times.
              if r_l > n_l - r_l then
                k_r       <= n_l - r_l;
                n_minus_k <= r_l;
              else
                k_r       <= r_l;
                n_minus_k <= n_l - r_l;
              end if;
              res_r   <= to_unsigned(1, W);
              i_r     <= to_unsigned(1, W);
              state_r <= S_CHECK;
            end if;

          when S_CHECK =>
            if i_r > k_r then
              state_r <= S_FIN;
            else
              state_r <= S_MUL_START;
            end if;

          when S_MUL_START =>
            state_r <= S_MUL_WAIT;

          when S_MUL_WAIT =>
            if md_done = '1' then
              state_r <= S_DIV_START;
            end if;

          when S_DIV_START =>
            state_r <= S_DIV_WAIT;

          when S_DIV_WAIT =>
            if md_done = '1' then
              if md_ovf = '1' then
                res_r   <= (others => '1');
                ovf_r   <= '1';
                state_r <= S_FIN;
              else
                res_r   <= md_lo;
                i_r     <= i_r + 1;
                state_r <= S_CHECK;
              end if;
            end if;

          when S_FIN =>
            done    <= '1';
            state_r <= S_IDLE;
        end case;
      end if;
    end if;
  end process;

  result <= res_r;
  busy   <= '0' when state_r = S_IDLE else '1';
  ovf    <= ovf_r;
end architecture;
