-- muldiv control unit: the "Control test" box of w03c_mult. A phase FSM that reads the
-- datapath status and start/op, and drives the datapath control word and done/busy.
-- Structural: instances and wires.
library ieee;
use ieee.std_logic_1164.all;
use work.muldiv_pkg.all;

entity muldiv_ctrl is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;
    op     : in  muldiv_op_t;
    status : in  muldiv_status_t;
    ctrl   : out muldiv_ctrl_t;
    busy   : out std_logic;
    done   : out std_logic
  );
end entity;

architecture rtl of muldiv_ctrl is
  signal phase      : phase_t;
  signal next_phase : phase_t;
  signal finish     : std_logic;
begin
  next_logic : entity work.muldiv_next
    port map (
      phase      => phase,
      start      => start,
      op         => op,
      status     => status,
      ctrl       => ctrl,
      next_phase => next_phase,
      finish     => finish
    );

  state_reg : entity work.muldiv_state_reg
    port map (
      clk        => clk,
      rst        => rst,
      next_phase => next_phase,
      finish     => finish,
      phase      => phase,
      busy       => busy,
      done       => done
    );
end architecture;
