import os
import sys
import argparse
import datetime
import re
from collections import defaultdict

def printf(format, *args):
    sys.stdout.write(format % args)

def slurm_time_format(total_seconds: int):
    """
    Convert seconds to SLURM D-HH:MM:SS format.
    Example: 258599 -> '2-23:43:19'
    """
    elapsed_time = datetime.timedelta(seconds=total_seconds)

    days = elapsed_time.days
    hours, remainder = divmod(elapsed_time.seconds, 3600)
    minutes, secs = divmod(remainder, 60)

    return f"{days}-{hours:02d}:{minutes:02d}:{secs:02d}"

def find_pairs(stressng_filename_list, gpuburn_filename_list):
    """
    Given:
      - stressng_filename_list: list of stressng *.out filenames
      - gpuburn_filename_list: list of *_gpuburn.txt filenames

    Return:
      - list of (gpuburn_file, stressng_file) tuples, matched by host and
        closest job id (min |jobid_stressng - jobid_gpuburn|).
    """

    pattern = re.compile(r'^(\d+)_([^_.]+)')

    def parse_job_and_host(filename):
        """
        Extract (job_id:int, host:str) from filenames like:
        44759359_holygpu8a12503_gpuburn.txt
        44759360_holygpu8a12503.out
        """
        m = pattern.match(filename)
        if not m:
            return None, None
        job_id_str, host = m.groups()
        return int(job_id_str), host

    # Group stressng .out files by host: host -> list of (job_id, filename)
    stressng_by_host = defaultdict(list)
    for out_name in stressng_filename_list:
        job_id, host = parse_job_and_host(out_name)
        if host is None:
            continue
        stressng_by_host[host].append((job_id, out_name))

    # Sort each host's list by job_id to make "closest" well-defined
    for host in stressng_by_host:
        stressng_by_host[host].sort(key=lambda x: x[0])

    # For each stressng file, track its best matching gpuburn (if any)
    # stressng_best[g_stressng_filename] = (best_diff, gpuburn_filename)
    stressng_best = {}

    for gpuburn_name in gpuburn_filename_list:
        g_job_id, host = parse_job_and_host(gpuburn_name)
        if host is None or host not in stressng_by_host:
            continue

        best_stressng_name = None
        best_diff = None

        for s_job_id, s_name in stressng_by_host[host]:
            diff = abs(s_job_id - g_job_id)
            if best_diff is None or diff < best_diff:
                best_diff = diff
                best_stressng_name = s_name

        if best_stressng_name is not None:
            # If this stressng already has a candidate, keep the closer one
            prev = stressng_best.get(best_stressng_name)
            if prev is None or best_diff < prev[0]:
                stressng_best[best_stressng_name] = (best_diff, gpuburn_name)

    # Build final list: one entry per stressng file
    pairs = []
    for stressng_name in stressng_filename_list:
        if stressng_name in stressng_best:
            _, gpuburn_name = stressng_best[stressng_name]
        else:
            gpuburn_name = "NA"
        pairs.append((gpuburn_name, stressng_name))

    return pairs

# -------------------------------
# parse input arguments
# -------------------------------
parser = argparse.ArgumentParser()

parser.add_argument("-d", "--date", dest="run_date",
                    required=True,
                    help="date in YYYY-MM-DD that the stress test started")
parser.add_argument("-D", "--detail",
                    required=False,
                    action='store_true',
                    help="output more details (e.g. path of log files)")
parser.add_argument("-g", "--debug", dest="debug",
                    required=False,
                    action='store_true',
                    help="debug mode (add print statements)")
parser.add_argument("-n", "--node-type", dest="node_type",
                    choices=["cpu", "gpu"],
                    required=True,
                    help="type of node where stress test was run")
args = parser.parse_args()

# store values
run_date = args.run_date
node_type = args.node_type
debug = args.debug
detail = args.detail

# Enforce strict YYYY-MM-DD format: 4-2-2 digits
if not re.match(r"^\d{4}-\d{2}-\d{2}$", run_date):
    parser.error("Argument -d/--date must be in strict YYYY-MM-DD format (e.g. 2025-01-23)")

# Also validate that it's a real date
try:
    datetime.datetime.strptime(run_date, "%Y-%m-%d")
except ValueError:
    parser.error("Argument -d/--date must be a valid date in YYYY-MM-DD format")    

# compose path with node type and date
folder_path = "/odyssey/stress_nodes/stress-test/" + node_type + \
              "_node/output/" + run_date

# -------------------------------
# look for stress-ng errors
# -------------------------------

