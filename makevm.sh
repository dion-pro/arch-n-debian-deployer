#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 -n <VM_NAME> -t <OS_TYPE> -d <DISK_NAME> -m <MEMORY> -c <CPUS> [ -sm <DISK_SIZE_MB> ] [ -sg <DISK_SIZE_GB> ] [ -i <ISO_PATH> ]"
    echo "  -n <VM_NAME>     : Name of the VM (must be unique)"
    echo "  -t <OS_TYPE>     : OS Type (e.g., Debian_64, Ubuntu_64, Windows10_64 or its description (Windows 10 )"
    echo "  -d <DISK_NAME>   : Name of the disk file (without extension, assumed VMDK due to its speed)"
    echo "  -m <MEMORY>      : Memory size in MB (e.g., 2048)"
    echo "  -c <CPUS>        : Number of CPUs (e.g., 2)"
    echo "  -sm <DISK_SIZE_MB>: Disk size in MB (optional)"
    echo "  -sg <DISK_SIZE_GB>: Disk size in GB (optional)"
    echo "  -i <ISO_PATH>    : Path to the ISO file (optional)"
    exit 1
}

# Initialize variables
DISK_SIZE_MB=""
DISK_SIZE_GB=""
ISO_PATH=""
DISK_NAME=""

# Extract OS types and descriptions
VALID_OS_TYPES=$(VBoxManage list ostypes | awk '/ID:/ {print $2}' | xargs)
VALID_OS_DESCS=$(VBoxManage list ostypes | awk -F: '/Description:/ {print substr($0, index($0,$2))}' | xargs)

# Function to check if a value is in a list
contains() {
    local value="$1"
    shift
    for item; do
        if [[ "$item" == "$value" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to validate OS type by ID or Description
validate_os_type() {
    local os_type="$1"
    if contains "$os_type" $VALID_OS_TYPES || contains "$os_type" "$VALID_OS_DESCS"; then
        return 0
    else
        return 1
    fi
}

# Parse command-line arguments
while getopts "n:t:d:m:c:sm:sg:i:" opt; do
    case ${opt} in
        n) VM_NAME=$OPTARG ;;
        t) OS_TYPE=$OPTARG ;;
        d) DISK_NAME=$OPTARG ;;
        m) MEMORY=$OPTARG ;;
        c) CPUS=$OPTARG ;;
        sm) DISK_SIZE_MB=$OPTARG ;;
        sg) DISK_SIZE_GB=$OPTARG ;;
        i) ISO_PATH=$OPTARG ;;
        \?) usage ;;
    esac
done

# Check for required arguments
if [ -z "$VM_NAME" ] || [ -z "$OS_TYPE" ] || [ -z "$DISK_NAME" ] || [ -z "$MEMORY" ] || [ -z "$CPUS" ]; then
    usage
fi

# Validate OS type
if ! validate_os_type "$OS_TYPE"; then
    echo "Error: Invalid OS type '$OS_TYPE'. Valid options are: $VALID_OS_TYPES and $VALID_OS_DESCS."
    exit 1
fi

# Check if VM already exists
if VBoxManage list vms | grep -q "\"$VM_NAME\""; then
    echo "Error: VM '$VM_NAME' already exists."
    exit 1
fi

# Determine disk size in MB
if [ -n "$DISK_SIZE_GB" ]; then
    # Convert GB to MB
    DISK_SIZE_MB=$((DISK_SIZE_GB * 1024))
elif [ -z "$DISK_SIZE_MB" ]; then
    # Default disk size if not specified
    DISK_SIZE_MB=20000
fi

# Check if VMDK already exists
VMDK_FILE="${DISK_NAME}.vmdk"
if [ -f "$VMDK_FILE" ]; then
    echo "Info: VMDK '$VMDK_FILE' already exists, skipping creation."
else
    VBoxManage createhd --filename "$VMDK_FILE" --size "$DISK_SIZE_MB" --format VMDK
fi

# Create the VM
VBoxManage createvm --name "$VM_NAME" --ostype "$OS_TYPE" --register

# Modify the VM settings
VBoxManage modifyvm "$VM_NAME" --memory "$MEMORY" --cpus "$CPUS" --nic1 nat --audio none

# Add SATA controller and attach the disk
VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VMDK_FILE"

# Attach ISO if specified
if [ -n "$ISO_PATH" ]; then
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$ISO_PATH"
fi

# Start VM in headless mode (i am not doing this)
# VBoxManage startvm "$VM_NAME" --type headless

# Output the result
echo "Created VM '$VM_NAME' with disk name: '$DISK_NAME', disk size: ${DISK_SIZE_MB:-20000} MB, ISO: ${ISO_PATH:-None}"