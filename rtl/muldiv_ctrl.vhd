-- muldiv control unit: the "Control test" box of w03c_mult. A phase FSM that reads the
-- datapath status and start/op, and drives the datapath control word and done/busy.
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
  type phase_t is (P_IDLE, P_MUL, P_DIV_SHIFT0, P_DIV_SUB, P_DIV_TEST, P_DIV_FIX);
  signal phase_r    : phase_t;
  signal next_phase : phase_t;
  signal finish     : std_logic;
begin
  process (phase_r, start, op, status)
  begin
    ctrl       <= CTRL_NOP;
    next_phase <= phase_r;
    finish     <= '0';
    case phase_r is
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

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        phase_r <= P_IDLE;
        done    <= '0';
      else
        phase_r <= next_phase;
        done    <= finish;
      end if;
    end if;
  end process;

  busy <= '0' when phase_r = P_IDLE else '1';
end architecture;
