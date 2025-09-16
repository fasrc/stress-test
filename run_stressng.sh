#!/bin/bash

# calculate number of cores for matrix stressor
# high- and low-usage cpu cores are listed at the top of cpu.job file
# this is based on: N_matrix= (total cores) - (high-usage cpu cores) - 0.75*(low-cpu usage cores)
#                           =$(nproc --all) -           5            -            10
let "N_matrix="$(nproc --all)"-15"

# stress-ng log file
output_file=/n/netscratch/rc_admin/Lab/stress-test/"$(hostname -s)"-"$(date "+%Y-%m-%d")".txt

# run stress-ng
stress-ng --matrix $N_matrix --job cpu.job --log-file $output_file 

