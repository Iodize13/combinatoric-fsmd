-- I/O registers of the CPU calculator, word addresses from 0x400 (cpu mem_map):
--   0x400 read  n (SW6..0)
--   0x404 read  r (SW13..7)
--   0x408 read  bit 0 = a run is requested;  write: take the request (run_request)
--   0x40C read  bit 0 = UART busy;           write: send the low byte
--   0x410 write bit 0 -> LED15 (overflow lamp)
-- Reads are combinational from mem_addr, so a load sees them in its own cycle.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu_io is
  generic (NW : positive := 7);
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    mem_we    : in  std_logic;
    mem_addr  : in  word_t;
    mem_wdata : in  word_t;
    io_rdata  : out word_t;
    n         : in  std_logic_vector(NW-1 downto 0);
    r         : in  std_logic_vector(NW-1 downto 0);
    request   : in  std_logic;
    tx_busy   : in  std_logic;
    take      : out std_logic;
    tx_start  : out std_logic;
    tx_data   : out std_logic_vector(7 downto 0);
    led_ovf   : out std_logic
  );
end entity;

architecture rtl of cpu_io is
  signal reg   : natural range 0 to 7;
  signal store : std_logic;
  signal led_r : std_logic := '0';
begin
  reg   <= to_integer(mem_addr(4 downto 2));
  store <= mem_we and mem_addr(10);

  with reg select io_rdata <=
    resize(unsigned(n), 32)                  when 0,
    resize(unsigned(r), 32)                  when 1,
    (0 => request, others => '0')            when 2,
    (0 => tx_busy, others => '0')            when 3,
    (others => '0')                          when others;

  take     <= store when reg = 2 else '0';
  tx_start <= store when reg = 3 else '0';
  tx_data  <= std_logic_vector(mem_wdata(7 downto 0));

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        led_r <= '0';
      elsif store = '1' and reg = 4 then
        led_r <= mem_wdata(0);
      end if;
    end if;
  end process;

  led_ovf <= led_r;
end architecture;
