#!/bin/bash

# Path to the source files
src_files=("flake.nix" "flake.lock")

# Target directory
target_dir="./fail_logs"

# Check if target directory exists
if [[ ! -d "$target_dir" ]]; then
    echo "Directory $target_dir does not exist."
    exit 1
fi

# Loop over all directories within the target directory
for dir in $target_dir/*; do
    # Check if it is a directory
    if [[ -d "$dir" ]]; then
        # Copy each source file into the directory
        for file in "${src_files[@]}"; do
            cp -v "$file" "$dir"
        done
    fi
done
