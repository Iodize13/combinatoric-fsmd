-- UART program loader on nexys_a7_cpu_top, end to end over the two UART pins.
-- Frame (PC -> FPGA): 0xA5, then 256 words big-endian, word 0 first (1024 bytes), then one
-- checksum byte = sum of those 1024 bytes mod 256. The loader holds the CPU in reset from
-- the 0xA5, writes each word into the instruction memory, and answers 'K' and restarts the
-- CPU at pc 0, or answers 'E' (bad checksum, or LOAD_TIMEOUT clocks with no byte) and keeps
-- the CPU held. Bytes other than 0xA5 outside a frame are ignored.
-- The test program prints 'Z' once and spins: addi $a0,$zero,0x5A; sw $a0,1036($zero); j 2.
-- Prints "TB PASS <bytes>" on success.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_loader is
end entity;

architecture sim of tb_loader is
  constant CLKS_PER_BIT : positive := 8;
  constant DIV_LOG2     : positive := 3;
  constant TIMEOUT      : positive := 1000;    -- divided clocks, about 12 byte times
  constant BIT_TIME     : time := CLKS_PER_BIT * (10 ns * 2**DIV_LOG2);
  constant BYTE_TIME    : time := 10 * BIT_TIME;

  type words_t is array (natural range <>) of std_logic_vector(31 downto 0);
  constant PROG : words_t := (x"2004005A", x"AC04040C", x"08000002");

  signal clk    : std_logic := '0';
  signal resetn : std_logic := '0';
  signal sw     : std_logic_vector(15 downto 0) := (others => '0');
  signal led    : std_logic_vector(15 downto 0);
  signal led16g : std_logic;
  signal txd    : std_logic;            -- FPGA -> PC
  signal rxd    : std_logic := '1';     -- PC -> FPGA

  -- bytes received from the FPGA, in order
  signal got       : string(1 to 4096);
  signal got_n     : natural := 0;
  signal rx_errors : natural := 0;
begin
  clk <= not clk after 5 ns;

  dut : entity work.nexys_a7_cpu_top
    generic map (CLK_DIV_LOG2 => DIV_LOG2, CLKS_PER_BIT => CLKS_PER_BIT, DEBOUNCE => 4,
                 LOAD_TIMEOUT => TIMEOUT)
    port map (CLK100MHZ => clk, CPU_RESETN => resetn, BTNC => '0', BTNU => '0', SW => sw,
              LED => led, LED16_G => led16g, UART_RXD_OUT => txd, UART_TXD_IN => rxd);

  rx : process
    variable b : std_logic_vector(7 downto 0);
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
    got(got_n + 1) <= character'val(to_integer(unsigned(b)));
    got_n          <= got_n + 1;
  end process;

  process
    variable failed : natural := 0;
    variable mark   : natural := 0;
    variable sum    : natural := 0;

    procedure send (b : natural) is
      variable v : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(b, 8));
    begin
      rxd <= '0';
      wait for BIT_TIME;
      for i in 0 to 7 loop
        rxd <= v(i);
        wait for BIT_TIME;
      end loop;
      rxd <= '1';
      wait for BIT_TIME;
    end procedure;

    -- a whole frame of PROG padded with zero words; bad_sum flips the checksum
    procedure send_frame (bad_sum : boolean) is
      variable w : std_logic_vector(31 downto 0);
      variable b : natural;
    begin
      send(16#A5#);
      sum := 0;
      for i in 0 to 255 loop
        w := (others => '0');
        if i <= PROG'high then
          w := PROG(i);
        end if;
        for k in 3 downto 0 loop
          b   := to_integer(unsigned(w(8*k+7 downto 8*k)));
          sum := (sum + b) mod 256;
          send(b);
        end loop;
      end loop;
      if bad_sum then
        send((sum + 1) mod 256);
      else
        send(sum);
      end if;
    end procedure;

    -- wait for the bytes after mark to equal want
    procedure expect (want : string; within : time; what : string) is
    begin
      if got_n < mark + want'length then
        wait until got_n >= mark + want'length for within;
      end if;
      if got_n < mark + want'length then
        report what & ": timeout, got " & integer'image(got_n - mark) & " of " &
               integer'image(want'length) & " bytes" severity error;
        failed := failed + 1;
      elsif got(mark + 1 to mark + want'length) /= want then
        report what & ": got """ & got(mark + 1 to mark + want'length) & """, want """ &
               want & """" severity error;
        failed := failed + 1;
      end if;
      mark := got_n;
    end procedure;

    procedure expect_quiet (during : time; what : string) is
    begin
      wait for during;
      if got_n /= mark then
        report what & ": unexpected """ & got(mark + 1 to got_n) & """" severity error;
        failed := failed + 1;
      end if;
      mark := got_n;
    end procedure;

    procedure wait_line (within : time) is
    begin
      loop
        wait until got_n'event for within;
        assert got_n'event report "banner timeout" severity failure;
        exit when got(got_n) = LF;
      end loop;
      mark := got_n;
    end procedure;
  begin
    wait for 200 ns;
    resetn <= '1';
    -- the ROM program (calc.s) boots first and prints its banner
    wait_line(2 ms);
    if got(1 to 9) /= "nCr CPU r" then
      report "no calc.s banner at boot" severity error;
      failed := failed + 1;
    end if;

    -- a good frame: 'K', then the loaded program prints 'Z' once
    send_frame(false);
    expect("KZ", 20 * BYTE_TIME, "good frame");
    expect_quiet(20 * BYTE_TIME, "after good frame");

    -- stray bytes outside a frame are ignored and the program keeps running
    send(character'pos('x'));
    send(character'pos('L'));
    expect_quiet(20 * BYTE_TIME, "stray bytes");

    -- CPU_RESETN restarts the loaded program, not calc.s
    resetn <= '0';
    wait for 1 us;
    resetn <= '1';
    expect("Z", 20 * BYTE_TIME, "reset keeps loaded program");
    expect_quiet(20 * BYTE_TIME, "after reset");

    -- bad checksum: 'E' and the CPU stays held
    send_frame(true);
    expect("E", 20 * BYTE_TIME, "bad checksum");
    expect_quiet(40 * BYTE_TIME, "held after bad checksum");

    -- truncated frame: 'E' after LOAD_TIMEOUT, CPU still held
    send(16#A5#);
    for i in 1 to 10 loop
      send(16#00#);
    end loop;
    expect("E", 40 * BYTE_TIME, "truncated frame");
    expect_quiet(40 * BYTE_TIME, "held after timeout");

    -- a good frame recovers
    send_frame(false);
    expect("KZ", 20 * BYTE_TIME, "recover");

    failed := failed + rx_errors;
    if failed = 0 then
      report "TB PASS " & integer'image(got_n) severity note;
    else
      report "TB FAIL " & integer'image(failed) severity failure;
    end if;
    std.env.finish;
  end process;
end architecture;
