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

- Installation
  - `stress-ng`
  - `gpu-burn`
- This repo organization
- How to run
  - cpu node
  - gpu node

## Installation

### Stress-ng



> [!NOTE]
> I (Paula) attempted to use Podman container, but even running as `root`,
> it didn't have enough privileges. I also tried to use the OS package from EPEL,
> but it's behind a few versions and it contained a bug. Thus, I ended up
> installing from source.

## How to run

###
