#!/bin/bash

# run stress-ng in tmux session (necessary when running with bpu_burn)
tmux new-session -d -s stress-ng_session './run_stressng.sh'
