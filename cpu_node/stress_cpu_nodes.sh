#!/bin/bash

helpstr="\
stress_cpu_node.sh gathers node information and submits a slurm job stress-ng 
to stress a cpu node (memory, cpu, and kernel)

Usage: ./stress_cpu_nodes.sh -f <list_of_nodes> -t <time_in_minutes> -y [-h for help]

  flag    argument          comment
    -f    list_of_nodes     text file containing list of nodes to stress
                            one node name per line
    -t    time_in_minutes   time to run stress test, in minutes
    -y                      add -y to actually submit the job
                            without -y is a dry run
"

while getopts "f:ht:y" opt; do
  case $opt in
	f) node_list_file="$OPTARG" 
	;;
	h) echo -n "$helpstr" 
	   exit 0
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
echo "submit job        ${submit_job}"

while read nodename; do
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
    
    # submit cpu job
    if [ "${submit_job}" = true ] ; then
        sbatch --time=${run_time} --partition ${job_partition} --mem=${slurm_mem} -c ${total_cpus} --nodelist ${nodename} slurm_stressng_job.sh
    else
	echo "    Dry run. Add -y to ./stress_cpu_nodes.sh to run"
	echo "    sbatch --time=${run_time} --partition ${job_partition} --mem=${slurm_mem} -c ${total_cpus} --nodelist ${nodename} slurm_stressng_job.sh"
    fi
done < ${node_list_file}
