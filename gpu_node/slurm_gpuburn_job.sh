#!/bin/bash
#SBATCH -J gpu-burn                  # job name

# stress-ng log file (goes to the same folder as std out and err)
output_file=/odyssey/stress_nodes/stress-test/gpu_node/output/"$(date "+%Y-%m-%d")"/${SLURM_JOBID}_${SLURM_NODELIST}_gpuburn.txt

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
