-- Combinational half of the nCr control unit: from the current state, start and the datapath
-- status, the control word, the next state, and finish (done next cycle).
library ieee;
use ieee.std_logic_1164.all;
use work.muldiv_pkg.all;
use work.ncr_pkg.all;

entity ncr_next is
  port (
    state      : in  state_t;
    start      : in  std_logic;
    status     : in  ncr_status_t;
    ctrl       : out ncr_ctrl_t;
    next_state : out state_t;
    finish     : out std_logic
  );
end entity;

architecture rtl of ncr_next is
begin
  process (state, start, status)
  begin
    ctrl       <= NCR_CTRL_NOP;
    next_state <= state;
    finish     <= '0';
    case state is
      when S_IDLE =>
        if start = '1' then
          ctrl.latch_nr  <= '1';
          ctrl.ovf_clear <= '1';
          next_state     <= S_INIT;
        end if;

      when S_INIT =>
        if status.r_gt_n = '1' then
          ctrl.res_op <= RES_ZERO;
          next_state  <= S_FIN;
        else
          ctrl.init_k <= '1';
          ctrl.k_swap <= status.r_gt_n_minus_r;
          ctrl.res_op <= RES_ONE;
          ctrl.i_load <= '1';
          next_state  <= S_CHECK;
        end if;

      when S_CHECK =>
        if status.i_gt_k = '1' then
          next_state <= S_FIN;
        else
          next_state <= S_MUL_START;
        end if;

      when S_MUL_START =>
        ctrl.md_start <= '1';
        ctrl.md_op    <= OP_MULTU;
        ctrl.md_b_sel <= '1';
        next_state    <= S_MUL_WAIT;

      when S_MUL_WAIT =>
        if status.md_done = '1' then
          next_state <= S_DIV_START;
        end if;

      when S_DIV_START =>
        ctrl.md_start <= '1';
        next_state    <= S_DIV_WAIT;

      when S_DIV_WAIT =>
        if status.md_done = '1' then
          if status.md_ovf = '1' then
            ctrl.res_op  <= RES_SATURATE;
            ctrl.ovf_set <= '1';
            next_state   <= S_FIN;
          else
            ctrl.res_op <= RES_LOAD_LO;
            ctrl.i_inc  <= '1';
            next_state  <= S_CHECK;
          end if;
        end if;

      when S_FIN =>
        finish     <= '1';
        next_state <= S_IDLE;
    end case;
  end process;
end architecture;
