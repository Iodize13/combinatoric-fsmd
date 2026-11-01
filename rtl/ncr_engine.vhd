-- nCr control unit + datapath without a multiply/divide unit of its own: it drives an
-- external muldiv through the md_* ports. ncr_core pairs it with a private muldiv; the CPU
-- shares its muldiv with it instead. Timing and result are the same as ncr_core.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;
use work.ncr_pkg.all;

entity ncr_engine is
  generic (W : positive := 32);
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    start    : in  std_logic;
    n        : in  unsigned(W-1 downto 0);
    r        : in  unsigned(W-1 downto 0);
    result   : out unsigned(W-1 downto 0);
    busy     : out std_logic;
    done     : out std_logic;
    ovf      : out std_logic;
    md_start : out std_logic;
    md_op    : out muldiv_op_t;
    md_a     : out unsigned(W-1 downto 0);
    md_b     : out unsigned(W-1 downto 0);
    md_lo    : in  unsigned(W-1 downto 0);
    md_done  : in  std_logic;
    md_ovf   : in  std_logic
  );
end entity;

architecture rtl of ncr_engine is
  signal ctrl   : ncr_ctrl_t;
  signal status : ncr_status_t;
begin
  u_ctrl : entity work.ncr_ctrl
    port map (
      clk    => clk,
      rst    => rst,
      start  => start,
      status => status,
      ctrl   => ctrl,
      busy   => busy,
      done   => done
    );

  u_dp : entity work.ncr_dp
    generic map (W => W)
    port map (
      clk      => clk,
      rst      => rst,
      ctrl     => ctrl,
      n        => n,
      r        => r,
      status   => status,
      result   => result,
      ovf      => ovf,
      md_start => md_start,
      md_op    => md_op,
      md_a     => md_a,
      md_b     => md_b,
      md_lo    => md_lo,
      md_done  => md_done,
      md_ovf   => md_ovf
    );
end architecture;
