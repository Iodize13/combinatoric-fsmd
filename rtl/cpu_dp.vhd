-- Datapath of the single-cycle CPU: PC, instruction memory, register file, ALU, data memory,
-- and the muldiv unit shared by multu/divu and the ncr engine. It only executes the control
-- word and reports status; every decision is taken in cpu_ctrl. Structural: instances and wires
-- (field slicing, sign extension and the jump-target concatenation are wiring).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;
use work.cpu_pkg.all;

entity cpu_dp is
  generic (ROM : mem_t);
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    ctrl       : in  cpu_ctrl_t;
    status     : out cpu_status_t;
    pc         : out word_t;
    mem_we     : out std_logic;
    mem_addr   : out word_t;
    mem_wdata  : out word_t;
    io_rdata   : in  word_t;
    imem_we    : in  std_logic;
    imem_waddr : in  unsigned(7 downto 0);
    imem_wdata : in  word_t
  );
end entity;

architecture rtl of cpu_dp is
  signal pc_q, pc_plus4, pc_next   : word_t;
  signal br_offset, br_target      : word_t;
  signal pc_br, pc_j, j_target     : word_t;
  signal instr, imm_ext            : word_t;
  signal rs, rt, rd, wa_rd, wa    : unsigned(4 downto 0);
  signal rs_val, rt_val, wd        : word_t;
  signal alu_b, alu_y              : word_t;
  signal alu_zero                  : std_logic;
  signal ram_rd, mem_rd            : word_t;
  signal ram_we                    : std_logic;
  signal md_start                  : std_logic;
  signal md_op                     : muldiv_op_t;
  signal md_a, md_b, md_hi, md_lo  : word_t;
  signal md_done, md_ovf           : std_logic;
  signal nx_start                  : std_logic;
  signal nx_op                     : muldiv_op_t;
  signal nx_a, nx_b, ncr_result    : word_t;
  signal ncr_done                  : std_logic;
begin
  -- fetch and next PC
  pc_reg : entity work.reg_en
    generic map (W => 32)
    port map (clk => clk, rst => rst, en => ctrl.pc_en, d => pc_next, q => pc_q);

  add_pc4 : entity work.alu
    generic map (N => 32)
    port map (a => pc_q, b => to_unsigned(4, 32), sub => '0', y => pc_plus4);

  imem_i : entity work.imem
    generic map (ROM => ROM)
    port map (clk => clk, we => imem_we, waddr => imem_waddr, wdata => imem_wdata,
              addr => pc_q, instr => instr);

  rs        <= instr(25 downto 21);
  rt        <= instr(20 downto 16);
  rd        <= instr(15 downto 11);
  imm_ext   <= unsigned(resize(signed(instr(15 downto 0)), 32));
  br_offset <= imm_ext(29 downto 0) & "00";
  j_target  <= pc_plus4(31 downto 28) & instr(25 downto 0) & "00";

  add_br : entity work.alu
    generic map (N => 32)
    port map (a => pc_plus4, b => br_offset, sub => '0', y => br_target);

  br_mux : entity work.mux2
    generic map (W => 32)
    port map (sel => ctrl.take_branch, a0 => pc_plus4, a1 => br_target, y => pc_br);

  j_mux : entity work.mux2
    generic map (W => 32)
    port map (sel => ctrl.jump, a0 => pc_br, a1 => j_target, y => pc_j);

  jr_mux : entity work.mux2
    generic map (W => 32)
    port map (sel => ctrl.jump_reg, a0 => pc_j, a1 => rs_val, y => pc_next);

  -- register file and ALU
  dst_mux : entity work.mux2
    generic map (W => 5)
    port map (sel => ctrl.reg_dst_rd, a0 => rt, a1 => rd, y => wa_rd);

  link_mux : entity work.mux2
    generic map (W => 5)
    port map (sel => ctrl.link, a0 => wa_rd, a1 => to_unsigned(31, 5), y => wa);

  regs : entity work.regfile
    port map (clk => clk, we => ctrl.reg_we, ra1 => rs, ra2 => rt, wa => wa, wd => wd,
              rd1 => rs_val, rd2 => rt_val);

  src_mux : entity work.mux2
    generic map (W => 32)
    port map (sel => ctrl.alu_src_imm, a0 => rt_val, a1 => imm_ext, y => alu_b);

  alu_i : entity work.cpu_alu
    port map (op => ctrl.alu_op, a => rs_val, b => alu_b, y => alu_y, zero => alu_zero);

  map_i : entity work.mem_map
    port map (we => ctrl.mem_we, addr => alu_y, ram_rd => ram_rd, io_rd => io_rdata,
              ram_we => ram_we, rd => mem_rd);

  ram : entity work.dmem
    port map (clk => clk, we => ram_we, addr => alu_y, wd => rt_val, rd => ram_rd);

  -- shared multiply/divide unit and the ncr engine that borrows it
  nx : entity work.ncr_engine
    generic map (W => 32)
    port map (
      clk      => clk,
      rst      => rst,
      start    => ctrl.ncr_start,
      n        => rs_val,
      r        => rt_val,
      result   => ncr_result,
      busy     => open,
      done     => ncr_done,
      ovf      => open,
      md_start => nx_start,
      md_op    => nx_op,
      md_a     => nx_a,
      md_b     => nx_b,
      md_lo    => md_lo,
      md_done  => md_done,
      md_ovf   => md_ovf
    );

  md_sel : entity work.md_mux
    port map (
      to_ncr    => ctrl.md_to_ncr,
      cpu_start => ctrl.md_start,
      cpu_op    => ctrl.md_op,
      cpu_a     => rs_val,
      cpu_b     => rt_val,
      ncr_start => nx_start,
      ncr_op    => nx_op,
      ncr_a     => nx_a,
      ncr_b     => nx_b,
      start     => md_start,
      op        => md_op,
      a         => md_a,
      b         => md_b
    );

  md : entity work.muldiv
    generic map (W => 32)
    port map (
      clk   => clk,
      rst   => rst,
      start => md_start,
      op    => md_op,
      a     => md_a,
      b     => md_b,
      hi    => md_hi,
      lo    => md_lo,
      busy  => open,
      done  => md_done,
      dz    => open,
      ovf   => md_ovf
    );

  wb : entity work.wb_mux
    port map (sel => ctrl.wb_sel, alu => alu_y, mem => mem_rd, hi => md_hi, lo => md_lo,
              ncr => ncr_result, pc4 => pc_plus4, y => wd);

  status.instr    <= instr;
  status.alu_zero <= alu_zero;
  status.md_done  <= md_done;
  status.ncr_done <= ncr_done;

  pc        <= pc_q;
  mem_we    <= ctrl.mem_we;
  mem_addr  <= alu_y;
  mem_wdata <= rt_val;
end architecture;
