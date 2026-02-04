import os
import sys
import argparse
from datetime import datetime
import re

def printf(format, *args):
    sys.stdout.write(format % args)

# -------------------------------
# parse input arguments
# -------------------------------
parser = argparse.ArgumentParser()

parser.add_argument("-d", "--date", dest="run_date",
                    required=True,
                    help="date in YYYY-MM-DD that the stress test started")
parser.add_argument("-g", "--debug", dest="debug",
                    required=False, 
                    default=False,
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

# Enforce strict YYYY-MM-DD format: 4-2-2 digits
if not re.match(r"^\d{4}-\d{2}-\d{2}$", run_date):
    parser.error("Argument -d/--date must be in strict YYYY-MM-DD format (e.g. 2025-01-23)")

# Also validate that it's a real date
try:
    datetime.strptime(run_date, "%Y-%m-%d")
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
node_list = []
jobID_list = []
stressng_status_list = []
if node_type=="gpu":
    gpuburn_status = []

# -------------------------------
# look for stress-ng errors
# -------------------------------


# look at all files in folder_path
for filename in os.listdir(folder_path):
    if filename.endswith(".out"):
        file_path = os.path.join(folder_path, filename)
        if debug: print("    File: " + filename)
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:

            # gather run information
            jobID, nodename = filename.split("_")
            node_list.append(nodename.split(".")[0])
            jobID_list.append(jobID)
            
            # read an entire file
            all_text = f.read()
            
            # ensure run completed
            if "run completed in" in all_text.lower():
                # check if unsuccessful run (stress-ng found failures)
                if "unsuccessful run completed" in all_text.lower():
                    if debug: print("        Inside unsuccessful " + jobID)
                    stressng_status_list.append("failed")
                # a successful run
                elif "failed: 0" in all_text.lower():
                    #for lineno, line in enumerate(f, start=1):
                    #    if "fail:" in line.lower():
                    #        # rstrip() to remove trailing newline
                    #        # print(f"'failed' found in: {filename} (line {lineno}): {line.rstrip()}")
                    #        print("        'fail' found in line " + str(lineno) + ": " + line)
                    if debug: print("        Inside successful " + jobID)
                    stressng_status_list.append("success")
            # run did not finish
            else:
                if debug: print("        Inside incomplete " + jobID)
                stressng_status_list.append("incomplete run")

if debug: print("")

# -------------------------------
# look for gpu-burn errors
# -------------------------------



# -------------------------------
# print summary table
# -------------------------------

# cpu nodes
if node_type=="cpu":
    printf("-----------------------------------------------\n")
    printf("           Node     job ID    stress-ng status \n")
    printf("-----------------------------------------------\n")

    for i in range(len(node_list)):
        printf("%15s %10s %19s\n", node_list[i], jobID_list[i], stressng_status_list[i])

    printf("-----------------------------------------------\n")

# gpu nodes
if node_type=="gpu":
    printf("-------------------------------------------------------------------\n")
    printf("           Node     job ID    stress-ng status     gpu-burn status \n")
    printf("-------------------------------------------------------------------\n")

    for i in range(len(node_list)):
        printf("%15s %10s %19s\n", node_list[i], jobID_list[i], stressng_status_list[i])

    printf("-------------------------------------------------------------------\n")
