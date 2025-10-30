#!/bin/bash

script_name=$(basename "$0")

helpstr="\
${script_name} gathers node information and submits one slurm job (stress-ng)
to stress a cpu node (memory, cpu, kernel, and local storage)

Usage: ${script_name} -f <list_of_nodes> [-r <reservation_name>] -t <time_in_minutes> -y [-h for help]

  flag    argument          comment
    -f    list_of_nodes     text file containing list of nodes to stress
                            one node name per line
    -r    reservation       (optional) reservation name
    -t    time_in_minutes   time > 30 to run stress test, in minutes
                            30 min is a buffer time to allow the job to finish cleanly
                            you may adjust buffer_time on the slurm* scripts
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

if [ "${submit_job}" = false ] ; then
    echo "######################################"
    echo "               DRY RUN"
    echo "######################################"
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

    # initialize sbatch_args
    sbatch_args=""

    if [ ! -z "${reservation+set}" ]; then
        sbatch_args="--reservation ${reservation}"
    fi

    # get list of partitions that node belongs to
    partition_list=$(echo ${scontrol_output} | tr ' ' '\n' | grep Partitions | awk -F '=' '{print $2}')

    # check that node belongs to a partition
    if [[ -z "${partition_list}" ]]; then
        echo "Error: ${nodename} does not belong to any partition."
	exit 1
    fi

    # get a non-requeue partition to avoid preemption
    for i in ${partition_list//,/ }
        do
            if [[ ! $i == *"requeue" ]]; then
                job_partition=$i
                break 
            fi
        done

    # get total mem on the node
    total_mem=$(echo ${scontrol_output} | tr ' ' '\n' | grep RealMemory | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # get mem reserved for slurm/os
    os_mem=$(echo ${scontrol_output} | tr ' ' '\n' | grep MemSpecLimit | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # calculate amount of memory available for stress-ng job
    slurm_mem=$(echo "${total_mem} - ${os_mem}" | bc)
    
    # get total number of cores
    total_cpus=$(echo ${scontrol_output} | tr ' ' '\n' | grep CPUTot | awk -F '=' '{print $2}')

    # checked if any cores are reserved for slurm
    slurm_cpus=$(echo ${scontrol_output} | tr ' ' '\n' | grep CoreSpecCount | awk -F '=' '{print $2}')

    if [[ "${slurm_cpus}" -gt 0 ]]; then
        total_cpus=$(echo "${total_cpus} - ${slurm_cpus}" | bc)
    fi

    # standard output and error file
    output_file=/odyssey/stress_nodes/stress-test/cpu_node/output/"$(date "+%Y-%m-%d")"/%j_%N.out
    error_file=/odyssey/stress_nodes/stress-test/cpu_node/output/"$(date "+%Y-%m-%d")"/%j_%N.err

    ## write summary
    echo "    nodename          ${nodename}"
    echo "    job_partition     ${job_partition}"
    echo "    slurm_mem         ${slurm_mem}"
    echo "    total_cpus        ${total_cpus}"

    # combine sbatch arguments
    sbatch_args="${sbatch_args} --time=${run_time} --partition ${job_partition} --mem=${slurm_mem} -c ${total_cpus} --nodelist ${nodename}"
    sbatch_args="${sbatch_args} -o ${output_file} -e ${error_file}"

    # submit cpu job
    if [ "${submit_job}" = true ] ; then
        echo "    Submitting job with:"
        echo "        sbatch ${sbatch_args} slurm_stressng_job.sh"
        sbatch ${sbatch_args} slurm_stressng_job.sh
    else
        echo " "
        echo "    **Dry run.**"
        echo "    Add -y to ./stress_gpu_nodes.sh to run. Commands that would be executed:"
        echo "        sbatch ${sbatch_args} slurm_stressng_job.sh"
    fi
done < ${node_list_file}
