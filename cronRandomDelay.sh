#!/bin/sh

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <full_path_to_script> <max_random_delay_in_seconds>"
    exit 1
fi

# Get the parameters
SCRIPT_PATH=$1
MAX_RANDOM_DELAY=$2

# Generate a random delay between 0 and MAX_RANDOM_DELAY seconds using awk
RANDOM_DELAY=$(awk -v max=$MAX_RANDOM_DELAY 'BEGIN{srand(); print int(rand()*max)}')
sleep $RANDOM_DELAY

# Run the provided script
$SCRIPT_PATH
