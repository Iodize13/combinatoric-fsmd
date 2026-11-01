#!/usr/bin/env bash
# Verification driver for the nCr FSMD and the single-cycle CPU around it.
#   scripts/verify.sh doctor
#   scripts/verify.sh sim [N_MAX]
#   scripts/verify.sh ncr N R
#   scripts/verify.sh formal [muldiv|ncr|equiv] [task]
#   scripts/verify.sh tla
#   scripts/verify.sh synth
#   scripts/verify.sh schematic        # RTL schematics as SVG (needs netlistsvg)
#   scripts/verify.sh all
#   scripts/verify.sh clean [RUN_ID]
# Evidence:   evidence/<RUN_ID>/   (kept by clean)
# Scratch:    build/<RUN_ID>/      (removed by clean)
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
OCS=${OSS_CAD_SUITE:-$HOME/.local/opt/oss-cad-suite}
TLA_JAR=${TLA2TOOLS:-$HOME/.local/opt/tla/tla2tools.jar}
NETLISTSVG=${NETLISTSVG:-$HOME/.local/opt/netlistsvg/node_modules/.bin/netlistsvg}
RUN_ID=${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}
EV="$ROOT/evidence/$RUN_ID"
WK="$ROOT/build/$RUN_ID"

export PATH="$OCS/bin:$PATH"

# RTL sources in compile order (packages first). The .sby files keep their own copies.
RTL=(rtl/muldiv_pkg.vhd rtl/alu.vhd rtl/reg_en.vhd rtl/sr_flag.vhd rtl/down_counter.vhd rtl/prodrem_reg.vhd rtl/muldiv_status.vhd rtl/muldiv_dp.vhd rtl/muldiv_next.vhd rtl/muldiv_state_reg.vhd rtl/muldiv_ctrl.vhd rtl/muldiv.vhd rtl/ncr_pkg.vhd rtl/up_counter.vhd rtl/cmp_gt.vhd rtl/mux2.vhd rtl/res_reg.vhd rtl/ncr_dp.vhd rtl/ncr_next.vhd rtl/ncr_state_reg.vhd rtl/ncr_ctrl.vhd rtl/ncr_engine.vhd rtl/ncr_core.vhd rtl/cpu_pkg.vhd rtl/program_pkg.vhd rtl/cpu_alu.vhd rtl/regfile.vhd rtl/imem.vhd rtl/dmem.vhd rtl/wb_mux.vhd rtl/md_mux.vhd rtl/cpu_decode.vhd rtl/cpu_ctrl.vhd rtl/cpu_dp.vhd rtl/cpu.vhd)
RTL_ABS=("${RTL[@]/#/$ROOT/}")

prep_dirs() { mkdir -p "$EV" "$WK"; }

# Run a command, tee output to an evidence log, record the exit code.
record() {
  local name=$1; shift
  printf '$ %s\n' "$*" > "$EV/$name.log"
  set +e
  "$@" >> "$EV/$name.log" 2>&1
  local rc=$?
  set -e
  echo "$rc" > "$EV/$name.exit"
  printf '%-22s exit=%s  log=%s\n' "$name" "$rc" "$EV/$name.log"
  return "$rc"
}

cmd_doctor() {
  local ok=0
  for t in ghdl yosys sby yosys-smtbmc yices-smt2 yosys-abc java; do
    if command -v "$t" >/dev/null; then printf 'ok   %-14s %s\n' "$t" "$(command -v "$t")"
    else printf 'MISS %s\n' "$t"; ok=1; fi
  done
  if yosys -m ghdl -q -p 'help ghdl' >/dev/null 2>&1; then echo "ok   ghdl-yosys-plugin"
  else echo "MISS ghdl-yosys-plugin"; ok=1; fi
  if [ -f "$TLA_JAR" ]; then echo "ok   tla2tools.jar  $TLA_JAR"; else echo "MISS tla2tools.jar ($TLA_JAR)"; ok=1; fi
  command -v ghdl >/dev/null && ghdl --version | head -1
  for f in "${RTL[@]}" tb/tb_muldiv.vhd tb/tb_ncr.vhd tb/tb_cpu.vhd formal/muldiv.sby formal/ncr.sby spec/NcrFsm.tla; do
    [ -f "$ROOT/$f" ] || { echo "MISS $f"; ok=1; }
  done
  return $ok
}

cmd_sim() {
  local nmax=${1:-30} rc=0
  prep_dirs
  cd "$WK"
  record sim-analyze ghdl -a --std=08 --workdir="$WK" \
    "${RTL_ABS[@]}" "$ROOT/formal/ref/muldiv_ref.vhd" "$ROOT/formal/ref/ncr_core_ref.vhd" \
    "$ROOT/tb/tb_muldiv.vhd" "$ROOT/tb/tb_ncr.vhd" "$ROOT/tb/tb_equiv.vhd" "$ROOT/tb/tb_cpu.vhd"
  for tb in tb_muldiv tb_ncr tb_equiv tb_cpu; do
    record "sim-elab-$tb" ghdl -e --std=08 --workdir="$WK" "$tb" || { rc=1; continue; }
    local gen=(); [ "$tb" = tb_ncr ] && gen=(-gN_MAX="$nmax")
    record "sim-run-$tb" ghdl -r --std=08 --workdir="$WK" "$tb" "${gen[@]}" \
      --assert-level=error --wave="$EV/$tb.ghw" || rc=1
    grep -h 'TB PASS' "$EV/sim-run-$tb.log" || { echo "$tb: no 'TB PASS' line"; rc=1; }
  done
  return $rc
}

