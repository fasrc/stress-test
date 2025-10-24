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
    # check node exists
    scontrol_output=$(scontrol show node ${nodename} | awk -F ' ' '{print $3}')
    if [[ "${scontrol_output}" == "not" ]]; then
        echo "Error: node ${nodename} does not exist. Update ${node_list_file}."
        exit 1
    fi

    # initialize sbatch_args
    sbatch_args=""

    if [ ! -z "${reservation+set}" ]; then
        sbatch_args="--reservation ${reservation}"
    fi

    # get primary partition that node belongs to
    job_partition=$(scontrol show node ${nodename} | grep Partitions | awk -F '=' '{print $2}' | awk -F ',' '{print $1}')
    
    # get total mem on the node
    total_mem=$(scontrol show node ${nodename} | grep RealMemory | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # get mem reserved for slurm/os
    os_mem=$(scontrol show node ${nodename} | grep MemSpecLimit | awk -F ' ' '{print $1}' | awk -F '=' '{print $2}')
    
    # calculate amount of memory available for stress-ng job
    slurm_mem=$(echo "${total_mem} - ${os_mem}" | bc)
    
    # get total number of cores
    total_cpus=$(scontrol show node ${nodename} | grep CPUTot | awk -F '=' '{print $4}' | awk -F ' ' '{print $1}')
    
    ## write summary
    echo "--------- per node summary -----------"
    echo "    nodename          ${nodename}"
    echo "    job_partition     ${job_partition}"
    echo "    slurm_mem         ${slurm_mem}"
    echo "    total_cpus        ${total_cpus}"

    sbatch_args="${sbatch_args} --time=${run_time} --partition ${job_partition} --mem=${slurm_mem} -c ${total_cpus} --nodelist ${nodename}"

    # submit cpu job
    if [ "${submit_job}" = true ] ; then
        sbatch ${sbatch_args} slurm_stressng_job.sh
    else
        echo " "
        echo "    **Dry run.**"
        echo "    Add -y to ./stress_gpu_nodes.sh to run. Commands that would be executed:"
        echo "        sbatch ${sbatch_args} slurm_stressng_job.sh"
    fi
done < ${node_list_file}
