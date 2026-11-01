-- Operation codes for the shared multiply/divide unit (see muldiv.vhd).
package muldiv_pkg is
  type muldiv_op_t is (OP_MULTU, OP_DIVU, OP_DIVHL);
end package;
