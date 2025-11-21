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
[nweeks@holybioinf repos]$  git clone --single-branch https://github.com/ColinIanKing/stress-ng.git
...
[nweeks@holybioinf repos]$ cd stress-ng/
[nweeks@holybioinf stress-ng]$ make -j
...
LD stress-ng
[nweeks@holybioinf stress-ng]$ ./stress-ng --version
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

```bash
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

> [!IMPORTANT]
> The time must be greater than 30 minutes because this is the total time of the
> slurm job. `stress-ng` runs for the input minus 30. This buffer time is
> necessary to allow `stress-ng` to finish and the slurm job ends cleanly.

The output files go to `output/<date>`, where `<date>` is the job submission
date in `YYYY-MM-DD`.

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

```bash
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

> [!IMPORTANT]
> The time must be greater than 30 minutes because this is the total time of the
> slurm job. `stress-ng` runs for the input minus 30. This buffer time is
> necessary to allow `stress-ng` to finish and the slurm job ends cleanly.

The output files go to `output/<date>`, where `<date>` is the job submission
date in `YYYY-MM-DD`.