cmd_ncr() {
  [ $# -eq 2 ] || { echo "usage: scripts/verify.sh ncr N R"; return 2; }
  mkdir -p "$WK"
  cd "$WK"
  ghdl -a --std=08 --workdir="$WK" "${RTL_ABS[@]}" "$ROOT/tb/ncr_run.vhd"
  ghdl -e --std=08 --workdir="$WK" ncr_run
  ghdl -r --std=08 --workdir="$WK" ncr_run -gN="$1" -gR="$2" 2>&1 | sed 's/^.*(report note): //'
}

cmd_formal() {
  local design=${1:-all} task=${2:-}
  prep_dirs
  cd "$ROOT/formal"
  local designs=(muldiv ncr equiv); [ "$design" = all ] || designs=("$design")
  local rc=0 d t tasks
  for d in "${designs[@]}"; do
    # muldiv: PDR proof at W=4 plus BMC at W=6; ncr: BMC only.
    if [ -n "$task" ]; then tasks=("$task")
    elif [ "$d" = ncr ]; then tasks=(bmc cover)
    elif [ "$d" = equiv ]; then tasks=(muldiv_prove muldiv_bmc ncr_prove ncr_bmc)
    else tasks=(prove bmc cover); fi
    for t in "${tasks[@]}"; do
      local job="formal-$d-$t" out="$WK/sby-$d-$t"
      record "$job" sby -f -d "$out" "$ROOT/formal/$d.sby" "$t" || rc=1
      grep -h 'DONE (' "$EV/$job.log" | tail -1 > "$EV/$job.status" || true
      mkdir -p "$EV/$job-traces"
      find "$out" -name '*.vcd' -exec cp --backup=numbered {} "$EV/$job-traces/" \; 2>/dev/null || true
    done
  done
  return $rc
}

cmd_tla() {
  prep_dirs
  cd "$ROOT/spec"
  record tla-tlc java -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
    -workers auto -metadir "$WK/tlc" -config NcrFsm.cfg NcrFsm.tla
  grep -q 'No error has been found' "$EV/tla-tlc.log"
}

cmd_synth() {
  prep_dirs
  cd "$WK"
  local rc=0 top
  for top in ncr_core cpu; do
    record "synth-$top" yosys -m ghdl -p "ghdl --std=08 ${RTL_ABS[*]} -e $top; synth -top $top; stat" || rc=1
  done
  return $rc
}

# One SVG per entity, hierarchy kept: structural tops show their sub-units as boxes.
cmd_schematic() {
  prep_dirs
  mkdir -p "$EV/schematic"
  cd "$WK"
  local rc=0 m
  for m in alu reg_en sr_flag down_counter up_counter cmp_gt mux2 res_reg prodrem_reg muldiv_status muldiv_next muldiv_state_reg ncr_next ncr_state_reg cpu_alu regfile imem dmem wb_mux md_mux cpu_decode muldiv_dp muldiv_ctrl muldiv ncr_dp ncr_ctrl ncr_engine ncr_core cpu_ctrl cpu_dp cpu; do
    record "schematic-$m" yosys -m ghdl -p \
      "ghdl --std=08 ${RTL_ABS[*]} -e $m; prep -top $m; opt_clean -purge; write_json $WK/$m.json" || { rc=1; continue; }
    "$NETLISTSVG" "$WK/$m.json" -o "$EV/schematic/$m.svg" || rc=1
  done
  ls "$EV/schematic"
  return $rc
}

cmd_all() {
  local rc=0
  cmd_doctor > /dev/null || { echo "doctor failed; run: scripts/verify.sh doctor"; return 1; }
  cmd_sim || rc=1
  cmd_formal || rc=1
  cmd_tla || rc=1
  cmd_synth || rc=1
  echo "evidence: $EV"
  return $rc
}

cmd_clean() {
  # Scratch only; evidence/ survives. With a RUN_ID, removes only that run's scratch.
  local target="$ROOT/build"
  [ -z "${1:-}" ] || target="$ROOT/build/$1"
  rm -rf -- "$target"
  echo "removed $target (evidence kept in $ROOT/evidence)"
}

case "${1:-}" in
  doctor) shift; cmd_doctor "$@" ;;
  sim)    shift; cmd_sim "$@" ;;
  ncr)    shift; cmd_ncr "$@" ;;
  formal) shift; cmd_formal "$@" ;;
  tla)    shift; cmd_tla "$@" ;;
  synth)  shift; cmd_synth "$@" ;;
  schematic) shift; cmd_schematic "$@" ;;
  all)    shift; cmd_all "$@" ;;
  clean)  shift; cmd_clean "$@" ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
