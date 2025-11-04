#!/bin/bash
#SBATCH -J stress-ng

# this job stress the cpu, memory, local io, and kernel

# calculate number of cores for matrix stressor
# high- and low-usage cpu cores are listed at the top of stress-ng.job file
# this started with: n_matrix= (total cores) - (high-usage cpu cores) - (low-cpu usage cores)
#                            = SLURM_CPUS_PER_TASK - 5 - 13
# Paula found that 13 cores for stressors other than matrix works well
n_matrix=$((${SLURM_CPUS_PER_TASK} - 12))

# output stress-ng.job to stdout for full run details
echo "--------------------------------------------------------------------------------"
echo "stress-ng input file:"
echo "--------------------------------------------------------------------------------"
cat stress-ng.job

# calculate 47.5% of --mem for the two memory stressors
echo SLURM_MEM_PER_NODE
echo "${SLURM_MEM_PER_NODE}"
custom_mem=$(echo "${SLURM_MEM_PER_NODE}*0.475" | bc)
echo custom_mem
echo ${custom_mem}

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
./stress-ng --matrix ${n_matrix} \
	    --vm 1 --vm-bytes ${custom_mem}m --vm-keep --vm-populate \
	    --malloc 1 --malloc-bytes ${custom_mem}m \
	    --timeout ${stressng_time_sec}s --job /odyssey/stress_nodes/stress-test/gpu_node/stress-ng.job

