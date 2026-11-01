-- Combinational half of the "Control test" box of w03c_mult: from the current phase, start/op
-- and the datapath status, the control word, the next phase, and finish (done next cycle).
library ieee;
use ieee.std_logic_1164.all;
use work.muldiv_pkg.all;

entity muldiv_next is
  port (
    phase      : in  phase_t;
    start      : in  std_logic;
    op         : in  muldiv_op_t;
    status     : in  muldiv_status_t;
    ctrl       : out muldiv_ctrl_t;
    next_phase : out phase_t;
    finish     : out std_logic
  );
end entity;

architecture rtl of muldiv_next is
begin
  process (phase, start, op, status)
  begin
    ctrl       <= CTRL_NOP;
    next_phase <= phase;
    finish     <= '0';
    case phase is
      when P_IDLE =>
        if start = '1' then
          ctrl.flags_clear <= '1';
          ctrl.m_load      <= '1';
          if op = OP_DIVHL then
            ctrl.rem_op <= R_CLR_TOP;
          else
            ctrl.rem_op <= R_LOAD_A;
          end if;
          if op = OP_MULTU then
            ctrl.cnt_load <= '1';
            next_phase    <= P_MUL;
          elsif status.b_zero = '1' then
            ctrl.dz_set <= '1';
            finish      <= '1';
          elsif op = OP_DIVHL and status.hi_ge_b = '1' then
            ctrl.ovf_set <= '1';
            finish       <= '1';
          else
            next_phase <= P_DIV_SHIFT0;
          end if;
        end if;

      when P_MUL =>
        if status.rem_lsb = '1' then
          ctrl.rem_op <= R_ADD_SHR;
        else
          ctrl.rem_op <= R_SHR;
        end if;
        ctrl.cnt_dec <= '1';
        if status.cnt_last = '1' then
          next_phase <= P_IDLE;
          finish     <= '1';
        end if;

      when P_DIV_SHIFT0 =>
        ctrl.rem_op   <= R_SHL0;
        ctrl.cnt_load <= '1';
        next_phase    <= P_DIV_SUB;

      when P_DIV_SUB =>
        ctrl.rem_op  <= R_WR_LEFT;
        ctrl.alu_sub <= '1';
        next_phase   <= P_DIV_TEST;

      when P_DIV_TEST =>
        if status.rem_sign = '1' then
          ctrl.rem_op <= R_RESTORE_SHL0;
        else
          ctrl.rem_op <= R_SHL1;
        end if;
        ctrl.cnt_dec <= '1';
        if status.cnt_last = '1' then
          next_phase <= P_DIV_FIX;
        else
          next_phase <= P_DIV_SUB;
        end if;

      when P_DIV_FIX =>
        ctrl.rem_op <= R_FIX;
        next_phase  <= P_IDLE;
        finish      <= '1';
    end case;
  end process;
end architecture;
