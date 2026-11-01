-- nCr control unit: the state machine that sequences the loop. It reads the datapath
-- status and start, and drives the datapath control word and done/busy.
library ieee;
use ieee.std_logic_1164.all;
use work.muldiv_pkg.all;
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
  type state_t is (S_IDLE, S_INIT, S_CHECK, S_MUL_START, S_MUL_WAIT,
                   S_DIV_START, S_DIV_WAIT, S_FIN);
  signal state_r    : state_t;
  signal next_state : state_t;
  signal finish     : std_logic;
begin
  process (state_r, start, status)
  begin
    ctrl       <= NCR_CTRL_NOP;
    next_state <= state_r;
    finish     <= '0';
    case state_r is
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

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state_r <= S_IDLE;
        done    <= '0';
      else
        state_r <= next_state;
        done    <= finish;
      end if;
    end if;
  end process;

  busy <= '0' when state_r = S_IDLE else '1';
end architecture;
