-- Combinational main decoder of the single-cycle CPU: from the instruction, the ALU zero flag
-- and the long-op handshake, the control word for this cycle.
-- Long ops (multu, divu, ncr): the first cycle starts the unit (issue = '1') and stalls the PC;
-- the PC stays stalled until the unit's done, which ends the op (retire = '1').
-- During reset nothing is written and nothing is started.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;
use work.cpu_pkg.all;

entity cpu_decode is
  port (
    rst    : in  std_logic;
    status : in  cpu_status_t;
    issued : in  std_logic;    -- the long op in instr has been started
    ctrl   : out cpu_ctrl_t;
    issue  : out std_logic;
    retire : out std_logic
  );
end entity;

architecture rtl of cpu_decode is
begin
  process (rst, status, issued)
    variable opc, fn  : unsigned(5 downto 0);
    variable md_op_v  : boolean;
    variable ncr_op_v : boolean;
    variable done_v   : std_logic;
  begin
    opc      := status.instr(31 downto 26);
    fn       := status.instr(5 downto 0);
    md_op_v  := opc = OPC_RTYPE and (fn = FN_MULTU or fn = FN_DIVU);
    ncr_op_v := opc = OPC_SPECIAL2 and fn = FN_NCR;
    done_v   := status.ncr_done when ncr_op_v else status.md_done;

    ctrl   <= CPU_CTRL_NOP;
    issue  <= '0';
    retire <= '0';

    if md_op_v or ncr_op_v then
      if issued = '0' then
        issue <= '1';
      elsif done_v = '1' then
        retire <= '1';
      end if;
      ctrl.pc_en <= issued and done_v;
    end if;

    case opc is
      when OPC_RTYPE =>
        ctrl.reg_dst_rd <= '1';
        case fn is
          when FN_ADD  => ctrl.reg_we <= '1'; ctrl.alu_op <= A_ADD;
          when FN_SUB  => ctrl.reg_we <= '1'; ctrl.alu_op <= A_SUB;
          when FN_AND  => ctrl.reg_we <= '1'; ctrl.alu_op <= A_AND;
          when FN_OR   => ctrl.reg_we <= '1'; ctrl.alu_op <= A_OR;
          when FN_SLT  => ctrl.reg_we <= '1'; ctrl.alu_op <= A_SLT;
          when FN_JR   => ctrl.jump_reg <= '1';
          when FN_MFHI => ctrl.reg_we <= '1'; ctrl.wb_sel <= WB_HI;
          when FN_MFLO => ctrl.reg_we <= '1'; ctrl.wb_sel <= WB_LO;
          when FN_MULTU =>
            ctrl.md_start <= not issued;
            ctrl.md_op    <= OP_MULTU;
          when FN_DIVU =>
            ctrl.md_start <= not issued;
            ctrl.md_op    <= OP_DIVU;
          when others => null;
        end case;

      when OPC_SPECIAL2 =>
        if fn = FN_NCR then
          ctrl.reg_dst_rd <= '1';
          ctrl.wb_sel     <= WB_NCR;
          ctrl.reg_we     <= issued and done_v;
          ctrl.ncr_start  <= not issued;
          ctrl.md_to_ncr  <= '1';
        end if;

      when OPC_ADDI =>
        ctrl.reg_we      <= '1';
        ctrl.alu_src_imm <= '1';

      when OPC_LW =>
        ctrl.reg_we      <= '1';
        ctrl.alu_src_imm <= '1';
        ctrl.wb_sel      <= WB_MEM;

      when OPC_SW =>
        ctrl.mem_we      <= '1';
        ctrl.alu_src_imm <= '1';

      when OPC_BEQ =>
        ctrl.alu_op      <= A_SUB;
        ctrl.take_branch <= status.alu_zero;

      when OPC_J =>
        ctrl.jump <= '1';

      when OPC_JAL =>
        ctrl.jump   <= '1';
        ctrl.link   <= '1';
        ctrl.reg_we <= '1';
        ctrl.wb_sel <= WB_LINK;

      when others => null;
    end case;

    if rst = '1' then
      ctrl  <= CPU_CTRL_NOP;
      issue <= '0';
    end if;
  end process;
end architecture;
