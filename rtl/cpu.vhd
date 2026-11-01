-- Single-cycle MIPS-subset CPU with a custom ncr instruction (encodings in cpu_pkg).
-- Harvard: 256-word instruction ROM (program_pkg) and 256-word data RAM, both read
-- asynchronously, so every instruction but multu/divu/ncr completes in one cycle.
-- multu/divu/ncr stall the PC until the shared muldiv unit (or the ncr engine) is done.
-- ROM is the program (a constant from program_pkg). Addresses 0x400-0x7FF are I/O
-- (mem_map): the store port (mem_we/mem_addr/mem_wdata) is brought out, and loads from
-- I/O return io_rdata, which the board top decodes from mem_addr in the same cycle.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;
use work.program_pkg.all;

entity cpu is
  generic (ROM : mem_t := TEST_PROGRAM);
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    pc        : out word_t;
    mem_we    : out std_logic;
    mem_addr  : out word_t;
    mem_wdata : out word_t;
    io_rdata  : in  word_t := (others => '0')
  );
end entity;

architecture rtl of cpu is
  signal ctrl   : cpu_ctrl_t;
  signal status : cpu_status_t;
begin
  u_ctrl : entity work.cpu_ctrl
    port map (clk => clk, rst => rst, status => status, ctrl => ctrl);

  u_dp : entity work.cpu_dp
    generic map (ROM => ROM)
    port map (
      clk       => clk,
      rst       => rst,
      ctrl      => ctrl,
      status    => status,
      pc        => pc,
      mem_we    => mem_we,
      mem_addr  => mem_addr,
      mem_wdata => mem_wdata,
      io_rdata  => io_rdata
    );
end architecture;
