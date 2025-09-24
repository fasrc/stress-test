#!/bin/bash

# calculate number of cores for matrix stressor
# high- and low-usage cpu cores are listed at the top of cpu.job file
# this is based on: N_matrix= (total cores) - (high-usage cpu cores) - 0.75*(low-cpu usage cores) - N_gpus
#                           =$(nproc --all) -           5            - 0.75*(        13         ) - 4
#let "N_matrix="$(nproc --all)"-15"
let "N_matrix="$(nproc --all)-17""

# stress-ng log file
cpu_output_file=/odyssey/paulasan/stress-test/gpu_output/stress-ng-"$(hostname -s)"-"$(date "+%Y-%m-%d-%H-%M-%S")".txt
gpu_output_file=/odyssey/paulasan/stress-test/gpu_output/gpu-burn-"$(hostname -s)"-"$(date "+%Y-%m-%d-%H-%M-%S")".txt

# load gpu burn modules
module load gcc/14.2.0-fasrc01
module load cuda/12.9.1-fasrc01
module load cudnn/9.10.2.21_cuda12-fasrc01

# run stress-ng and gpu-burn concurrently
stress-ng --matrix $N_matrix --job cpu.job --log-file $cpu_output_file &
(cd /odyssey/paulasan/gpu-burn; ./gpu_burn -d 43200 > $gpu_output_file)