# initialize summary lists
stressng_node          = []
stressng_jobid         = []
stressng_status        = []
stressng_filename      = []
stressng_req_runtime   = []
stressng_final_runtime = []
stressng_max_temp      = []

# list for temperature plot
stressng_T1            = []
stressng_T2            = []

# number of stressng files
n = 0

print("")
print("Looking for files in " + folder_path)
print("")

# look at all files in folder_path
for filename in os.listdir(folder_path):
    file_path = os.path.join(folder_path, filename)

    # look for stress-ng output files - end with .out
    if (filename.endswith(".out")) and (os.stat(file_path).st_size > 0):
        stressng_filename.insert(n, filename)
        if debug: print("File: " + filename )
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:

            # initialize variables
            max_temp = 0

            # gather run information
            jobID, nodename, *_ = filename.split("_")
            stressng_node.insert(n, nodename.split(".")[0])
            stressng_jobid.insert(n, jobID)
            
            # read an entire file
            all_text = f.read()
            
            # ensure run completed
            if "run completed in" in all_text.lower():
                # check if unsuccessful run (stress-ng found failures)
                if "unsuccessful run completed" in all_text.lower():
                    if debug: print("    Inside unsuccessful job " + jobID)
                    stressng_status.insert(n, "failed")
                # a successful run
                elif "failed: 0" in all_text.lower():
                    if debug: print("    Inside successful job " + jobID)
                    stressng_status.insert(n, "success")

            # run did not finish
            else:
                if debug: print("    Inside incomplete job " + jobID)
                stressng_status.insert(n, "incomplete run")

            # print more details
            if detail:
                if debug: print("    Getting details of " + filename)
                for i, line in enumerate(all_text.splitlines(), 1):
                    # get requested run time
                    if "stress-ng run time" in line:
                        requested_runtime_sec = float(line.split(" ")[-2])
                        if debug: print("        Requested run time: " +  \
                                        str(requested_runtime_sec) + " seconds or " + \
                                        slurm_time_format(requested_runtime_sec))
                        stressng_req_runtime.insert(n, slurm_time_format(requested_runtime_sec))

                    # get final run time (only for completed runs)
                    if(stressng_status[-1] == "incomplete run"):
                        stressng_final_runtime.insert(n, "use sacct")
                    else:
                        if "s run time" in line:
                            final_runtime_string = line.split(" ")[-3]
                            final_runtime_sec = float(final_runtime_string.rstrip('s'))
                            if debug: print("        Final run time: " +  \
                                            str(final_runtime_sec) + " seconds or " + \
                                            slurm_time_format(final_runtime_sec))
                            stressng_final_runtime.insert(n, slurm_time_format(final_runtime_sec))

                    # get max temperature
                    T1 = 0
                    T2 = 0
                    T3 = 0
                    # temperature printed every so often
                    if "therm: " in line:
                        last_column = line.split(" ")[-1]
                        # check that it's not a header
                        if(last_column != "x86_pk"):
                            T1 = float(last_column)
                            T2 = float(line.split(" ")[-3])
                        # store temperatures in the list for temp. plot
                        # this is not the summary list
                        stressng_T1.append(T1)
                        stressng_T2.append(T2)
                        if(T1 > max_temp):
                                max_temp = T1
                        if(T2 > max_temp):
                                max_temp = T2
                    # temperature at the end of the run
                    if "x86_pkg_temp" in line:
                        T3 = float(line.split(" ")[-4])
                        if(T3 > max_temp):
                            max_temp = T3
                if(max_temp < 0.1):
                    stressng_max_temp.insert(n, "NA")
                else:
                    stressng_max_temp.insert(n, max_temp)

        # update node counter
        n = n + 1

if debug: print("")

# -------------------------------
# look for gpu-burn errors
# -------------------------------

