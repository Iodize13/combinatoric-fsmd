-- Types shared by the nCr core (ncr_core.vhd): the control and status words between
-- ncr_ctrl (control unit) and ncr_dp (datapath).
library ieee;
use ieee.std_logic_1164.all;
use work.muldiv_pkg.all;

package ncr_pkg is
  type res_op_t is (RES_HOLD, RES_ONE, RES_ZERO, RES_SATURATE, RES_LOAD_LO);

  type state_t is (S_IDLE, S_INIT, S_CHECK, S_MUL_START, S_MUL_WAIT,
                   S_DIV_START, S_DIV_WAIT, S_FIN);

  type ncr_ctrl_t is record
    latch_nr  : std_logic;    -- n_l, r_l <= n, r
    init_k    : std_logic;    -- k_r, n_minus_k <= min(r, n-r), n - min(r, n-r)
    k_swap    : std_logic;    -- with init_k: k = n_l - r_l instead of r_l
    res_op    : res_op_t;
    i_load    : std_logic;    -- i <= 1
    i_inc     : std_logic;    -- i <= i + 1
    ovf_clear : std_logic;
    ovf_set   : std_logic;
    md_start  : std_logic;
    md_op     : muldiv_op_t;
    md_b_sel  : std_logic;    -- '1': muldiv b = n_minus_k + i, '0': b = i
  end record;

  constant NCR_CTRL_NOP : ncr_ctrl_t :=
    ('0', '0', '0', RES_HOLD, '0', '0', '0', '0', '0', OP_DIVHL, '0');

  type ncr_status_t is record
    r_gt_n         : std_logic;
    r_gt_n_minus_r : std_logic;
    i_gt_k         : std_logic;
    md_done        : std_logic;
    md_ovf         : std_logic;
  end record;
end package;
