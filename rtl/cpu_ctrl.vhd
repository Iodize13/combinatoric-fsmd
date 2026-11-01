-- Control unit of the single-cycle CPU: the main decoder plus one flag that remembers that the
-- current long op (multu, divu, ncr) has been started. Structural: instances and wires.
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity cpu_ctrl is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    status : in  cpu_status_t;
    ctrl   : out cpu_ctrl_t
  );
end entity;

architecture rtl of cpu_ctrl is
  signal issued, issue, retire : std_logic;
begin
  decode : entity work.cpu_decode
    port map (rst => rst, status => status, issued => issued,
              ctrl => ctrl, issue => issue, retire => retire);

  issued_flag : entity work.sr_flag
    port map (clk => clk, rst => rst, clr => retire, set => issue, q => issued);
end architecture;