if node_type=="gpu":

    if debug:
        print("+++ gpuburn +++")
        print("")

    # initialize summary lists
    gpuburn_jobid           = []
    gpuburn_status          = []
    gpuburn_filename        = []
    gpuburn_req_runtime     = []
    gpuburn_final_runtime   = []
    gpuburn_max_temp        = []

    # look at all files in folder_path
    all_entries = os.listdir(folder_path)

    # compose list of gpu-burn output files
    gpuburn_files_unmatched = [
        entry
        for entry in all_entries
            # ensure only files (no directories)
            if os.path.isfile(os.path.join(folder_path, entry))
                # ensure only files that end with gpuburn.txt
                if entry.endswith("gpuburn.txt")
    ]
    if debug:
        print("Unmatched gpuburn output files:")
        print(f"    {gpuburn_files_unmatched}")

    # on gpunodes, stress-ng and gpu-burn are run in pair.
    # thus, we have to find the matching pairs.
    # find the gpuburn file that matches the stressng node
    pairs = find_pairs(stressng_filename, gpuburn_files_unmatched)

    # populate gpuburn_filename list
    if debug: print("Matched stressng and gpuburn output files:")
    for i, (gpuburn_file, stressng_file) in enumerate(pairs):
        if debug: print(f"    {stressng_file}  <-->  {gpuburn_file}")
        gpuburn_jobid.insert(i, gpuburn_file.split("_")[0])
        gpuburn_filename.insert(i, gpuburn_file)

    # loop through gpuburn output files
    for i, filename in enumerate(gpuburn_filename):
        if debug: print("File: " + filename )

        # skip when gpuburn output file does not exist
        if filename == "NA":
            gpuburn_status.insert(i,"did not start")
        else:
            # compose file_path
            file_path = os.path.join(folder_path, filename)

            # open file
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:

                # read an entire file
                all_text = f.read()

                # check run completed
                match = re.search(r"Tested (\d+) GPUs:", all_text)
                if match is None:
                    gpuburn_status.insert(i,"incomplete run")
                else:
                    # search for OK (sucess) in all GPUs
                    num_gpus = int(match.group(1))
                    if debug: print("    Number of GPUs: " + str(num_gpus))
                    for j in range(num_gpus):
                        ok_matches = len(re.findall(r"GPU \d+: OK", all_text))
                        if num_gpus == ok_matches:
                            gpuburn_status.insert(i,"success")
                        else:
                            gpuburn_status.insert(i,"failed")




#    # list for temperature plot
#    gpuburn_T1            = []
#    gpuburn_T2            = []
#


# -------------------------------
# print summary table
# -------------------------------

# short summary
if not detail:
    # cpu node
    if node_type=="cpu":
        printf("-----------------------------------------------\n")
        printf("           Node  job ID    stress-ng status \n")
        printf("-----------------------------------------------\n")

        for i in range(len(stressng_node)):
            printf("%15s  %-8s  %-17s \n", stressng_node[i], stressng_jobid[i], stressng_status[i])

        printf("-----------------------------------------------\n")
    # gpu node
    else:
        printf("-----------------------------------------------------------------------\n")
        printf("                      stress-ng                  gpu-burn\n")
        printf("           Node    job ID    status          job ID    status\n")
        printf("-----------------------------------------------------------------------\n")

        for i in range(len(stressng_node)):
            printf("%15s    %-8s  %-14s  %-8s  %-14s\n", \
                    stressng_node[i],   \
                    stressng_jobid[i],  \
                    stressng_status[i], \
                    gpuburn_jobid[i],   \
                    gpuburn_status[i]
                    )

        printf("-----------------------------------------------------------------------\n")

# detailed summary
else:
    printf("----------------------------------------------------------------------------------------------------------------\n")
    printf("                                                 stress-ng\n")
    printf("----------------------------------------------------------------------------------------------------------------\n")
    printf("           Node  job ID    stress-ng       logfile                       requested     final         max temp\n")
    printf("                           status          (root dir above)              run time      run time      (C)\n")
    printf("----------------------------------------------------------------------------------------------------------------\n")

    for i in range(len(stressng_node)):
        printf("%15s  %-8s  %-15s %-29s %-12s  %-12s  %-6s\n", \
                stressng_node[i],          \
                stressng_jobid[i],         \
                stressng_status[i],        \
                stressng_filename[i],      \
                stressng_req_runtime[i],   \
                stressng_final_runtime[i], \
                stressng_max_temp[i])
    printf("----------------------------------------------------------------------------------------------------------------\n")

    # gpu nodes
    if node_type=="gpu":
        print("")
        printf("-------------------------------------------------------------------------------------------------------------------------\n")
        printf("                                                 gpu-burn\n")
        printf("-------------------------------------------------------------------------------------------------------------------------\n")
        printf("           Node  job ID    gpu-burn        logfile                               requested     final         max temp\n")
        printf("                           status          (root dir above)                      run time      run time      (C)\n")
        printf("-------------------------------------------------------------------------------------------------------------------------\n")

        for i in range(len(stressng_node)):
            printf("%15s  %-8s  %-15s %-37s %-12s  %-12s  %-6s\n", \
                    stressng_node[i],          \
                    gpuburn_jobid[i],          \
                    gpuburn_status[i],         \
                    gpuburn_filename[i],       \
                    stressng_req_runtime[i],   \
                    stressng_final_runtime[i], \
                    stressng_max_temp[i])
        printf("-------------------------------------------------------------------------------------------------------------------------\n")

