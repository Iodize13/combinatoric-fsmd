-- Directed + random simulation of muldiv at W = 32 against numeric_std * / mod.
-- Prints "TB PASS <count>" on success.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.muldiv_pkg.all;

entity tb_muldiv is
  generic (N_RANDOM : natural := 2000);
end entity;

architecture sim of tb_muldiv is
  constant W : positive := 32;
  subtype word is unsigned(W-1 downto 0);
  type word_arr is array (natural range <>) of word;

  constant EDGES : word_arr := (
    x"00000000", x"00000001", x"00000002", x"00000003", x"7FFFFFFF",
    x"80000000", x"80000001", x"FFFFFFFE", x"FFFFFFFF", x"0000FFFF", x"FFFF0000");

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal start : std_logic := '0';
  signal op    : muldiv_op_t := OP_MULTU;
  signal a, b  : word := (others => '0');
  signal hi, lo : word;
  signal busy, done, dz, ovf : std_logic;
begin
  clk <= not clk after 5 ns;

  dut : entity work.muldiv
    generic map (W => W)
    port map (clk, rst, start, op, a, b, hi, lo, busy, done, dz, ovf);

  process
    variable checked, failed : natural := 0;
    variable s1, s2 : positive := 7;
    variable rnd    : real;
    variable x, y   : word;
    variable want   : unsigned(2*W-1 downto 0);

    procedure run(o : muldiv_op_t; xa, xb : word) is
    begin
      op <= o; a <= xa; b <= xb; start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait until rising_edge(clk) and done = '1';
    end procedure;

    procedure fail(msg : string) is
    begin
      report msg severity error;
      failed := failed + 1;
    end procedure;

    procedure check_mul(xa, xb : word) is
    begin
      run(OP_MULTU, xa, xb);
      if hi & lo /= xa * xb then
        fail("MULTU " & to_hstring(xa) & "*" & to_hstring(xb) & " got " & to_hstring(hi & lo));
      end if;
      checked := checked + 1;
    end procedure;

    procedure check_div(xa, xb : word) is
    begin
      run(OP_DIVU, xa, xb);
      if xb = 0 then
        if dz /= '1' then fail("DIVU by 0 without dz"); end if;
      elsif dz /= '0' or ovf /= '0' or lo /= xa / xb or hi /= xa mod xb then
        fail("DIVU " & to_hstring(xa) & "/" & to_hstring(xb) &
             " got q=" & to_hstring(lo) & " r=" & to_hstring(hi));
      end if;
      checked := checked + 1;
    end procedure;

    -- MULTU then DIVHL on the product: the nCr access pattern.
    procedure check_muldiv(xa, xb, xd : word) is
    begin
      run(OP_MULTU, xa, xb);
      want := xa * xb;
      run(OP_DIVHL, (others => '0'), xd);
      if xd = 0 then
        if dz /= '1' then fail("DIVHL by 0 without dz"); end if;
      elsif want(2*W-1 downto W) >= xd then
        if ovf /= '1' then fail("DIVHL overflow not flagged"); end if;
      elsif ovf /= '0' or lo /= resize(want / xd, W) or hi /= resize(want mod xd, W) then
        fail("DIVHL " & to_hstring(want) & "/" & to_hstring(xd) &
             " got q=" & to_hstring(lo) & " r=" & to_hstring(hi));
      end if;
      checked := checked + 1;
    end procedure;

    impure function rand_word return word is
      variable v : word;
    begin
      for k in 0 to 1 loop
        uniform(s1, s2, rnd);
        v(16*k + 15 downto 16*k) := to_unsigned(integer(trunc(rnd * 65536.0)) mod 65536, 16);
      end loop;
      return v;
    end function;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    for p in EDGES'range loop
      for q in EDGES'range loop
        check_mul(EDGES(p), EDGES(q));
        check_div(EDGES(p), EDGES(q));
        check_muldiv(EDGES(p), EDGES(q), EDGES(q));
      end loop;
    end loop;

    for t in 1 to N_RANDOM loop
      x := rand_word; y := rand_word;
      check_mul(x, y);
      check_div(x, y);
      check_muldiv(x, y, rand_word);
      check_muldiv(x, y, y);
    end loop;

    if failed = 0 then
      report "TB PASS " & integer'image(checked) severity note;
    else
      report "TB FAIL " & integer'image(failed) & "/" & integer'image(checked) severity failure;
    end if;
    std.env.finish;
  end process;
end architecture;
