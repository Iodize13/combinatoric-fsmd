-- Formats nCr results as text for the UART: after reset it sends a banner, and on each go
-- it sends "C(n,r) = <decimal>" (or "= overflow") followed by CR LF.
-- n, r and result are converted to decimal by three bin2bcd units in parallel.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ncr_report is
  generic (NW : positive := 7);
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    go       : in  std_logic;
    n        : in  unsigned(NW-1 downto 0);
    r        : in  unsigned(NW-1 downto 0);
    result   : in  unsigned(31 downto 0);
    ovf      : in  std_logic;
    busy     : out std_logic;
    tx_start : out std_logic;
    tx_data  : out std_logic_vector(7 downto 0);
    tx_busy  : in  std_logic
  );
end entity;

architecture rtl of ncr_report is
  constant NR_DIGITS  : positive := 3;     -- enough for NW <= 9
  constant RES_DIGITS : positive := 10;    -- 2^32 - 1 = 4294967295

  type msg_t is array (0 to 63) of std_logic_vector(7 downto 0);
  type state_t is (S_BANNER, S_IDLE, S_CONVERT, S_BUILD, S_SEND, S_SEND_WAIT);

  signal state    : state_t := S_BANNER;
  signal msg      : msg_t := (others => x"00");
  signal len, pos : natural range 0 to 64 := 0;
  signal conv     : std_logic;
  signal ovf_l    : std_logic := '0';
  signal n_bcd, r_bcd : unsigned(4*NR_DIGITS-1 downto 0);
  signal res_bcd  : unsigned(4*RES_DIGITS-1 downto 0);
  signal res_done : std_logic;

  procedure put (variable m : inout msg_t; variable k : inout natural; s : string) is
  begin
    for i in s'range loop
      m(k) := std_logic_vector(to_unsigned(character'pos(s(i)), 8));
      k    := k + 1;
    end loop;
  end procedure;

  -- Decimal digits of a packed BCD value, without leading zeros ("0" for zero).
  procedure put_dec (variable m : inout msg_t; variable k : inout natural; bcd : unsigned) is
    constant D       : natural := bcd'length / 4;
    variable b       : unsigned(bcd'length-1 downto 0) := bcd;
    variable digit   : unsigned(3 downto 0);
    variable leading : boolean := true;
  begin
    for i in D-1 downto 0 loop
      digit := b(4*i+3 downto 4*i);
      if digit /= 0 or i = 0 then
        leading := false;
      end if;
      if not leading then
        m(k) := std_logic_vector(to_unsigned(48 + to_integer(digit), 8));
        k    := k + 1;
      end if;
    end loop;
  end procedure;
begin
  conv <= '1' when state = S_IDLE and go = '1' else '0';

  n_dec : entity work.bin2bcd
    generic map (W => NW, DIGITS => NR_DIGITS)
    port map (clk => clk, rst => rst, start => conv, bin => n, bcd => n_bcd, done => open);

  r_dec : entity work.bin2bcd
    generic map (W => NW, DIGITS => NR_DIGITS)
    port map (clk => clk, rst => rst, start => conv, bin => r, bcd => r_bcd, done => open);

  res_dec : entity work.bin2bcd
    generic map (W => 32, DIGITS => RES_DIGITS)
    port map (clk => clk, rst => rst, start => conv, bin => result, bcd => res_bcd,
              done => res_done);

  process (clk)
    variable m : msg_t;
    variable k : natural range 0 to 64;
  begin
    if rising_edge(clk) then
      tx_start <= '0';
      if rst = '1' then
        state <= S_BANNER;
      else
        case state is
          when S_BANNER =>
            k := 0;
            put(m, k, "nCr ready: n = SW6..0, r = SW13..7, BTNC = run, BTNU = debug" & CR & LF);
            msg   <= m;
            len   <= k;
            pos   <= 0;
            state <= S_SEND;

          when S_IDLE =>
            if go = '1' then
              ovf_l <= ovf;
              state <= S_CONVERT;
            end if;

          when S_CONVERT =>
            -- n and r (NW cycles) finish before result (32 cycles)
            if res_done = '1' then
              state <= S_BUILD;
            end if;

          when S_BUILD =>
            k := 0;
            put(m, k, "C(");
            put_dec(m, k, n_bcd);
            put(m, k, ",");
            put_dec(m, k, r_bcd);
            put(m, k, ") = ");
            if ovf_l = '1' then
              put(m, k, "overflow");
            else
              put_dec(m, k, res_bcd);
            end if;
            put(m, k, CR & LF);
            msg   <= m;
            len   <= k;
            pos   <= 0;
            state <= S_SEND;

          when S_SEND =>
            if pos = len then
              state <= S_IDLE;
            elsif tx_busy = '0' then
              tx_data  <= msg(pos);
              tx_start <= '1';
              pos      <= pos + 1;
              state    <= S_SEND_WAIT;
            end if;

          when S_SEND_WAIT =>
            -- uart_tx raises busy the cycle after start
            state <= S_SEND;
        end case;
      end if;
    end if;
  end process;

  busy <= '0' when state = S_IDLE else '1';
end architecture;
