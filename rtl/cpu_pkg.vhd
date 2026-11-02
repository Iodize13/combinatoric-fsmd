-- Types and encodings of the single-cycle MIPS-subset CPU (cpu.vhd).
--   R-type (opcode 0x00): add sub and or slt mfhi mflo multu divu
--   I-type: addi lw sw beq      J-type: j
--   ncr rd, rs, rt: opcode SPECIAL2 (0x1C), funct 0x1C. rd <= C(rs, rt), all ones if it
--   does not fit in 32 bits. It runs on the shared muldiv unit, so it clobbers HI/LO.
-- add/sub/addi do not trap on overflow (they behave like addu/subu/addiu).
-- multu, divu and ncr stall the PC until their unit reports done.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

package cpu_pkg is
  subtype word_t is unsigned(31 downto 0);

  constant MEM_WORDS : positive := 256;    -- per memory; addresses wrap at 4*MEM_WORDS bytes
  type mem_t is array (0 to MEM_WORDS-1) of word_t;

  constant OPC_RTYPE    : unsigned(5 downto 0) := "000000";
  constant OPC_J        : unsigned(5 downto 0) := "000010";
  constant OPC_BEQ      : unsigned(5 downto 0) := "000100";
  constant OPC_ADDI     : unsigned(5 downto 0) := "001000";
  constant OPC_SPECIAL2 : unsigned(5 downto 0) := "011100";
  constant OPC_LW       : unsigned(5 downto 0) := "100011";
  constant OPC_SW       : unsigned(5 downto 0) := "101011";

  constant FN_MFHI  : unsigned(5 downto 0) := "010000";
  constant FN_MFLO  : unsigned(5 downto 0) := "010010";
  constant FN_MULTU : unsigned(5 downto 0) := "011001";
  constant FN_DIVU  : unsigned(5 downto 0) := "011011";
  constant FN_ADD   : unsigned(5 downto 0) := "100000";
  constant FN_SUB   : unsigned(5 downto 0) := "100010";
  constant FN_AND   : unsigned(5 downto 0) := "100100";
  constant FN_OR    : unsigned(5 downto 0) := "100101";
  constant FN_SLT   : unsigned(5 downto 0) := "101010";
  constant FN_NCR   : unsigned(5 downto 0) := "011100";    -- under OPC_SPECIAL2

  type alu_op_t is (A_ADD, A_SUB, A_AND, A_OR, A_SLT);
  type wb_sel_t is (WB_ALU, WB_MEM, WB_HI, WB_LO, WB_NCR);

  type cpu_ctrl_t is record
    pc_en       : std_logic;    -- '0' stalls the PC (multu/divu/ncr not done yet)
    take_branch : std_logic;    -- next PC = branch target
    jump        : std_logic;    -- next PC = jump target
    reg_we      : std_logic;
    reg_dst_rd  : std_logic;    -- '1': write rd, '0': write rt
    alu_src_imm : std_logic;    -- '1': ALU b = sign-extended immediate, '0': rt
    alu_op      : alu_op_t;
    mem_we      : std_logic;
    wb_sel      : wb_sel_t;
    md_start    : std_logic;    -- CPU-issued multu/divu
    md_op       : muldiv_op_t;
    ncr_start   : std_logic;
    md_to_ncr   : std_logic;    -- '1': the ncr engine drives the muldiv unit
  end record;

  constant CPU_CTRL_NOP : cpu_ctrl_t :=
    ('1', '0', '0', '0', '0', '0', A_ADD, '0', WB_ALU, '0', OP_MULTU, '0', '0');

  type cpu_status_t is record
    instr    : word_t;
    alu_zero : std_logic;
    md_done  : std_logic;
    ncr_done : std_logic;
  end record;
end package;
