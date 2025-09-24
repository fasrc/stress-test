#!/bin/bash

# calculate number of cores for matrix stressor
# high- and low-usage cpu cores are listed at the top of cpu.job file
# this is based on: N_matrix= (total cores) - (high-usage cpu cores) - 0.75*(low-cpu usage cores)
#                           =$(nproc --all) -           5            - 0.75*(        13         )
let "N_matrix="$(nproc --all)"-13"
#let "N_matrix="$(nproc --all)-20""

# stress-ng log file
output_file=/odyssey/paulasan/stress-test/cpu_output/"$(hostname -s)"-"$(date "+%Y-%m-%d-%H-%M-%S")".txt

# run stress-ng
stress-ng --matrix $N_matrix --job cpu.job --log-file $output_file 

