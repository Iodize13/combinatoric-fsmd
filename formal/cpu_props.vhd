-- Formal harness for the CPU control unit (VHDL-2008 PSL, read by ghdl-yosys-plugin).
-- cpu_ctrl sees any instruction word, any ALU zero flag, and abstract muldiv / ncr units
-- whose done arrives one to MAX_LAT cycles after start. The real units are proved in
-- muldiv.sby / ncr.sby; this checks the decoder and the multu/divu/ncr stall handshake.
-- The register file rides along with free inputs for the $0 and write/read checks.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;
use work.cpu_pkg.all;

entity cpu_props is
  generic (MAX_LAT : positive := 3);
  port (
    clk      : in std_logic;
    rst      : in std_logic;
    instr    : in word_t;
    alu_zero : in std_logic;
    md_done  : in std_logic;
    ncr_done : in std_logic;
    rf_we    : in std_logic;
    rf_ra1   : in unsigned(4 downto 0);
    rf_ra2   : in unsigned(4 downto 0);
    rf_wa    : in unsigned(4 downto 0);
    rf_wd    : in word_t
  );
end entity;

architecture formal of cpu_props is
  signal status       : cpu_status_t;
  signal ctrl         : cpu_ctrl_t;
  signal opc, fn      : unsigned(5 downto 0);
  signal is_md, is_ncr, is_long : boolean;
  -- abstract units: busy from the cycle after start until done
  signal md_busy, ncr_busy : std_logic := '0';
  signal md_age, ncr_age   : natural range 0 to MAX_LAT := 0;
  -- environment and bookkeeping
  signal instr_q      : word_t := (others => '0');
  signal held         : std_logic := '0';    -- last cycle stalled, so the PC (and instr) holds
  signal started      : std_logic := '0';    -- this instruction already started its unit
  signal stall_len    : natural range 0 to MAX_LAT + 3 := 0;
  -- register file
  signal rd1, rd2     : word_t;
  signal last_we      : std_logic := '0';
  signal last_wa      : unsigned(4 downto 0) := (others => '0');
  signal last_wd      : word_t := (others => '0');
