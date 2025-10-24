#!/bin/bash
#SBATCH -J gpu-burn                  # job name
#SBATCH -o /odyssey/stress_nodes/stress-test/gpu_node/output/%N_%j.out          # %N nodename, %j jobid
#SBATCH -e /odyssey/stress_nodes/stress-test/gpu_node/output/%N_%j.err          # %N nodename, %j jobid

# stress-ng log file
output_file=/odyssey/stress_nodes/stress-test/gpu_node/output/gpu-burn-${SLURM_NODELIST}-${SLURM_JOBID}.txt

# calculate gpu-burn run time
# use SLURM_JOB_END_TIME to calculate remaining time
buffer_time=1800         # time in seconds to allow job to finish
current_time=$(date +%s)
gpuburn_time_sec=$(echo "${SLURM_JOB_END_TIME} - ${current_time} - ${buffer_time}" | bc)


# load gpu burn modules
module load gcc/14.2.0-fasrc01
module load cuda/12.9.1-fasrc01
module load cudnn/9.10.2.21_cuda12-fasrc01

# run gpu-burn
(cd /odyssey/stress_nodes/gpu-burn; ./gpu_burn -d ${gpuburn_time_sec} > ${output_file})
