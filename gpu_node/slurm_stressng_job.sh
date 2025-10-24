#!/bin/bash
#SBATCH -J stress-ng
#SBATCH -o /odyssey/stress_nodes/stress-test/gpu_node/output/%N_%j.out      # %N nodename, %j jobid
#SBATCH -e /odyssey/stress_nodes/stress-test/gpu_node/output/%N_%j.err      # %N nodename, %j jobid

# this job stresses the cpu, memory, and kernel, and local io

# calculate number of cores for matrix stressor
# high- and low-usage cpu cores are listed at the top of cpu.job file
# this is based on: n_matrix= (total cores)       - (high-usage cpu cores) - (low-cpu usage cores)
#                           = SLURM_CPUS_PER_TASK -           5            - (        13         )
#n_matrix=$(echo "${SLURM_CPUS_PER_TASK} - 13" | bc)
n_matrix=$((${SLURM_CPUS_PER_TASK} - 13))

# output stress-ng.job to stdout for full run details
echo "--------------------------------------------------------------------------------"
echo "stress-ng input file:"
echo "--------------------------------------------------------------------------------"
cat stress-ng.job

# calculate stress-ng run time
# use SLURM_JOB_END_TIME to calculate remaining time
buffer_time=1800         # time in seconds to allow job to finish
current_time=$(date +%s)
stressng_time_sec=$(echo "${SLURM_JOB_END_TIME} - ${current_time} - ${buffer_time}" | bc)

# run
echo "--------------------------------------------------------------------------------"
echo " stress-ng output"
echo "--------------------------------------------------------------------------------"
echo "stress-ng run time ${stressng_time_sec} seconds"
cd /odyssey/stress_nodes/stress-ng
./stress-ng --version 
./stress-ng --matrix ${n_matrix} --timeout ${stressng_time_sec}s --job /odyssey/stress_nodes/stress-test/gpu_node/stress-ng.job

