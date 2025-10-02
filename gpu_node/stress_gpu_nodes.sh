#!/bin/bash

helpstr="\
stress_gpu_node.sh gathers node information and submits a slurm job stress-ng 
to stress a cpu node (memory, cpu, and kernel)

Usage: ./stress_gpu_nodes.sh -f <list_of_nodes> [-r <reservation_name>] -t <time_in_minutes> -y [-h for help]

  flag    argument          comment
    -f    list_of_nodes     text file containing list of nodes to stress
                            one node name per line
    -r    reservation       (optional) reservation name
    -t    time_in_minutes   time to run stress test, in minutes
    -y                      add -y to actually submit the job
                            without -y is a dry run
"

while getopts ":f:hr:t:y" opt; do
  case $opt in
	f) node_list_file="$OPTARG" 
	;;
	h) echo -n "$helpstr" 
	   exit 0
	;;
	r) reservation="$OPTARG" 
	;;
	t) run_time="$OPTARG"
	;;
	y) submit_job=true
	;;
	\?) echo "Invalid option: $OPTARG"
	    echo -n "$helpstr"
	    exit 1
	;;
	:)  echo "Error: Option -$OPTARG requires an argument."
            exit 1
        ;;
  esac
done

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
    sbatch_cpu_args="--reservation ${reservation}"
    sbatch_gpu_args="--reservation ${reservation}"
fi

while read nodename; do
    # get primary partition that node belongs to
    job_partition=$(scontrol show node ${nodename} | grep Partitions | awk -F '=' '{print $2}' | awk -F ',' '{print $1}')
    
    # get total mem on the node
    total_mem=$(scontrol show node ${nodename} | grep RealMemory | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # get mem reserved for slurm/os
    os_mem=$(scontrol show node ${nodename} | grep MemSpecLimit | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # calculate amount of memory available for jobs
    slurm_mem=$(echo "${total_mem} - ${os_mem}" | bc)
    
    # set gpu-burn job memory
    # based on tests, gpu-burn uses about 2GB of mem when using 4 gpus
    gpu_job_mem=4096
    
    # calculate amount of memory for stress-ng job
    # the division by 1 is to round the decimal number
    cpu_job_mem=$(echo "${slurm_mem} - ${gpu_job_mem}" | bc)
    
    # get total number of gpu cards
    n_gpus=$(scontrol show node ${nodename} | grep Gres | awk -F ':' '{print $3}' | awk -F '(' '{print $1}')
    
    # get total number of cores
    total_cpus=$(scontrol show node ${nodename} | grep CPUTot | awk -F '=' '{print $4}' | awk -F ' ' '{print $1}')
    
    # calculate cores for each job
    # based on tests, we can use 2 gpus per core without decreasing Gflops
    gpu_job_cpus=$(echo "${n_gpus} / 2" | bc)
    cpu_job_cpus=$(echo "${total_cpus} - ${gpu_job_cpus}" | bc)

    ## write summary
    echo "--------- per node summary -----------"
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
