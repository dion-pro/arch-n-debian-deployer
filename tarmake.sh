#!/bin/bash

# Check for sufficient arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <backup_path> <root_directory>"
    echo "Example: $0 /path/to/backup/system.tar.gz /"
    exit 1
fi

# Variables from script parameters
BACKUP_PATH="$1"
ROOT_DIR="$2"

# Check if the root directory exists
if [ ! -d "$ROOT_DIR" ]; then
    echo "Error: Root directory ${ROOT_DIR} does not exist."
    exit 1
fi

# Predefined exclusion patterns
EXCLUSIONS=(
    '*/boot/*'
    '*/tmp/*'
    '*/var/cache/*'
    '*/var/tmp/*'
    '*/mnt/*'
    '*/proc/*'
    '*/sys/*'
    '*/dev/*'
    '*/run/*'
    '*/media/*'
    '*/lost+found/*'
    "${ROOT_DIR}/etc/fstab"
)

# Build the exclude options for tar
EXCLUDE_OPTIONS=()
for EXCLUDE in "${EXCLUSIONS[@]}"; do
    EXCLUDE_OPTIONS+=("--exclude=${EXCLUDE}")
done

# Create the tarball with exclusions
echo "Creating tarball from ${ROOT_DIR}..."
tar -czvf "${BACKUP_PATH}" -C "${ROOT_DIR}" "${EXCLUDE_OPTIONS[@]}" .

echo "Tarball created at ${BACKUP_PATH}"
