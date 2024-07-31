#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 -n <VM_NAME> [-p <GUEST_ADDITIONS_ISO_PATH>]"
    echo "  -n <VM_NAME>               : Name of the VM where Guest Additions will be attached"
    echo "  -p <GUEST_ADDITIONS_ISO_PATH>: Path to the Guest Additions ISO (optional, default is /usr/share/virtualbox/VBoxGuestAdditions.iso)"
    exit 1
}

# Initialize variables
GUEST_ADDITIONS_ISO_PATH="/usr/share/virtualbox/VBoxGuestAdditions.iso"

# Parse command-line arguments
while getopts "n:p:" opt; do
    case ${opt} in
        n) VM_NAME=$OPTARG ;;
        p) GUEST_ADDITIONS_ISO_PATH=$OPTARG ;;
        \?) usage ;;
    esac
done

# Check for required arguments
if [ -z "$VM_NAME" ]; then
    usage
fi

# Attach the Guest Additions ISO to the VM
VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium "$GUEST_ADDITIONS_ISO_PATH"

echo "Attached Guest Additions ISO to VM '$VM_NAME'."
