-- Program loader on the UART. Frame: 0xA5, then 256 words big-endian, word 0 first (1024
-- bytes), then a checksum byte = sum of the 1024 bytes mod 256. hold (the CPU's reset) rises
-- at the 0xA5; each word is written to the instruction memory as its last byte arrives.
-- The reply is 'K' (CPU released once it is sent) or 'E' on a bad checksum or TIMEOUT clocks
-- without a byte (CPU stays held until a good frame). Other bytes outside a frame are ignored.
-- No reset: a held CPU stays held through CPU_RESETN, and a stalled frame ends by timeout.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity uart_loader is
  generic (TIMEOUT : positive);
  port (
    clk        : in  std_logic;
    rx_valid   : in  std_logic;
    rx_data    : in  std_logic_vector(7 downto 0);
    tx_busy    : in  std_logic;
    hold       : out std_logic;
    imem_we    : out std_logic;
    imem_waddr : out unsigned(7 downto 0);
    imem_wdata : out word_t;
    tx_start   : out std_logic;
    tx_data    : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of uart_loader is
  -- run: CPU running; halt: CPU held after an 'E'; data, sum: receiving the frame;
  -- reply: waiting for the transmitter; drain: reply byte on the line
  type state_t is (run, halt, data, sum, reply, drain);

  constant START  : unsigned(7 downto 0) := x"A5";
  constant ACK    : std_logic_vector(7 downto 0) := x"4B";    -- 'K'
  constant NAK    : std_logic_vector(7 downto 0) := x"45";    -- 'E'

  signal state  : state_t := run;
  signal count  : unsigned(9 downto 0) := (others => '0');            -- data bytes received
  signal word   : std_logic_vector(23 downto 0) := (others => '0');  -- first 3 bytes of a word
  signal csum   : unsigned(7 downto 0) := (others => '0');
  signal idle   : natural range 0 to TIMEOUT - 1 := 0;               -- clocks since a byte
  signal answer : std_logic_vector(7 downto 0) := NAK;
  signal byte   : unsigned(7 downto 0);
begin
  byte <= unsigned(rx_data);

  process (clk)
  begin
    if rising_edge(clk) then
      case state is
        when run | halt =>
          if rx_valid = '1' and byte = START then
            state <= data;
            count <= (others => '0');
            csum  <= (others => '0');
            idle  <= 0;
          end if;

        when data | sum =>
          if rx_valid = '1' then
            idle <= 0;
            if state = data then
              word  <= word(15 downto 0) & rx_data;
              csum  <= csum + byte;
              count <= count + 1;
              if count = 1023 then
                state <= sum;
              end if;
            else
              answer <= NAK;
              if byte = csum then
                answer <= ACK;
              end if;
              state <= reply;
            end if;
          elsif idle = TIMEOUT - 1 then
            answer <= NAK;
            state  <= reply;
          else
            idle <= idle + 1;
          end if;

        when reply =>
          if tx_busy = '0' then
            state <= drain;
          end if;

        when drain =>
          if tx_busy = '0' then
            state <= halt;
            if answer = ACK then
              state <= run;
            end if;
          end if;
      end case;
    end if;
  end process;

  hold       <= '0' when state = run else '1';
  imem_we    <= rx_valid when state = data and count(1 downto 0) = "11" else '0';
  imem_waddr <= count(9 downto 2);
  imem_wdata <= unsigned(word & rx_data);
  tx_start   <= '1' when state = reply and tx_busy = '0' else '0';
  tx_data    <= answer;
end architecture;
