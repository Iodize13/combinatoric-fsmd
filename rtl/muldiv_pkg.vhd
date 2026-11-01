-- Types shared by the multiply/divide unit (muldiv.vhd): the operation code and the
-- control/status words between muldiv_ctrl (the "Control test" box) and muldiv_dp (the datapath).
library ieee;
use ieee.std_logic_1164.all;

package muldiv_pkg is
  type muldiv_op_t is (OP_MULTU, OP_DIVU, OP_DIVHL);

  -- One update of the Product/Remainder register per cycle.
  type rem_op_t is (
    R_HOLD,
    R_LOAD_A,        -- resize(a)
    R_CLR_TOP,       -- DIVHL start: clear the carry bit above HI:LO
    R_ADD_SHR,       -- MUL, Product0 = 1: left half + M, then shift right
    R_SHR,           -- MUL, Product0 = 0: shift right
    R_SHL0,          -- DIV first shift
    R_WR_LEFT,       -- DIV subtract: write the ALU result into the left half
    R_RESTORE_SHL0,  -- DIV test negative: add M back, shift in 0
    R_SHL1,          -- DIV test non-negative: shift in 1
    R_FIX            -- DIV final: shift the left half right once
  );

  type muldiv_ctrl_t is record
    rem_op      : rem_op_t;
    alu_sub     : std_logic;
    m_load      : std_logic;
    cnt_load    : std_logic;
    cnt_dec     : std_logic;
    flags_clear : std_logic;
    dz_set      : std_logic;
    ovf_set     : std_logic;
  end record;

  constant CTRL_NOP : muldiv_ctrl_t := (R_HOLD, '0', '0', '0', '0', '0', '0', '0');

  type muldiv_status_t is record
    rem_lsb  : std_logic;  -- Product0
    rem_sign : std_logic;  -- top bit of the left half
    cnt_last : std_logic;  -- counter = 1
    b_zero   : std_logic;
    hi_ge_b  : std_logic;
  end record;
end package;
