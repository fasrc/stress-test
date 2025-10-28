#!/bin/bash

script_name=$(basename "$0")

helpstr="\
${script_name} gathers node information and submits two slurm jobs (stress-ng and gpu-burn)
to stress a gpu node (memory, cpu, kernel, local storage, and gpu)

Usage: ${script_name} -f <list_of_nodes> [-r <reservation_name>] -t <time_in_minutes> -y [-h for help]

  flag    argument          comment
    -f    list_of_nodes     text file containing list of nodes to stress
                            one node name per line
    -r    reservation       (optional) reservation name
    -t    time_in_minutes   time to run stress test, in minutes
    -y                      add -y to actually submit the job
                            without -y is a dry run
"
# check for no arguments
if [ $# -eq 0 ]; then
    echo "$helpstr"
    exit 0
fi

# initialize submit_job
submit_job=false

while getopts "f:hr:t:y" opt; do
  case $opt in
        f) node_list_file="$OPTARG" ;;
        h) echo -n "$helpstr"
           exit 0 ;;
        r) reservation="$OPTARG" ;;
        t) run_time="$OPTARG" ;;
        y) submit_job=true ;;
        \?) echo "Invalid option: -$OPTARG"
            echo "$helpstr"
            exit 1 ;;
        :)  echo "Error: Option -$OPTARG requires an argument."
            echo "$helpstr"
            exit 1 ;;
  esac
done

# check input
if [[ -z "${node_list_file}" ]]; then
    echo "Error: Must specify node list file (-f)"
    echo "$helpstr"
    exit 1
fi
if [[ ! -f "${node_list_file}" ]]; then
    echo "Error: Node list file '${node_list_file}' does not exist."
    exit 1
fi
if [[ -z "${run_time}" ]]; then
    echo "Error: Must specify run time (-t) in minutes"
    echo "$helpstr"
    exit 1
fi
if ! [[ "${run_time}" =~ ^[0-9]+$ ]]; then
    echo "Error: Time (-t) must be an integer (minutes)"
    exit 1
fi

echo "========= All nodes summary =========="
echo "run_time          ${run_time} minutes"
echo "node_list_file    ${node_list_file}"

if [ "${submit_job}" = true ] ; then
    echo "submit job        ${submit_job}"
else
    echo "submit job        false"
fi
	
if [ -z "${reservation+set}" ]; then
    echo "reservation       (empty)"
else
    echo "reservation       ${reservation}"
fi

while read nodename; do
    echo "--------- per node summary -----------"

    # save scontrol output
    scontrol_output=$(scontrol show node ${nodename})

    # check node exists
    node_output=$(echo ${scontrol_output} | awk -F ' ' '{print $3}')
    if [[ "${node_output}" == "not" ]]; then
        echo "**Error**: node ${nodename} does not exist. Update ${node_list_file}."
        exit 1
    fi

    # initialize variables
    sbatch_cpu_args=""
    sbatch_gpu_args=""

    if [ ! -z "${reservation+set}" ]; then
        sbatch_cpu_args="--reservation ${reservation}"
        sbatch_gpu_args="--reservation ${reservation}"
    fi

    # get primary partition that node belongs to
    job_partition=$(echo ${scontrol_output} | tr ' ' '\n' | grep Partitions | awk -F '=' '{print $2}' | awk -F ',' '{print $1}')

    # exit if partition is serial_requeue
    if [[ "${job_partition}" == "serial_requeue" ]]; then
      echo "**Error**: job_partition is serial_requeue. Exiting."
      exit 1
    fi

    # exit if partition is gpu_requeue
    if [[ "${job_partition}" == "gpu_requeue" ]]; then
      echo "**Error**: job_partition is gpu_requeue. Exiting."
      exit 1
    fi
    
    # get total mem on the node
    total_mem=$(echo ${scontrol_output} | tr ' ' '\n' | grep RealMemory | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # get mem reserved for slurm/os
    os_mem=$(echo ${scontrol_output} | tr ' ' '\n' | grep MemSpecLimit | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # calculate amount of memory available for jobs
    slurm_mem=$(echo "${total_mem} - ${os_mem}" | bc)
    
    # set gpu-burn job memory
    # based on tests, gpu-burn uses about 2GB of mem when using 4 gpus
    gpu_job_mem=4096
    
    # calculate amount of memory for stress-ng job
    # the division by 1 is to round the decimal number
    cpu_job_mem=$(echo "${slurm_mem} - ${gpu_job_mem}" | bc)
    
    # get total number of gpu cards
    n_gpus=$(echo ${scontrol_output} | tr ' ' '\n' | grep Gres | awk -F ':' '{print $3}' | awk -F '(' '{print $1}')

    # check that node has gpus
    if [[ -z "${n_gpus}" ]]; then
        echo "Error: ${nodename} does not have any gpus."
	exit 1
    fi
    
    # get total number of cores
    total_cpus=$(echo ${scontrol_output} | tr ' ' '\n' | grep CPUTot | awk -F '=' '{print $2}')

    # checked if any cores are reserved for slurm
    slurm_cpus=$(echo ${scontrol_output} | tr ' ' '\n' | grep CoreSpecCount | awk -F '=' '{print $2}')

    if [[ "${slurm_cpus}" -gt 0 ]]; then
        total_cpus=$(echo "${total_cpus} - ${slurm_cpus}" | bc)
    fi

    # calculate cores for each job
    # based on tests, we can use 2 gpus per core without decreasing Gflops
    gpu_job_cpus=$(echo "${n_gpus} / 2" | bc)
    cpu_job_cpus=$(echo "${total_cpus} - ${gpu_job_cpus}" | bc)

    ## write summary
    echo "    nodename          ${nodename}"
    echo "    job_partition     ${job_partition}"
    echo "    slurm_mem         ${slurm_mem}"
    echo "        gpu_job_mem   ${gpu_job_mem}"
    echo "        cpu_job_mem   ${cpu_job_mem}"
    echo "    total_cpus        ${total_cpus}"
    echo "        gpu_job_cpus  ${gpu_job_cpus}"
    echo "        cpu_job_cpus  ${cpu_job_cpus}"
    echo "    n_gpus            ${n_gpus}"
    
    # save arguments
    sbatch_gpu_args="${sbatch_gpu_args} --time=${run_time} --partition ${job_partition} --mem ${gpu_job_mem} -c ${gpu_job_cpus} --nodelist ${nodename} --gres=gpu:${n_gpus}"
    sbatch_cpu_args="${sbatch_cpu_args} --time=${run_time} --partition ${job_partition} --mem ${cpu_job_mem} -c ${cpu_job_cpus} --nodelist ${nodename}"

    if [ "${submit_job}" = true ] ; then
        # submit gpu job
        sbatch ${sbatch_gpu_args} slurm_gpuburn_job.sh
        
        # submit cpu job
        sbatch ${sbatch_cpu_args} slurm_stressng_job.sh
    else
	echo " "
	echo "    **Dry run.**"
	echo "    Add -y to ./stress_gpu_nodes.sh to run. Commands that would be executed:"
        echo "        sbatch ${sbatch_gpu_args} slurm_gpuburn_job.sh"
        echo "        sbatch ${sbatch_cpu_args} slurm_stressng_job.sh"
    fi
   
done < ${node_list_file}
