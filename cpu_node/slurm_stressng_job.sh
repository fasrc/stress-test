#!/bin/bash
#SBATCH -J stress-ng
#SBATCH -o /odyssey/paulasan/stress-test/cpu_node/output/%N_%j.out      # %N nodename, %j jobid
#SBATCH -e /odyssey/paulasan/stress-test/cpu_node/output/%N_%j.err      # %N nodename, %j jobid
#SBATCH --reservation=cpu_burn

# this job stress the cpu, memory, and kernel

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
# use SLURM_JOB_END_TIME to
current_time=$(date +%s)
stressng_time_sec=$(echo "${SLURM_JOB_END_TIME} - ${current_time} - 600" | bc)

# run
echo "--------------------------------------------------------------------------------"
echo " stress-ng output"
echo "--------------------------------------------------------------------------------"
echo "stress-ng run time ${stressng_time_sec} seconds"
cd /odyssey/stress_nodes/stress-ng
./stress-ng --matrix ${n_matrix} --timeout ${stressng_time_sec}s --job /odyssey/paulasan/stress-test/cpu_node/stress-ng.job

