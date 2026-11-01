-- Nexys A7 nCr calculator end to end: set the switches, press BTNC, decode the UART line
-- bit by bit and compare the text. Then debug mode (BTNU): switch changes alone print, and
-- nothing prints while the switches stay put. Fast UART and debounce generics; real
-- clock divider.
-- Prints "TB PASS <lines>" on success.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_board is
end entity;

architecture sim of tb_board is
  constant CLKS_PER_BIT : positive := 8;
  constant BIT_TIME     : time := CLKS_PER_BIT * 40 ns;    -- 100 MHz / 4

  type case_t is record
    n, r : natural;
    text : string(1 to 24);    -- expected line, space padded
  end record;
  type cases_t is array (natural range <>) of case_t;

  constant CASES : cases_t := (
    (34, 17,  "C(34,17) = 2333606220   "),
    (67, 33,  "C(67,33) = overflow     "),
    (5, 2,    "C(5,2) = 10             "),
    (3, 5,    "C(3,5) = 0              "),
    (0, 0,    "C(0,0) = 1              "),
    (127, 1,  "C(127,1) = 127          "),
    (40, 20,  "C(40,20) = overflow     "),
    (33, 16,  "C(33,16) = 1166803110   "));

  signal clk    : std_logic := '0';
  signal resetn : std_logic := '0';
  signal btnc   : std_logic := '0';
  signal btnu   : std_logic := '0';
  signal led16g : std_logic;
  signal sw     : std_logic_vector(15 downto 0) := (others => '0');
  signal led    : std_logic_vector(15 downto 0);
  signal txd    : std_logic;
  signal line_buf  : string(1 to 80);
  signal line_len  : natural := 0;
  signal line_evt  : boolean := false;
  signal rx_errors : natural := 0;

  function trim (s : string) return string is
  begin
    for i in s'reverse_range loop
      if s(i) /= ' ' then
        return s(s'left to i);
      end if;
    end loop;
    return "";
  end function;
begin
  clk <= not clk after 5 ns;

  dut : entity work.nexys_a7_top
    generic map (CLK_DIV_LOG2 => 2, CLKS_PER_BIT => CLKS_PER_BIT, DEBOUNCE => 4)
    port map (CLK100MHZ => clk, CPU_RESETN => resetn, BTNC => btnc, BTNU => btnu, SW => sw,
              LED => led, LED16_G => led16g,
              UART_RXD_OUT => txd);

  -- UART receiver: always listening, publishes each completed line (CR dropped).
  rx : process
    variable b   : std_logic_vector(7 downto 0);
    variable c   : character;
    variable buf : string(1 to 80);
    variable n   : natural := 0;
  begin
    wait until txd = '0';
    wait for BIT_TIME / 2;
    for i in 0 to 7 loop
      wait for BIT_TIME;
      b(i) := txd;
    end loop;
    wait for BIT_TIME;
    if txd /= '1' then
      report "missing stop bit" severity error;
      rx_errors <= rx_errors + 1;
    end if;
    c := character'val(to_integer(unsigned(b)));
    if c = LF then
      line_buf <= buf;
      line_len <= n;
      line_evt <= not line_evt;
      n := 0;
    elsif c /= CR then
      n      := n + 1;
      buf(n) := c;
    end if;
  end process;

  process
    variable failed : natural := 0;
    variable lines  : natural := 0;

    procedure read_line is
    begin
      wait on line_evt for 2 ms;
      assert line_evt'event report "UART timeout" severity failure;
      lines := lines + 1;
    end procedure;
  begin
    wait for 200 ns;
    resetn <= '1';
    read_line;
    report "banner: " & line_buf(1 to line_len) severity note;
    for i in CASES'range loop
      sw <= (others => '0');
      sw(6 downto 0)  <= std_logic_vector(to_unsigned(CASES(i).n, 7));
      sw(13 downto 7) <= std_logic_vector(to_unsigned(CASES(i).r, 7));
      wait for 1 us;
      btnc <= '1';
      wait for 2 us;
      btnc <= '0';
      read_line;
      if line_buf(1 to line_len) /= trim(CASES(i).text) then
        report "got """ & line_buf(1 to line_len) & """, want """ & trim(CASES(i).text) & """"
          severity error;
        failed := failed + 1;
      end if;
      wait for 1 us;
      if (led(15) = '1') /= (CASES(i).text(12 to 19) = "overflow" or
                              CASES(i).text(13 to 20) = "overflow") then
        report "LED15 wrong after " & trim(CASES(i).text) severity error;
        failed := failed + 1;
      end if;
    end loop;
    -- debug mode: no BTNC from here on
    btnu <= '1';
    wait for 2 us;
    btnu <= '0';
    wait for 1 us;
    if led16g /= '1' then
      report "debug LED off after BTNU" severity error;
      failed := failed + 1;
    end if;
    for i in 0 to 2 loop
      sw <= (others => '0');
      sw(6 downto 0)  <= std_logic_vector(to_unsigned(CASES(i).n, 7));
      sw(13 downto 7) <= std_logic_vector(to_unsigned(CASES(i).r, 7));
      read_line;
      if line_buf(1 to line_len) /= trim(CASES(i).text) then
        report "debug: got """ & line_buf(1 to line_len) & """, want """ &
               trim(CASES(i).text) & """" severity error;
        failed := failed + 1;
      end if;
    end loop;
    -- settled and already printed: must stay quiet
    wait on line_evt for 200 us;
    if line_evt'event then
      report "debug mode printed without a switch change" severity error;
      failed := failed + 1;
    end if;
    -- BTNU again leaves debug mode: a switch change alone prints nothing
    btnu <= '1';
    wait for 2 us;
    btnu <= '0';
    wait for 1 us;
    sw(6 downto 0) <= std_logic_vector(to_unsigned(9, 7));
    wait on line_evt for 200 us;
    if line_evt'event or led16g /= '0' then
      report "still in debug mode after second BTNU" severity error;
      failed := failed + 1;
    end if;

    failed := failed + rx_errors;
    if failed = 0 then
      report "TB PASS " & integer'image(lines) severity note;
    else
      report "TB FAIL " & integer'image(failed) severity failure;
    end if;
    std.env.finish;
  end process;
end architecture;