begin
  status <= (instr => instr, alu_zero => alu_zero, md_done => md_done, ncr_done => ncr_done);

  dut : entity work.cpu_ctrl
    port map (clk => clk, rst => rst, status => status, ctrl => ctrl);

  rf : entity work.regfile
    port map (clk => clk, we => rf_we, ra1 => rf_ra1, ra2 => rf_ra2, wa => rf_wa, wd => rf_wd,
              rd1 => rd1, rd2 => rd2);

  opc     <= instr(31 downto 26);
  fn      <= instr(5 downto 0);
  is_md   <= opc = OPC_RTYPE and (fn = FN_MULTU or fn = FN_DIVU);
  is_ncr  <= opc = OPC_SPECIAL2 and fn = FN_NCR;
  is_long <= is_md or is_ncr;

  process (clk)
  begin
    if rising_edge(clk) then
      instr_q <= instr;
      last_we <= rf_we;
      last_wa <= rf_wa;
      last_wd <= rf_wd;
      if rst = '1' then
        md_busy   <= '0';
        ncr_busy  <= '0';
        md_age    <= 0;
        ncr_age   <= 0;
        held      <= '0';
        started   <= '0';
        stall_len <= 0;
      else
        -- the ncr engine runs the shared muldiv itself, so CPU-side md_busy tracks multu/divu only
        if md_done = '1' then
          md_busy <= '0';
          md_age  <= 0;
        elsif ctrl.md_start = '1' then
          md_busy <= '1';
        elsif md_busy = '1' and md_age < MAX_LAT then
          md_age <= md_age + 1;
        end if;
        if ncr_done = '1' then
          ncr_busy <= '0';
          ncr_age  <= 0;
        elsif ctrl.ncr_start = '1' then
          ncr_busy <= '1';
        elsif ncr_busy = '1' and ncr_age < MAX_LAT then
          ncr_age <= ncr_age + 1;
        end if;
        held <= not ctrl.pc_en;
        if ctrl.pc_en = '1' then
          started <= '0';
        elsif ctrl.md_start = '1' or ctrl.ncr_start = '1' then
          started <= '1';
        end if;
        if ctrl.pc_en = '1' then
          stall_len <= 0;
        elsif stall_len < MAX_LAT + 3 then
          stall_len <= stall_len + 1;
        end if;
      end if;
    end if;
  end process;

  default clock is rising_edge(clk);

  assume_reset_first : assume rst = '1';

  -- Environment: a stalled PC fetches the same instruction; units answer only while busy
  -- (md_done may also pulse while ncr borrows the muldiv), and at the latest after MAX_LAT.
  assume_pc_holds  : assume always ((rst = '0' and held = '1') -> instr = instr_q);
  assume_md_done   : assume always (md_done = '1' -> (md_busy = '1' or ncr_busy = '1'));
  assume_ncr_done  : assume always (ncr_done = '1' -> ncr_busy = '1');
  assume_md_bound  : assume always ((md_busy = '1' and md_age = MAX_LAT) -> md_done = '1');
  assume_ncr_bound : assume always ((ncr_busy = '1' and ncr_age = MAX_LAT) -> ncr_done = '1');

  -- Decoder
  assert_mem_we_only_sw : assert always (ctrl.mem_we = '1' -> opc = OPC_SW);
  assert_no_reg_we_sw_beq_j : assert always
    (ctrl.reg_we = '1' -> (opc /= OPC_SW and opc /= OPC_BEQ and opc /= OPC_J));
  assert_one_pc_source : assert always
    not ((ctrl.jump = '1' and ctrl.take_branch = '1') or
         (ctrl.jump_reg = '1' and (ctrl.jump = '1' or ctrl.take_branch = '1')));
  assert_jr_only_jr : assert always
    (ctrl.jump_reg = '1' -> (opc = OPC_RTYPE and fn = FN_JR));
  assert_link_only_jal : assert always
    (ctrl.link = '1' -> (opc = OPC_JAL and ctrl.reg_we = '1' and ctrl.wb_sel = WB_LINK));
  assert_jr_no_write : assert always
    ((opc = OPC_RTYPE and fn = FN_JR) -> ctrl.reg_we = '0');
  assert_branch_only_beq : assert always
    (ctrl.take_branch = '1' -> (opc = OPC_BEQ and alu_zero = '1'));
  assert_md_to_ncr_only_ncr : assert always (ctrl.md_to_ncr = '1' -> is_ncr);

  -- Stall handshake
  assert_stall_only_long : assert always (ctrl.pc_en = '0' -> is_long);
  assert_no_write_in_stall : assert always
    (ctrl.pc_en = '0' -> (ctrl.reg_we = '0' and ctrl.mem_we = '0'));
  assert_ncr_writes_on_retire : assert always
    ((is_ncr and ctrl.reg_we = '1') -> ctrl.pc_en = '1');
  assert_start_once : assert always
    ((rst = '0' and (ctrl.md_start = '1' or ctrl.ncr_start = '1')) -> started = '0');
  assert_start_idle_unit : assert always
    ((rst = '0' and (ctrl.md_start = '1' or ctrl.ncr_start = '1')) ->
       (md_busy = '0' and ncr_busy = '0'));
  assert_one_unit : assert always not (ctrl.md_start = '1' and ctrl.ncr_start = '1');
  assert_long_retires : assert always ((rst = '0' and is_long and ctrl.pc_en = '1') -> started = '1');
  assert_stall_bounded : assert always (stall_len <= MAX_LAT + 1);

  -- Reset: nothing is written or started
  assert_reset_quiet : assert always
    (rst = '1' -> (ctrl.reg_we = '0' and ctrl.mem_we = '0' and
                   ctrl.md_start = '0' and ctrl.ncr_start = '0'));

  -- Register file
  assert_zero_reads_zero : assert always
    ((rf_ra1 = 0 -> rd1 = 0) and (rf_ra2 = 0 -> rd2 = 0));
  assert_write_then_read : assert always
    ((rst = '0' and last_we = '1' and last_wa /= 0 and rf_ra1 = last_wa and
      not (rf_we = '1' and rf_wa = last_wa)) -> rd1 = last_wd);

  -- Covers require rst = '0'; otherwise they match in the reset cycle.
  cover_ncr_retire  : cover {rst = '0' and is_ncr and ctrl.reg_we = '1'};
  cover_multu_slowest : cover {rst = '0' and opc = OPC_RTYPE and fn = FN_MULTU and
                               ctrl.pc_en = '1' and stall_len = MAX_LAT + 1};
  cover_md_during_ncr : cover {rst = '0' and ncr_busy = '1' and md_done = '1' and is_ncr};
  cover_branch      : cover {rst = '0' and ctrl.take_branch = '1'};
  cover_jal         : cover {rst = '0' and ctrl.link = '1' and ctrl.pc_en = '1'};
  cover_jr          : cover {rst = '0' and ctrl.jump_reg = '1'};
  cover_back_to_back : cover {rst = '0' and is_ncr and ctrl.pc_en = '1';
                              rst = '0' and ctrl.ncr_start = '1'};
end architecture;
