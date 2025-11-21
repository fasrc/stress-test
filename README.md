# stress-test
> [!CAUTION]
> Codes to stress test nodes - use caution!!

This repo contains scripts to stress compute nodes for a given time. For all
compute nodes, CPU and GPU,
[`stress-ng`](https://github.com/ColinIanKing/stress-ng) is used to stress
memory, cpu, kernel, PCI, and local storage. For GPU nodes, we also use
[`gpu-burn`](https://github.com/wilicc/gpu-burn) to continuously use the GPU and
its onboard memory.

These tools were selected based on the paper [Single-Node Power Demand During AI
Training: Measurements on an 8-GPU NVIDIA H100
System](https://ieeexplore.ieee.org/abstract/document/10938551), in which they
compared the power draw from these tools vs. AI workflows. In addition,
`stress-ng` and `gpu-burn` have active support and many citations.

## Content

- [Installation](#installation)
  - [`stress-ng`](#stress-ng)
  - [`gpu-burn`](#gpu-burn)
- [How to run](#how-to-run)
  - [CPU node](#cpu-node)
  - [GPU node](#gpu-node)

## Installation

You may install your own version or you may use the installed software in
`/odyssey/stress_nodes`.

### stress-ng

Install from source (see note below for reason).
> [!NOTE]
> I (Paula) attempted to use Podman container, but even running as `root`,
> it didn't have enough privileges. I also tried to use the OS package from EPEL,
> but it's behind a few versions and it contained a bug. Thus, I ended up
> installing from source.

```
$  git clone --single-branch https://github.com/ColinIanKing/stress-ng.git
...
$ cd stress-ng/
$ make -j
...
$ ./stress-ng --version
stress-ng, version 0.19.04 (gcc 8.5.0, x86_64 Linux 4.18.0-513.18.1.el8_9.x86_64)
```

### gpu-burn

Choose the latest `cuda` and its `cudnn`. For example (as of Nov 2025):

```bash
module load gcc/14.2.0-fasrc01
module load cuda/12.9.1-fasrc01
module load cudnn/9.10.2.21_cuda12-fasrc01

# when compiling gpu-burn, ensure that CUDAPATH and CCPATH are given
make CUDAPATH=$CUDA_HOME CCPATH=/n/sw/helmod-rocky8/apps/Core/gcc/14.2.0-fasrc01/bin
```

## How to run

`stress-ng` and `gpu-burn` are installed in `/odyssey/stress_nodes`:

```bash
$ pwd
/odyssey/stress_nodes
$ tree -L 1
.
├── gpu-burn
├── stress-ng
└── stress-test
```

Running scripts to stress nodes are in `stress-test` (this repo) and are
organized per node type, CPU and GPU, nodes.

Requirements

1. List of nodes, where each node name is in one line. For example:

   ```
   $ cat node_list.txt
   holy7c26401
   holy7c26402
   holy7c26403
   ```
2. Nodes **must** be added to slurm. All clusters work, Cannon, FASSE, and test
cluster. (You may run `stress-ng` and `gpu-burn` on nodes not added to slurm,
but scripts for automation and batch run are not ready)

3. Run jobs as `root`

### CPU node

In the `cpu_node` directory, you can find the scripts to stress a CPU node:

- `stress_cpu_nodes.sh`: main script to run; it gathers information about each
    node from the node list and submits a job using the script
    `slurm_stressng_job.sh`
- `slurm_stressng_job.sh`: submits the slurm job that runs `stress-ng` (called
    from `stress_cpu_nodes.sh`)
- `stress-ng.job`: input parameters for the `stress-ng` run `output` directory:
- where output files are written to

To run:

> [!IMPORTANT]
> The time must be greater than 30 minutes because this is the total time of the
> slurm job. `stress-ng` runs for the input minus 30. This buffer time is
> necessary to allow `stress-ng` to finish and the slurm job ends cleanly.

```
[root@holy7c26403 cpu_node]# ./stress_cpu_nodes.sh
stress_cpu_nodes.sh gathers node information and submits one slurm job (stress-ng)
to stress a cpu node (memory, cpu, kernel, and local storage)

Usage: stress_cpu_nodes.sh -f <list_of_nodes> [-r <reservation_name>] -t <time_in_minutes> -y [-h for help]

  flag    argument          comment
    -f    list_of_nodes     text file containing list of nodes to stress
                            one node name per line
    -r    reservation       (optional) reservation name
    -t    time_in_minutes   time > 30 to run stress test, in minutes
                            30 min is a buffer time to allow the job to finish cleanly
                            you may adjust buffer_time on the slurm* scripts
    -y                      add -y to actually submit the job
                            without -y is a dry run

```

The output files go to `output/<date>`, where `<date>` is the job submission
date in `YYYY-MM-DD`.

#### Example run

```
[root@holy7c26403 cpu_node]# pwd
/odyssey/stress_nodes/stress-test/cpu_node

[root@holy7c26403 cpu_node]# cat node_list.txt
holy7c26401

[root@holy7c26403 cpu_node]# ./stress_cpu_nodes.sh -f node_list.txt -t 32
######################################
               DRY RUN
######################################
========= All nodes summary ==========
run_time          32 minutes
node_list_file    node_list.txt
submit job        false
reservation       (empty)
--------- per node summary -----------
    nodename          holy7c26401
    job_partition     rc-testing
    slurm_mem         510985
    total_cpus        64

    **Dry run.**
    Add -y to ./stress_gpu_nodes.sh to run. Commands that would be executed:
        sbatch  --time=32 --partition rc-testing --mem=510985 -c 64 --nodelist holy7c26401 -o /odyssey/stress_nodes/stress-test/cpu_node/output/2025-11-21/%j_%N.out -e /odyssey/stress_nodes/stress-test/cpu_node/output/2025-11-21/%j_%N.err slurm_stressng_job.sh

[root@holy7c26403 cpu_node]# ./stress_cpu_nodes.sh -f node_list.txt -t 32 -y
========= All nodes summary ==========
run_time          32 minutes
node_list_file    node_list.txt
submit job        true
reservation       (empty)
--------- per node summary -----------
    nodename          holy7c26401
    job_partition     rc-testing
    slurm_mem         510985
    total_cpus        64
    Submitting job with:
        sbatch  --time=32 --partition rc-testing --mem=510985 -c 64 --nodelist holy7c26401 -o /odyssey/stress_nodes/stress-test/cpu_node/output/2025-11-21/%j_%N.out -e /odyssey/stress_nodes/stress-test/cpu_node/output/2025-11-21/%j_%N.err slurm_stressng_job.sh
Submitted batch job 12512

[root@holy7c26403 cpu_node]# ls -l output/2025-11-21
total 64
-rw-r--r--. 1 root root     0 Nov 21 13:09 12512_holy7c26401.err
-rw-r--r--. 1 root root 37110 Nov 21 13:13 12512_holy7c26401.out
```

### GPU node

In the `gpu_node` directory, you can find the scripts to stress a CPU node:

- `stress_gpu_nodes.sh`: main script to run; it gathers information about each
    node from the node list and submits a job using the scripts
    `slurm_stressng_job.sh` and `slurm_gpuburn_job.sh`
- `slurm_stressng_job.sh` (called from `stress_cpu_nodes.sh`): submits the slurm
    job that runs `stress-ng`
- `slurm_gpuburn_job.sh` (called from `stress_cpu_nodes.sh`): submits the slurm
    job that runs `gpu-burn`
- `stress-ng.job`: input parameters for the `stress-ng` run
- `output` directory: where output files are written to

To run:

> [!IMPORTANT]
> The time must be greater than 30 minutes because this is the total time of the
> slurm job. `stress-ng` runs for the input minus 30. This buffer time is
> necessary to allow `stress-ng` to finish and the slurm job ends cleanly.

```
[root@holy7c26403 gpu_node]# ./stress_gpu_nodes.sh
stress_gpu_nodes.sh gathers node information and submits two slurm jobs (stress-ng and gpu-burn)
to stress a gpu node (memory, cpu, kernel, local storage, and gpu)

Usage: stress_gpu_nodes.sh -f <list_of_nodes> [-r <reservation_name>] -t <time_in_minutes> -y [-h for help]

  flag    argument          comment
    -f    list_of_nodes     text file containing list of nodes to stress
                            one node name per line
    -r    reservation       (optional) reservation name
    -t    time_in_minutes   time > 30 to run stress test, in minutes
                            30 min is a buffer time to allow the job to finish cleanly
                            you may adjust buffer_time on the slurm* scripts
    -y                      add -y to actually submit the job
                            without -y is a dry run
```

The output files go to `output/<date>`, where `<date>` is the job submission
date in `YYYY-MM-DD`.

#### Example run

```
[root@fasse-node gpu_node]# cat node_list.txt
holygpu8a12101

[root@fasse-node gpu_node]# ./stress_gpu_nodes.sh -f node_list.txt -t 32
######################################
               DRY RUN
######################################
========= All nodes summary ==========
run_time          32 minutes
node_list_file    node_list.txt
submit job        false
reservation       (empty)
--------- per node summary -----------
    nodename          holygpu8a12101
    job_partition     fasse_gpu_h200
    slurm_mem         1014868
        gpu_job_mem   4096
        cpu_job_mem   1010772
    total_cpus        112
        gpu_job_cpus  2
        cpu_job_cpus  110
    n_gpus            4

    **Dry run.**
    Add -y to ./stress_gpu_nodes.sh to run. Commands that would be executed:
        sbatch  --time=32 --partition fasse_gpu_h200 --mem 4096 -c 2 --nodelist holygpu8a12101 --gres=gpu:4 -o /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N.out -e /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N.err slurm_gpuburn_job.sh
        sbatch  --time=32 --partition fasse_gpu_h200 --mem 1010772 -c 110 --nodelist holygpu8a12101 -o /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N_stressng.out -e /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N_stressng.err slurm_stressng_job.sh

[root@fasse-node gpu_node]# ./stress_gpu_nodes.sh -f node_list.txt -t 32 -y
========= All nodes summary ==========
run_time          32 minutes
node_list_file    node_list.txt
submit job        true
reservation       (empty)
--------- per node summary -----------
    nodename          holygpu8a12101
    job_partition     fasse_gpu_h200
    slurm_mem         1014868
        gpu_job_mem   4096
        cpu_job_mem   1010772
    total_cpus        112
        gpu_job_cpus  2
        cpu_job_cpus  110
    n_gpus            4
    Submitting gpu and cpu jobs with:
        sbatch  --time=32 --partition fasse_gpu_h200 --mem 4096 -c 2 --nodelist holygpu8a12101 --gres=gpu:4 -o /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N.out -e /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N.err slurm_gpuburn_job.sh
        sbatch  --time=32 --partition fasse_gpu_h200 --mem 1010772 -c 110 --nodelist holygpu8a12101 -o /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N_stressng.out -e /odyssey/stress_nodes/stress-test/gpu_node/output/2025-11-21/%j_%N_stressng.err slurm_stressng_job.sh
========= Jobs submitted =============
Submitted batch job 6390281
Submitted batch job 6390282

[root@fasse-node gpu_node]# ls -l output/2025-11-21
total 224
-rw-r--r--. 1 root root   444 Nov 21 13:17 6390281_holygpu8a12101.err
-rw-r--r--. 1 root root     0 Nov 21 13:17 6390281_holygpu8a12101_gpuburn.txt
-rw-r--r--. 1 root root     0 Nov 21 13:17 6390281_holygpu8a12101.out
-rw-r--r--. 1 root root     0 Nov 21 13:17 6390282_holygpu8a12101_stressng.err
-rw-r--r--. 1 root root 50134 Nov 21 13:19 6390282_holygpu8a12101_stressng.out
```
