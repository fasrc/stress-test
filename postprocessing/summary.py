import os
import sys
import argparse
import datetime
import re

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

print("")
print("Looking for files in " + folder_path)
print("")

#summary_table = [
#    ["Node", "jobID", "Start run date", "stress-ng status", "gpu-burn status"],
#    ["node01", "12345", "2025-12-18 10:00", "running", "pending"]
#]

# initialize summary lists
node_list            = []
jobID_list           = []
stressng_status_list = []
filename_list        = []
req_run_time_list    = []
final_run_time_list  = []
stressng_max_temp_list = []
if node_type=="gpu":
    gpuburn_status   = []

# list for temperature plot
stressng_T1            = []
stressng_T2            = []

# -------------------------------
# look for stress-ng errors
# -------------------------------

# number of files
n = 0

# look at all files in folder_path
for filename in os.listdir(folder_path):
    if filename.endswith(".out"):
        file_path = os.path.join(folder_path, filename)
        filename_list.insert(n, filename)
        if debug: print("File: " + filename )
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:

            # initialize variables
            max_temp = 0

            # gather run information
            jobID, nodename = filename.split("_")
            node_list.insert(n, nodename.split(".")[0])
            jobID_list.insert(n, jobID)
            
            # read an entire file
            all_text = f.read()
            
            # ensure run completed
            if "run completed in" in all_text.lower():
                # check if unsuccessful run (stress-ng found failures)
                if "unsuccessful run completed" in all_text.lower():
                    if debug: print("    Inside unsuccessful " + jobID)
                    stressng_status_list.insert(n, "failed")
                # a successful run
                elif "failed: 0" in all_text.lower():
                    if debug: print("    Inside successful " + jobID)
                    stressng_status_list.insert(n, "success")

            # run did not finish
            else:
                if debug: print("    Inside incomplete " + jobID)
                stressng_status_list.insert(n, "incomplete run")

            # print more details
            if detail:
                if debug: print("    Getting details of " + filename)
                for i, line in enumerate(all_text.splitlines(), 1):
                    # get requested run time
                    if "stress-ng run time" in line:
                        requested_run_time_sec = float(line.split(" ")[-2])
                        if debug: print("        Requested run time: " +  \
                                        str(requested_run_time_sec) + " seconds or " + \
                                        slurm_time_format(requested_run_time_sec))
                        req_run_time_list.insert(n, slurm_time_format(requested_run_time_sec))

                    # get final run time (only for completed runs)
                    if(stressng_status_list[-1] == "incomplete run"):
                        final_run_time_list.insert(n, "use sacct")
                    else:
                        if "s run time" in line:
                            final_run_time_string = line.split(" ")[-3]
                            final_run_time_sec = float(final_run_time_string.rstrip('s'))
                            if debug: print("        Final run time: " +  \
                                            str(final_run_time_sec) + " seconds or " + \
                                            slurm_time_format(final_run_time_sec))
                            final_run_time_list.insert(n, slurm_time_format(final_run_time_sec))

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
                    stressng_max_temp_list.insert(n, "NA")
                else:
                    stressng_max_temp_list.insert(n, max_temp)

        # update node counter
        n = n + 1

if debug: print("")

# -------------------------------
# look for gpu-burn errors
# -------------------------------



# -------------------------------
# print summary table
# -------------------------------

# cpu nodes
if node_type=="cpu":
    # short summary
    if not detail:
        printf("-----------------------------------------------\n")
        printf("           Node  job ID    stress-ng status \n")
        printf("-----------------------------------------------\n")

        for i in range(len(node_list)):
            printf("%15s  %-8s  %-17s \n", node_list[i], jobID_list[i], stressng_status_list[i])

        printf("-----------------------------------------------\n")
    # detailed summary
    else:
        printf("----------------------------------------------------------------------------------------------------------------\n")
        printf("           Node  job ID    stress-ng       logfile                       requested     final         max temp\n")
        printf("                           status          (root dir above)              run time      run time      (C)\n")
        printf("----------------------------------------------------------------------------------------------------------------\n")

        for i in range(len(node_list)):
            printf("%15s  %-8s  %-15s %-29s %-12s  %-12s  %-6s\n", \
                    node_list[i],            \
                    jobID_list[i],           \
                    stressng_status_list[i], \
                    filename_list[i],        \
                    req_run_time_list[i],    \
                    final_run_time_list[i],  \
                    stressng_max_temp_list[i])
        printf("----------------------------------------------------------------------------------------------------------------\n")

# gpu nodes
if node_type=="gpu":
    printf("-------------------------------------------------------------------\n")
    printf("           Node     job ID    stress-ng status     gpu-burn status \n")
    printf("-------------------------------------------------------------------\n")

    for i in range(len(node_list)):
        printf("%15s %10s %19s\n", node_list[i], jobID_list[i], stressng_status_list[i])

    printf("-------------------------------------------------------------------\n")
