#!/bin/bash

# check the cell name has been provided by the user
if [ $# -eq 0 ]; then
  echo "No cell name provided"
  exit 1
fi

mkdir -p run_dir

# go into cell specific run folder
cd run_dir
if [ ! -d "$1" ]; then
    mkdir -p "$1";
fi
cd "$1"

# create a magic tcl command file
echo "gds flatten true
# gds read ../../amsat_txrx_ic.gds" > magic_commands.tcl
echo "gds flatten true
gds read ../../amsat_txrx_ic.gds
load $1
#flatten drc_cell_lvs
#load drc_cell_lvs
extract all
extract do all
ext2spice lvs
# ext2spice subcircuits off
ext2spice -o $1_lvs.spice
select top cell
port makeall
ext2spice lvs
ext2spice cthresh 0.01
ext2spice rthresh 0.01
ext2spice subcircuit on
ext2spice ngspice
ext2spice -o $1_pex.spice
exit" > magic_commands.tcl

# remove the old LVS export
rm -f drc_cell_lvs.spice

# run magic
magic -noconsole -dnull magic_commands.tcl

# wait for new file to be generated
printf "Waiting for LVS extracted netlist to be generated.."
while [ ! -s "$1_lvs.spice" ]
    do
    printf "."
    sleep 0.25
done
echo " "

# move to the root directory and use xschem to generate a new netlist in LVS mode
run_dir=$PWD
cd ../../../..
xschem -n -q -o "$run_dir" --tcl "set top_subckt 1; set bus_replacement_char {[]}" "design/$1/$1.sch"
cd $run_dir

# include the digital cell definitions
sed -i '$s,.end,.include '"$SKY130A"'\/libs.ref\/sky130_fd_sc_hd\/spice\/sky130_fd_sc_hd.spice\n.end,g' "$1.spice"
sed -i '$s,.end,.include '"$SKY130A"'\/libs.ref\/sky130_fd_sc_hs\/spice\/sky130_fd_sc_hs.spice\n.end,g' "$1.spice"

# now compare the xschem schematic netlist and the magic extracted netlist
netgen -batch lvs "$1_lvs.spice "$1"" ""$1".spice "$1"" "$SKY130A/libs.tech/netgen/sky130A_setup.tcl" lvs_report.out -json
