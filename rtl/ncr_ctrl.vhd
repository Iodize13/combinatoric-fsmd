-- nCr control unit: the state machine that sequences the loop. It reads the datapath
-- status and start, and drives the datapath control word and done/busy.
-- Structural: instances and wires.
library ieee;
use ieee.std_logic_1164.all;
use work.ncr_pkg.all;

entity ncr_ctrl is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;
    status : in  ncr_status_t;
    ctrl   : out ncr_ctrl_t;
    busy   : out std_logic;
    done   : out std_logic
  );
end entity;

architecture rtl of ncr_ctrl is
  signal state      : state_t;
  signal next_state : state_t;
  signal finish     : std_logic;
begin
  next_logic : entity work.ncr_next
    port map (
      state      => state,
      start      => start,
      status     => status,
      ctrl       => ctrl,
      next_state => next_state,
      finish     => finish
    );

  state_reg : entity work.ncr_state_reg
    port map (
      clk        => clk,
      rst        => rst,
      next_state => next_state,
      finish     => finish,
      state      => state,
      busy       => busy,
      done       => done
    );
end architecture;
